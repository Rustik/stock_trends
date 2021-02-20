defmodule StockTrends.LinkPuller do
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

  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  # GenServer callbacks

  def handle_cast(:perform, state) do
    {:noreply, Puller.call, state}
  end

  def handle_call(:metrics, _from, state) do
    {:reply, Puller.metrics, state}
  end

  def init(state \\ %{}) do
    {:ok, state}
  end
end
