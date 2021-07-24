defmodule ScrapingPipeline do
  @moduledoc """
  We are converting incoming events so Broadway can process them, then filtering offline pages
  concurrently using the processors. Finally, we limited the number of scrapers running in
  parallel by configuring how batchers work.

  This is an example of using a custom GenStage producer with Broadway.
  In this implementation, Broadway substitutes for `Scraper.OnlinePageProducerConsumer`,
  `Scraper.PageConsumerSupervisor` and `Scraper.PageConsumer`.
  """

  defmodule PageProducer do
    @moduledoc """
    Since `ScrapingPipeline` is starting the process for us, we do not need the start_link/2 function.
    """

    use GenStage
    require Logger

    @doc """
    This function is the starting point of the pipeline.

    ## Examples

        pages = ["google.com", "facebook.com", "apple.com", "netflix.com", "amazon.com"]
        ScrapingPipeline.PageProducer.scrape_pages(pages)

    """
    def scrape_pages(pages) when is_list(pages) do
      ScrapingPipeline
      # We need to find a producer process name because Broadway starts it automatically.
      |> Broadway.producer_names()
      |> List.first()
      |> GenStage.cast({:scrape_pages, pages})
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

  use Broadway

  require Logger

  @producer PageProducer

  @producer_options []

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_args) do
    options = [
      name: __MODULE__,
      producer: [
        module: {@producer, @producer_options},
        # The `:transformer` setting accepts an MFA tuple, which will be used to convert incoming
        # events to `%Broadway.Message{}` structs.
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [max_demand: 1, concurrency: 2]
      ],
      batchers: [
        # This is equivalent `Scraper.PageConsumerWorker`. Wow this is a lot simpler!
        default: [batch_size: 1, concurrency: 2]
      ]
    ]

    Broadway.start_link(__MODULE__, options)
  end

  defmodule Data do
    defstruct [:page_url]
  end

  def transform(page_url, _options) do
    %Broadway.Message{
      data: %ScrapingPipeline.Data{
        page_url: page_url
      },
      acknowledger: {__MODULE__, :pages_acknowledger, []}
    }
  end

  @doc """
  Invoked to acknowledge successful and failed messages.
  The acknowledger receives groups of messages that have been processed, successfully or not. This
  is usually an opportunity to contact the message broker and inform it of the outcome.
  https://hexdocs.pm/broadway/Broadway.Acknowledger.html
  """
  @spec ack(
          ack_ref :: term(),
          successful :: [Broadway.Message.t()],
          failed :: [Broadway.Message.t()]
        ) :: :ok
  def ack(:pages_acknowledger, _successful_messages, _failed_messages) do
    # Right now we just return :ok regardless of the outcome for each message.
    # Perhaps in the future, if PageProducer has an internal queue, we can send messages back to be retried.
    :ok
  end

  @impl Broadway
  @spec handle_message(any, Broadway.Message.t(), any) :: Broadway.Message.t()
  def handle_message(_processor, message, _context) do
    if Scraper.online?(message.data.page_url) do
      # Specify a batch key for dynamic batching.
      # Use page URLs as batch keys so that we can reduce the number of requests per URL.
      Broadway.Message.put_batch_key(message, message.data.page_url)
    else
      # discard offline websites
      Broadway.Message.failed(message, "offline")
    end
  end

  @impl Broadway
  def handle_batch(_batcher, [message], _batch_info, _context) do
    Logger.info("Batch Processor received #{message.data.page_url}")
    Scraper.fake_work()
    [message]
  end
end
