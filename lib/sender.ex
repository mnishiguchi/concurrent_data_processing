defmodule Sender do
  @moduledoc """
  Documentation for `Sender`.

  ## Examples

      # Send one email
      emails |> Enum.at(0) |> Sender.send_one_email()

      # Send many emails
      Sender.send_many_emails(emails)
  """

  def send_one_email(email) do
    Process.sleep(3000)
    IO.puts("Email to #{email} sent")
    {:ok, "email_sent"}
  end

  def send_many_emails(emails) do
    Enum.each(emails, &send_one_email/1)
  end
end
