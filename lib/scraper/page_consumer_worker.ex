defmodule Scraper.PageConsumerWorker do
  @moduledoc """
  This does the actual work although it is not a GenStage consumer.
  """

  require Logger

  # https://hexdocs.pm/gen_stage/ConsumerSupervisor.html
  @spec start_link(any) :: {:ok, pid}
  def start_link(event) do
    Logger.info("[PageConsumerWorker] received #{inspect(event)}")

    # Pretending that we are scraping web pages
    Task.start_link(fn ->
      Scraper.fake_work()
    end)
  end
end
