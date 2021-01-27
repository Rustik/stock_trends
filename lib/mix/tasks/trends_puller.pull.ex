defmodule Mix.Tasks.TrendsPuller.Pull do
  use Mix.Task

  @shortdoc "Pull and create trends for all stocks"

  def run(_) do
    StockTrends.Puller.call
  end
end
