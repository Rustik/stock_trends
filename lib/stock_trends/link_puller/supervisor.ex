defmodule StockTrends.LinkPuller.Supervisor do
  alias StockTrends.LinkPuller
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(LinkPuller, [[name: LinkPuller]])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
