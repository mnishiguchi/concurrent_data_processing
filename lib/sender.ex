defmodule Sender do
  @moduledoc """
  Documentation for `Sender`.
  """

  @doc """
  Send one email

  ## Examples

      emails |> Enum.at(0) |> Sender.send_email()

  """
  def send_email(email) do
    Process.sleep(:timer.seconds(3))
    IO.puts("Email to #{email} sent")
    {:ok, "email_sent"}
  end

  @doc """
  Send many emails

  ## Examples

      Sender.send_many_emails(emails)
      Sender.send_many_emails(emails, :async_forget)
      Sender.send_many_emails(emails, :async_await)

  """
  def send_many_emails(emails, mode \\ :basic) do
    case mode do
      # Send async then do not care about the result
      :async_forget ->
        Enum.each(emails, fn email ->
          Task.start_link(fn -> send_email(email) end)
        end)

      # Send async and get the result
      :async_await ->
        emails
        |> Enum.map(fn email ->
          Task.async(fn -> send_email(email) end)
        end)
        |> Enum.map(&Task.await/1)

      # Send async with concurrency limit (back pressure) and get the result
      # By default, concurrency limit is set to the number of logical cores available in the system
      :async_stream ->
        emails
        |> Task.async_stream(&send_email/1)
        |> Enum.to_list()

      # Send async with concurrency limit (back pressure) and do not care about the result
      :async_stream_forget ->
        emails
        |> Task.async_stream(&send_email/1)
        |> Stream.run()

      # If we do not care about the order of the result, we can potentially speed up the operation
      :async_stream_unordered ->
        emails
        |> Task.async_stream(&send_email/1, order: false)
        |> Enum.to_list()

      # We can kill tasks that take longer than timeout (default 5 seconds) instead of exiting
      :async_stream_kill_on_timeout ->
        emails
        |> Task.async_stream(&send_email/1, on_timeout: :kill_task)
        |> Enum.to_list()

      # Send one by one in series
      _basic ->
        Enum.each(emails, &send_email/1)
    end
  end
end
