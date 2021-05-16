defmodule SenderServerTest do
  use ExUnit.Case
  doctest SenderServer.Mailer

  test "SenderServer" do
    {:ok, pid} = SenderServer.start_link()

    :ok = SenderServer.send_email(pid, "111@example.com")
    :ok = SenderServer.send_email(pid, "error@example.com")

    assert %{
             emails: [
               %{email: "error@example.com", retries: 0, status: "failed"},
               %{email: "111@example.com", retries: 0, status: "sent"}
             ],
             max_retries: 5
           } = :sys.get_state(pid)
  end
end
