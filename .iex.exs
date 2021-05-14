emails = [
  "111@example.com",
  "error@example.com",
  "222@example.com"
]

good_work = fn -> Process.sleep(2000); {:ok, []} end

bad_work = fn -> Process.sleep(2000); :error end

doomed_work = fn -> Process.sleep(2000); raise "Boom!" end

alias Sender.SenderTask
alias Sender.SenderServer
alias Sender.JobRunner
alias Sender.JobWorker
