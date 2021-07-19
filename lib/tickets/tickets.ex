defmodule Tickets do
  @moduledoc false

  def tickets_available?("cinema") do
    Process.sleep(Enum.random(100..200))
    # Demonstrates failure
    # false
    true
  end

  def tickets_available?(ticket_type) when is_binary(ticket_type) do
    Process.sleep(Enum.random(100..200))
    true
  end

  def create_ticket(_user, _ticket_type) do
    Process.sleep(Enum.random(250..1000))
  end

  def send_email(_user) do
    Process.sleep(Enum.random(100..250))
  end

  @users [
    %{id: "1", email: "foo@email.com"},
    %{id: "2", email: "bar@email.com"},
    %{id: "3", email: "baz@email.com"}
  ]
  def list_users_by_ids(ids) when is_list(ids) do
    # Normally this would be a database query,
    # selecting only users whose id belongs to `ids`.
    Enum.filter(@users, &(&1.id in ids))
  end

  def insert_tickets(messages) do
    # Normally `Repo.insert_all/3` if using `Ecto`...
    Process.sleep(Enum.count(messages) * 250)
    messages
  end
end
