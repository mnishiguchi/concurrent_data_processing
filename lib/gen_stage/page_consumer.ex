defmodule PageConsumer do
  use GenStage
  require Logger

  def start_link(_args) do
    initial_state = []
    GenStage.start_link(__MODULE__, initial_state)
  end

  @impl GenStage
  def init(initial_state) do
    Logger.info("[PageConsumer] init")

    # subscribe_to = [PageProducer] # Default 500..1000
    # subscribe_to = [{PageProducer, min_demand: 0, max_demand: 3}]
    subscribe_to = [{PageProducer, min_demand: 0, max_demand: 1}]
    {:consumer, initial_state, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    Logger.info("[PageConsumer] received #{inspect(events)}")

    # Pretending thhat we are scraping web pages
    Enum.each(events, fn _page ->
      Scraper.work()
    end)

    {:noreply, [], state}
  end
end
