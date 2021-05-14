defmodule Sender.JobRunner do
  @moduledoc ~S"""
  Starts an isolated supervised process for each job.

  ```
             Application
                  |
             Job runner
           /      |       \
  supervisor  supervisor  supervisor
  worker      worker      worker
  ```

  ## Examples

      {:ok, pid} = JobRunner.start_job(good_work)

      {:ok, pid} = JobRunner.start_job(bad_work)

      {:ok, pid} = JobRunner.start_job(doomed_work)

  """

  use DynamicSupervisor

  def start_link(args \\ []) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_job(work_fn) do
    start_child(work_fn: work_fn)
  end

  defp start_child(args) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Sender.JobSupervisor, args}
    )
  end

  def which_children do
    DynamicSupervisor.which_children(__MODULE__)
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_seconds: 30
    )
  end
end
