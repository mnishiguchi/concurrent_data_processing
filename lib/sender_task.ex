defmodule SenderTask do
  @moduledoc false

  defmodule Mailer do
    @moduledoc false

    @doc """
    Sends one email.

    ## Examples

        iex> SenderTask.Mailer.deliver_now("error@example.com")
        :error

        iex> SenderTask.Mailer.deliver_now("111@example.com")
        {:ok, "email_sent"}

    """
    def deliver_now("error@example.com" = _email_address), do: :error

    # def deliver_now("error@example.com" = email) do
    #   raise "Oops, couldn't send email to #{email}!"
    # end

    def deliver_now(email_address) do
      Process.sleep(:timer.seconds(2))
      IO.puts("Email to #{email_address} sent")

      {:ok, "email_sent"}
    end
  end

  @doc """
  Send many emails

    ## Examples

        emails = [ "111@example.com", "error@example.com", "222@example.com"]

        SenderTask.send_emails(emails, :sequential)
        SenderTask.send_emails(emails, :async_forget)
        SenderTask.send_emails(emails, :async_await)
        SenderTask.send_emails(emails, :async_stream_forget)
        SenderTask.send_emails(emails, :async_stream_unordered)
        SenderTask.send_emails(emails, :async_stream_kill_on_timeout)
        SenderTask.send_emails(emails, :supervised)

  """
  # Send one by one sequentially
  def send_emails(emails, :sequential) do
    Enum.each(emails, &Mailer.deliver_now/1)
  end

  # Send async then do not care about the result
  def send_emails(emails, :async_forget) do
    Enum.each(emails, fn email ->
      Task.start_link(fn -> Mailer.deliver_now(email) end)
    end)
  end

  # Send async and get the result
  def send_emails(emails, :async_await) do
    emails
    |> Enum.map(fn email ->
      Task.async(fn -> Mailer.deliver_now(email) end)
    end)
    |> Enum.map(&Task.await/1)
  end

  # Send async with concurrency limit (back pressure) and do not care about the result
  def send_emails(emails, :async_stream_forget) do
    emails
    |> Task.async_stream(&Mailer.deliver_now/1)
    |> Stream.run()
  end

  # If we do not care about the order of the result, we can potentially speed up the operation
  def send_emails(emails, :async_stream_unordered) do
    emails
    |> Task.async_stream(&Mailer.deliver_now/1, order: false)
    |> Enum.to_list()
  end

  # We can kill tasks that take longer than timeout (default 5 seconds) instead of exiting
  def send_emails(emails, :async_stream_kill_on_timeout) do
    emails
    |> Task.async_stream(&Mailer.deliver_now/1, on_timeout: :kill_task)
    |> Enum.to_list()
  end

  # The caller won't crash when a task is crashed.
  def send_emails(emails, :supervised) do
    SenderTaskSupervisor
    |> Task.Supervisor.async_stream_nolink(emails, &Mailer.deliver_now/1)
    |> Enum.to_list()
  end
end
