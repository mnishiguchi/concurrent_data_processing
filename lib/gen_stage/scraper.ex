defmodule Scraper do
  require Logger

  def work() do
    # fake web scraping work
    seconds = Enum.random(1..5)
    Process.sleep(:timer.seconds(seconds))
  end

  def online?(_url) do
    # Pretend we are checking if the service is online
    work()

    # Select result randomly (33% chance of the service being offline)
    Enum.random([false, true, true])
  end
end
