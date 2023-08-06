defmodule StockTrends.LinkPuller do
  import StockTrends.CacheMetrics
  alias StockTrends.Puller
  use GenServer
  #
  # Client and Server interface for Puller
  #
  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_args, name: __MODULE__)
  end

  def perform do
    GenServer.cast(__MODULE__, :perform)
  end

  def puller_running? do
    metrics()[:status] == "started"
  end

  def info do
    generate_info()
  end

  # GenServer callbacks

  def handle_cast(:perform, state) do
    {:noreply, Puller.call, state}
  end

  def init(state \\ %{}) do
    {:ok, state}
  end
end
