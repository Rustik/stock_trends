defmodule StockTrendsWeb.PageController do
  use StockTrendsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
