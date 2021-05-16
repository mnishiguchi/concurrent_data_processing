defmodule Scraper do
  require Logger

  def work() do
    # fake web scraping work
    seconds = Enum.random(1..5)
    Process.sleep(:timer.seconds(seconds))
    Logger.info("[Scraper] done")
  end
end
