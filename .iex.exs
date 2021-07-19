import_file_if_available("~/.iex.exs")

emails = [
  "111@example.com",
  "error@example.com",
  "222@example.com"
]

good_work = fn ->
  Process.sleep(5000)
  {:ok, []}
end

bad_work = fn ->
  Process.sleep(5000)
  :error
end

doomed_work = fn ->
  Process.sleep(5000)
  raise "Boom!"
end

pages = Enum.map(1..5, &"#{&1}.example.com")

import Airports

send_messages = fn num_messages ->
  # Connect to the RabbitMQ server, using the default port and credentials
  {:ok, connection} = AMQP.Connection.open()
  # Once you have the connection, you can open a channel and start publishing messages to a queue
  {:ok, channel} = AMQP.Channel.open(connection)

  Enum.each(1..num_messages, fn _ ->
    event = Enum.random(["cinema", "musical", "play"])
    user_id = Enum.random(1..3)
    AMQP.Basic.publish(channel, "", "bookings_queue", "#{event},#{user_id}")
  end)

  AMQP.Connection.close(connection)
end
