defmodule Sender.JobRegistry do
  @moduledoc """
  Manages the processes of `JobWorker`. Job ID's are used as an identifier.
  Each entry has job type attached to it.
  """

  @type id :: Sender.JobWorker.id()
  @type type :: Sender.JobWorker.type()

  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_args) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  @spec start_link :: {:error, any} | {:ok, pid}
  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  Returns a via tuple for accessing a process that is held in this registry.
  """
  @spec via(id, type) :: {:via, Registry, {Sender.JobRegistry, id, type}}
  def via(id, type) do
    # {:via, Registry, {registry_module, unique_name, optional_value}}
    {:via, Registry, {__MODULE__, id, type}}
  end

  @doc """
  Looks up currently running "import" job processes.
  """
  @spec running_imports :: list
  def running_imports() do
    # Each value in the Registry is a tuple in the form of `{name, pid, value}`.
    match_all = {:"$1", :"$2", :"$3"}
    guards = [{:==, :"$3", "import"}]
    map_result = [%{id: :"$1", pid: :"$2", type: :"$3"}]
    Registry.select(__MODULE__, [{match_all, guards, map_result}])
  end

  @doc """
  Finds a pid by the specified ID.
  """
  @spec whereis_name(id) :: :undefined | pid
  def whereis_name(id) when is_binary(id) do
    Registry.whereis_name({__MODULE__, id})
  end
end
