defmodule Sender.SenderServer do
  use GenServer

  @doc """
  Send one email

  ## Examples

      iex> SenderServer.send_email("111@example.com")
      :ok

      iex> SenderServer.send_email("error@example.com")
      :error

  """
  # Simulates error
  def send_email("error@example.com" = _email_address) do
    :error
  end

  # Simulates success
  def send_email(email_address) do
    Process.sleep(:timer.seconds(2))
    IO.puts("Email to #{email_address} sent")
    {:ok, "email_sent"}
  end

  @doc """
  ## Examples

      {:ok, pid} = SenderServer.start_link()
      SenderServer.send_email(pid, "111@example.com")
      SenderServer.send_email(pid, "error@example.com")
      :sys.get_state(pid)

  """
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def send_email(server, email) do
    GenServer.cast(server, {:send_email, email})
  end

  @impl GenServer
  def init(args) do
    IO.puts("Received arguments: #{inspect(args)}")
    max_retries = Keyword.get(args, :max_retries, 5)

    # Periodically check for failed emails
    Process.send_after(self(), :send_failed_emails, 5000)

    state = %{emails: [], max_retries: max_retries}
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:send_email, email_address}, state) do
    status =
      case send_email(email_address) do
        {:ok, _} -> "sent"
        :error -> "failed"
      end

    emails = [%{email: email_address, status: status, retries: 0} | state.emails]
    {:noreply, %{state | emails: emails}}
  end

  @impl GenServer
  def handle_info(:send_failed_emails, state) do
    {failed, done} =
      Enum.split_with(state.emails, fn entry ->
        entry.status == "failed" && entry.retries < state.max_retries
      end)

    retried =
      Enum.map(failed, fn entry ->
        IO.puts("Retrying email #{entry.email}...")

        new_status =
          case send_email(entry.email) do
            {:ok, _} -> "sent"
            :error -> "failed"
          end

        %{email: entry.email, status: new_status, retries: entry.retries + 1}
      end)

    Process.send_after(self(), :send_failed_emails, 5000)

    {:noreply, %{state | emails: retried ++ done}}
  end

  @impl GenServer
  def terminate(reason, _state) do
    IO.puts("Terminating with reason #{reason}")
  end
end
