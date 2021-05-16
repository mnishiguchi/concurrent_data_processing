defmodule SenderServer do
  @moduledoc false

  defmodule Mailer do
    @moduledoc false

    @doc """
    Sends one email.

    ## Examples

        iex> SenderServer.Mailer.deliver_now("error@example.com")
        :error

        iex> SenderServer.Mailer.deliver_now("111@example.com")
        {:ok, "email_sent"}

    """
    def deliver_now("error@example.com" = _email_address), do: :error

    def deliver_now(email_address) do
      Process.sleep(:timer.seconds(2))
      IO.puts("Email to #{email_address} sent")

      {:ok, "email_sent"}
    end
  end

  use GenServer

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
      case Mailer.deliver_now(email_address) do
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
          case Mailer.deliver_now(entry.email) do
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
