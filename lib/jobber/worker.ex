defmodule Jobber.Worker do
  @moduledoc """
  Does the actual work.
  """

  use GenServer, restart: :temporary

  require Logger

  defstruct [
    :work_fn,
    :id,
    :max_retries,
    retries: 0,
    status: "new"
  ]

  @retry_interval 5000

  @type id :: binary
  @type type :: binary
  @type work_fn :: (() -> {:ok, any} | {:error, any})
  @type max_retries :: pos_integer

  @type init_arg :: [
          id: id,
          type: type,
          work_fn: work_fn,
          max_retries: max_retries
        ]

  @spec start_link(init_arg) :: GenServer.on_start()
  def start_link(args \\ []) do
    args = maybe_put_random_id(args)

    id = Keyword.fetch!(args, :id)
    type = Keyword.fetch!(args, :type)
    GenServer.start_link(__MODULE__, args, name: Jobber.Registry.via(id, type))
  end

  defp maybe_put_random_id(args) do
    if Keyword.has_key?(args, :id),
      do: args,
      else: Keyword.put(args, :id, random_job_id())
  end

  @impl GenServer
  def init(args) do
    initial_state = %__MODULE__{
      id: Keyword.fetch!(args, :id),
      work_fn: Keyword.fetch!(args, :work_fn),
      max_retries: Keyword.get(args, :max_retries, 3)
    }

    {:ok, initial_state, {:continue, :run}}
  end

  # Generates a short unique ID
  defp random_job_id() do
    :crypto.strong_rand_bytes(5) |> Base.url_encode64(padding: false)
  end

  @impl GenServer
  def handle_continue(:run, state) do
    new_state = state.work_fn.() |> handle_job_result(state)

    if new_state.status == "errored" do
      Process.send_after(self(), :retry, @retry_interval)
      {:noreply, new_state}
    else
      Logger.info("Job exiting #{state.id}")
      {:stop, :normal, new_state}
    end
  end

  # success, when the job completes and returns {:ok, data}
  defp handle_job_result({:ok, _data}, state) do
    Logger.info("Job completed #{state.id}")
    %__MODULE__{state | status: "done"}
  end

  # initial error, when it fails the first time with :error
  defp handle_job_result(:error, %{status: "new"} = state) do
    Logger.warn("Job errored #{state.id}")
    %__MODULE__{state | status: "errored"}
  end

  # retry error, when we attempt to re-run the job and also receive :error
  defp handle_job_result(:error, %{status: "errored"} = state) do
    Logger.warn("Job retry failed #{state.id}")
    new_state = %__MODULE__{state | retries: state.retries + 1}

    if new_state.retries == state.max_retries do
      %__MODULE__{new_state | status: "max retries reached"}
    else
      new_state
    end
  end

  @impl GenServer
  def handle_info(:retry, state) do
    # Delegate work to the `handle_continue/2` callback.
    {:noreply, state, {:continue, :run}}
  end

  @impl GenServer
  def terminate(reason, _state) do
    Logger.info("Terminating with reason #{inspect(reason)}")
  end
end
