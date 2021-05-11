defmodule Sender.SenderTask do
  @moduledoc false

  @doc """
  Send one email

  ## Examples

      iex> SenderTask.send_email("111@example.com")
      :ok

      iex> SenderTask.send_email("error@example.com")
      ** (RuntimeError) Oops, couldn't send email to error@example.com!

  """
  # # Simulates error
  # def send_email("error@example.com" = email) do
  #   raise "Oops, couldn't send email to #{email}!"
  # end

  # Simulates success
  def send_email(email) do
    Process.sleep(:timer.seconds(2))
    IO.puts("Email to #{email} sent")
    {:ok, "email_sent"}
  end

  @doc """
  Send many emails

    ## Examples

        emails = [
          "111@example.com",
          "error@example.com",
          "222@example.com"
        ]

        SenderTask.send_emails(emails)
        SenderTask.send_emails(emails, :async_forget)
        SenderTask.send_emails(emails, :async_await)
        SenderTask.send_emails(emails, :async_stream_forget)
        SenderTask.send_emails(emails, :async_stream_unordered)
        SenderTask.send_emails(emails, :async_stream_kill_on_timeout)
        SenderTask.send_emails(emails, :supervised)

  """
  # Send one by one in series
  def send_emails(emails) do
    Enum.each(emails, &send_email/1)
  end

  # Send async then do not care about the result
  def send_emails(emails, :async_forget) do
    Enum.each(emails, fn email ->
      Task.start_link(fn -> send_email(email) end)
    end)
  end

  # Send async and get the result
  def send_emails(emails, :async_await) do
    emails
    |> Enum.map(fn email ->
      Task.async(fn -> send_email(email) end)
    end)
    |> Enum.map(&Task.await/1)
  end

  # Send async with concurrency limit (back pressure) and do not care about the result
  def send_emails(emails, :async_stream_forget) do
    emails
    |> Task.async_stream(&send_email/1)
    |> Stream.run()
  end

  # If we do not care about the order of the result, we can potentially speed up the operation
  def send_emails(emails, :async_stream_unordered) do
    emails
    |> Task.async_stream(&send_email/1, order: false)
    |> Enum.to_list()
  end

  # We can kill tasks that take longer than timeout (default 5 seconds) instead of exiting
  def send_emails(emails, :async_stream_kill_on_timeout) do
    emails
    |> Task.async_stream(&send_email/1, on_timeout: :kill_task)
    |> Enum.to_list()
  end

  # The caller won't crash when a task is crashed.
  def send_emails(emails, :supervised) do
    Sender.EmailTaskSupervisor
    |> Task.Supervisor.async_stream_nolink(emails, &send_email/1)
    |> Enum.to_list()
  end
end
