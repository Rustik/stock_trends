defmodule StockTrends.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      StockTrends.Repo,
      # Start the Telemetry supervisor
      StockTrendsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: StockTrends.PubSub},
      # Start the Endpoint (http/https)
      StockTrendsWeb.Endpoint
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
  def config_change(changed, _new, removed) do
    StockTrendsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
