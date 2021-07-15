defmodule Scraper.PageConsumerSupervisor do
  @moduledoc """
  Manages demand, receives events and starts concurrent worker processes.
  A child process is started per event.
  """

  use ConsumerSupervisor
  require Logger

  def start_link(args) do
    ConsumerSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl ConsumerSupervisor
  def init(_args) do
    Logger.info("[PageConsumerSupervisor] init")

    children = [
      # The template for all concurrent child processes. An event will be passed in as an arg.
      # https://hexdocs.pm/gen_stage/ConsumerSupervisor.html
      %{
        id: Scraper.PageConsumerWorker,
        start: {Scraper.PageConsumerWorker, :start_link, []},
        restart: :transient
      }
    ]

    opts = [
      strategy: :one_for_one,
      subscribe_to: []
    ]

    ConsumerSupervisor.init(children, opts)
  end
end
