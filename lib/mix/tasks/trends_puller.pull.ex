defmodule Mix.Tasks.TrendsPuller.Pull do
  use Mix.Task

  @shortdoc "Pull and create trends for all stocks"

  def run(_) do
    Mix.Task.run("app.start")
    Mix.shell.info("Started app, calling puller..")
    StockTrends.Puller.call
  end
end
