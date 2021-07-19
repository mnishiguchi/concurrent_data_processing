defmodule BookingsPipeline do
  @moduledoc """
  Processes ticket bookings.

  ## Incoming messages

  Comma-separated values of ticket type and user id.

  ```
  cinema,1
  ```
  """

  use Broadway

  @producer BroadwayRabbitMQ.Producer

  # broker-specific configuration
  # https://hexdocs.pm/broadway_rabbitmq/BroadwayRabbitMQ.Producer.html#module-options
  @producer_options [
    # The queue will be created automatically.
    queue: "bookings_queue",
    # The :declare option will create this queue in RabbitMQ if it doesn’t exist already.
    # Setting this to `durable: true` will persist the queue between broker restarts.
    declare: [durable: true],
    # Send failed messages back to the queue
    on_failure: :reject_and_requeue,
    qos: [
      # https://hexdocs.pm/broadway_rabbitmq/BroadwayRabbitMQ.Producer.html#module-back-pressure-and-prefetch_count
      prefetch_count: 100
    ]
  ]

  def start_link(_args) do
    # https://hexdocs.pm/broadway/Broadway.html#start_link/2-options
    options = [
      # Used as a prefix when naming processes
      name: __MODULE__,
      # Configuration about the source of events
      producer: [
        module: {@producer, @producer_options}
      ],
      # Configuration about the stage processes that receive the messages and do most of the work
      processors: [
        # The `:default` group of processors is the only one that is allowed for now; however, in
        # the future, Broadway may support multiple processor groups.
        default: []
      ],
      batchers: [
        # Unlike `:processors`, the `:batchers` configuration supports multiple groups.
        # By default, you get one batch processor per batcher, but you can increase this by using
        # the `:concurrency` key on each batcher group.
        # The variables `:batcher`, `:batch_key`, `:batch_size`, and `:batch_time` determines what
        # messages each batch processor receives.
        cinema: [batch_size: 75],
        musical: [batch_size: 100],
        default: [batch_size: 50]
      ]
    ]

    Broadway.start_link(__MODULE__, options)
  end

  defmodule Data do
    defstruct [:ticket_type, :user, :user_id]
  end

  # - Used for preloading data.
  # - A potential error in your code will cause all messages to be marked as failed.
  @impl Broadway
  @spec prepare_messages(messages :: [Broadway.Message.t()], context :: term) ::
          [Broadway.Message.t()]
  def prepare_messages(messages, _context) do
    # Here you can iterate over a list of messages, update it as needed.

    # Parse data and convert to a map.
    messages =
      Enum.map(messages, fn message ->
        Broadway.Message.update_data(message, fn data ->
          [ticket_type, user_id] = String.split(data, ",")

          %BookingsPipeline.Data{
            ticket_type: ticket_type,
            user_id: user_id
          }
        end)
      end)

    users = Tickets.list_users_by_ids(Enum.map(messages, & &1.data.user_id))

    # Put users in messages.
    Enum.map(messages, fn message ->
      Broadway.Message.update_data(message, fn data ->
        user = Enum.find(users, &(&1.id == data.user_id))
        struct!(data, user: user)
      end)
    end)
  end

  # - Processes incoming messages sent by the broker.
  # - Executed by processors that are concurrently running processes started by Broadway.
  # - If an exception happens, the pipeline will be restarted and quickly brought back to a working state.
  @impl Broadway
  @spec handle_message(
          processor :: atom,
          message :: Broadway.Message.t(),
          context :: term
        ) :: Broadway.Message.t()
  def handle_message(_processor_group, message, _context) do
    # Add your business logic here...
    if Tickets.tickets_available?(message.data.ticket_type) do
      case message do
        %{data: %{ticket_type: "cinema"}} = message ->
          Broadway.Message.put_batcher(message, :cinema)

        %{data: %{ticket_type: "musical"}} = message ->
          Broadway.Message.put_batcher(message, :musical)

        message ->
          message
      end
    else
      # Manually mark a message as failed specifying the reason
      Broadway.Message.failed(message, "bookings-closed")
    end
  end

  # A place for us to see what happens in case a message is marked as fail
  @impl Broadway
  @spec handle_failed(
          messages :: [Broadway.Message.t()],
          context :: term
        ) :: [Broadway.Message.t()]
  def handle_failed(messages, _context) do
    IO.inspect(messages, label: "Failed messages")

    Enum.map(messages, fn
      # A message that fails with the reason "bookings-closed"
      %{status: {:failed, "bookings-closed"}} = message ->
        # Overwrite the acknowledgment setting for this particular message
        Broadway.Message.configure_ack(message, on_failure: :reject)

      # A message that fails with the other reasons
      message ->
        message
    end)
  end

  @impl Broadway
  @spec handle_batch(
          batcher :: atom,
          messages :: [Broadway.Message.t()],
          batch_info :: Broadway.BatchInfo.t(),
          context :: term
        ) :: [Broadway.Message.t()]
  def handle_batch(_batcher, messages, batch_info, _context) do
    IO.puts("#{inspect(self())} Batch #{batch_info.batcher} #{batch_info.batch_key}")

    messages
    |> Tickets.insert_tickets()
    |> Enum.each(fn message ->
      channel = message.metadata.amqp_channel
      payload = "email,#{message.data.user.email}"
      AMQP.Basic.publish(channel, "", "notifications_queue", payload)
    end)

    messages
  end
end
