defmodule Sender.JobSupervisor do
  @moduledoc """
  An intermediary supervisor that starts the Job process. This process won't be
  restarted even when the child process exits with an error.
  """

  use Supervisor, restart: :temporary

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl Supervisor
  def init(args) do
    children = [
      {Sender.JobWorker, args}
    ]

    options = [
      strategy: :one_for_one,
      max_seconds: 30
    ]

    Supervisor.init(children, options)
  end
end
