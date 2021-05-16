emails = [
  "111@example.com",
  "error@example.com",
  "222@example.com"
]

good_work = fn -> Process.sleep(5000); {:ok, []} end

bad_work = fn -> Process.sleep(5000); :error end

doomed_work = fn -> Process.sleep(5000); raise "Boom!" end

alias SenderTask
alias SenderServer
alias Jobber.Runner
alias Jobber.Worker
alias Jobber.Registry
