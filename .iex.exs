import_file_if_available("~/.iex.exs")

emails = [
  "111@example.com",
  "error@example.com",
  "222@example.com"
]

good_work = fn -> Process.sleep(5000); {:ok, []} end

bad_work = fn -> Process.sleep(5000); :error end

doomed_work = fn -> Process.sleep(5000); raise "Boom!" end

pages = (1..5) |> Enum.map(& "#{&1}.example.com")

import Airports
