defmodule PageProducer do
  @moduledoc false

  use GenStage
  require Logger

  def start_link(_args) do
    initial_state = []
    GenStage.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @doc """
  ## Examples

      pages = ["google.com", "facebook.com", "apple.com", "netflix.com", "amazon.com"]
      PageProducer.scrape_pages(pages)

  """
  def scrape_pages(pages) when is_list(pages) do
    GenStage.cast(__MODULE__, {:scrape_pages, pages})
  end

  @impl GenStage
  def init(initial_state) do
    Logger.info("[PageProducer] init")

    {:producer, initial_state}
  end

  # Invoked when a consumer process asks for events
  @impl GenStage
  def handle_demand(demand, state) do
    Logger.info("[PageProducer] received demand for #{demand} pages")

    events = []
    {:noreply, events, state}
  end

  @impl GenStage
  def handle_cast({:scrape_pages, pages}, state) do
    {:noreply, pages, state}
  end
end
