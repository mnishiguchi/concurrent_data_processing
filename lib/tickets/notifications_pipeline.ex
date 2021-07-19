defmodule NotificationsPipeline do
  @moduledoc """
  Processes notifications.

  ## Incoming messages

  Comma-separated values of notification type and recipient.

  ```
  email,user@example.com
  ```
  """

  use Broadway

  @producer BroadwayRabbitMQ.Producer

  @producer_options [
    queue: "notifications_queue",
    declare: [durable: true],
    on_failure: :reject_and_requeue,
    qos: [prefetch_count: 100]
  ]

  def start_link(_args) do
    options = [
      name: NotificationsPipeline,
      producer: [module: {@producer, @producer_options}],
      processors: [
        default: []
      ],
      batchers: [
        # five workes; 10-second window (trigger every 10 seconds)
        email: [concurrency: 5, batch_timeout: 10_000]
      ]
    ]

    Broadway.start_link(__MODULE__, options)
  end

  defmodule Data do
    defstruct [:notification_type, :recipient]
  end

  @impl Broadway
  @spec prepare_messages(messages :: [Broadway.Message.t()], context :: term) ::
          [Broadway.Message.t()]
  def prepare_messages(messages, _context) do
    Enum.map(messages, fn message ->
      Broadway.Message.update_data(message, fn data ->
        [notification_type, recipient] = String.split(data, ",")

        %NotificationsPipeline.Data{
          notification_type: notification_type,
          recipient: recipient
        }
      end)
    end)
  end

  @impl Broadway
  @spec handle_message(
          processor :: atom,
          message :: Broadway.Message.t(),
          context :: term
        ) :: Broadway.Message.t()
  def handle_message(_processor, message, _context) do
    message
    # Specify which batcher to use
    |> Broadway.Message.put_batcher(:email)
    # Specify a batch key which is used for dynamic batching
    |> Broadway.Message.put_batch_key(message.data.recipient)
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

    # Send an email digest to the user with all information.
    # Of course, we oversimplified our notifications on purpose. Normally we’ll need the
    # notification text and other variables in the message, so we can include them in the email.
    # We also skipped the logic that creates the digest email before sending it.

    messages
  end
end
