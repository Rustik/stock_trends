defmodule StockTrends.Repo do
  use Ecto.Repo,
    otp_app: :stock_trends,
    adapter: Ecto.Adapters.Postgres
end
