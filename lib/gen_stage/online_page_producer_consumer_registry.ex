defmodule OnlinePageProducerConsumerRegistry do
  @moduledoc false

  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_) do
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
  Returns a standardized via-tuple for this registry.
  """
  def via(unique_name) do
    # {:via, Registry, {registry_module, unique_name, optional_value}}
    {:via, Registry, {__MODULE__, unique_name}}
  end
end
