defmodule Scraper.OnlinePageFlow do
  @moduledoc """
  Filters offline pages out of the data.
  This needs to be started after `PageProducer` and `PageConsumerSupervisor`.
  """

  use Flow
  require Logger

  def start_link(_args) do
    Logger.info("[OnlinePageFlow] start_link")

    producers = [
      Process.whereis(Scraper.PageProducer)
    ]

    consumers = [
      {Process.whereis(Scraper.PageConsumerSupervisor), max_demand: 2}
    ]

    # Normally, you will start a Flow process `Flow.start_link/2`; however, `Flow.into_stages/3`
    # will handle it for us.
    # Previously, we used the `Registry` to name and start two instances of
    # `OnlinePageConsumerProducer`, which is no longer needed since we can set `:stages` to 2 in
    # `from_stages/2`.
    Flow.from_stages(producers, max_demand: 1, stages: 2)
    |> Flow.filter(&Scraper.online?/1)
    |> Flow.into_stages(consumers)
  end
end
