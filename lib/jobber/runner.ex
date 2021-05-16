defmodule Jobber.Runner do
  @moduledoc ~S"""
  Starts an isolated supervised process for each job.

  ```
             Application
                  |
             Job runner
           /      |       \
  supervisor  supervisor  supervisor # remain idle even after the job is done (maybe this can be purged periodically)
  worker      worker      worker     # exit when the job is done
  ```

  ## Examples

      # Simulate error
      {:ok, pid} = Jobber.Runner.start_job(work_fn: bad_work, type: "send_email")

      # Simulate crash
      {:ok, pid} = Jobber.Runner.start_job(work_fn: doomed_work, type: "send_email")

      # Send many
      (1..6) |> Enum.map(fn _ -> Jobber.Runner.start_job(work_fn: good_work, type: "import") end)

      # Send different job types
      {:ok, pid} = Jobber.Runner.start_job(work_fn: good_work, type: "import")
      {:ok, pid} = Jobber.Runner.start_job(work_fn: good_work, type: "send_email")
      {:ok, pid} = Jobber.Runner.start_job(work_fn: good_work, type: "import")
      JobRegistry.running_imports()

      # Inspect children
      Jobber.Runner.count_children()
      Jobber.Runner.which_children()

      # Purge idle children
      Jobber.Runner.idle_children()
      Jobber.Runner.stop_idle_children()

  """

  use DynamicSupervisor

  @spec start_link(nil | []) :: Supervisor.on_start()
  def start_link(args \\ []) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec start_job(Jobber.Worker.init_arg()) :: DynamicSupervisor.on_start_child()
  def start_job(args) do
    # Enforce a limit on how many import jobs can run at any given time
    if Enum.count(Jobber.Registry.running_imports()) >= 5 do
      {:error, :import_quota_reached}
    else
      DynamicSupervisor.start_child(__MODULE__, {Jobber.Supervisor, args})
    end
  end

  def which_children do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children do
    DynamicSupervisor.count_children(__MODULE__)
  end

  def stop_idle_children do
    Enum.each(idle_children(), &Supervisor.stop(&1))
  end

  def idle_children do
    {done, _pending} =
      which_children()
      |> Enum.map(&elem(&1, 1))
      |> Enum.split_with(&(Supervisor.which_children(&1) == []))

    done
  end

  @impl DynamicSupervisor
  def init(_args) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_seconds: 30
    )
  end
end
