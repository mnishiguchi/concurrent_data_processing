defmodule Scraper.OnlinePageProducerConsumer do
  @moduledoc false

  use GenStage
  require Logger

  @type state :: list
  @type events :: list

  @type child_spec_options :: [{:id, any}]

  @spec child_spec(child_spec_options) :: Supervisor.child_spec()
  def child_spec(id: id) do
    %{
      id: {__MODULE__, id},
      start: {__MODULE__, :start_link, [id]}
    }
  end

  defdelegate via(unique_name), to: Scraper.OnlinePageProducerConsumerRegistry

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(unique_name) do
    GenStage.start_link(__MODULE__, :ok, name: via(unique_name))
  end

  @impl GenStage
  @spec init(:ok) :: {:producer_consumer, state, [GenStage.producer_consumer_option()]}
  def init(:ok) do
    Logger.info("[OnlinePageProducerConsumer] init")

    initial_state = []

    subscribe_to = [
      {Scraper.PageProducer, min_demand: 0, max_demand: 1}
    ]

    {:producer_consumer, initial_state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  @spec handle_events(events, GenStage.from(), state) :: {:noreply, list, state}
  def handle_events(events, _, state) do
    Logger.info("[OnlinePageProducerConsumer] received #{inspect(events)}")

    events = Enum.filter(events, &Scraper.online?/1)

    # Unlike :consumer stages, we can return a list of events from the handle_events/3 callback
    {:noreply, events, state}
  end
end
