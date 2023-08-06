defmodule StockTrends.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the Telemetry supervisor
      StockTrendsWeb.Telemetry,
      # Start the Ecto repository
      StockTrends.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: StockTrends.PubSub},
      # Start Finch
      {Finch, name: StockTrends.Finch},
      # Start the Endpoint (http/https)
      StockTrendsWeb.Endpoint,
      supervisor(StockTrends.LinkPuller.Supervisor, []),
      # Start a worker by calling: StockTrends.Worker.start_link(arg)
      # {StockTrends.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StockTrends.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StockTrendsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
