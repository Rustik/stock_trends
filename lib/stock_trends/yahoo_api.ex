defmodule StockTrends.YahooApi do
  import StockTrends.Dig

  # Get ticker data from Yahoo API
  def pull_ticker(ticker) do
    case request_quote_summary(ticker) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, parsed_result(body)}
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, "[YahooApi] Ticker not found"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "[YahooApi] Error: #{reason}"}
    end
  end

  defp request_quote_summary(ticker) do
    ticker_url(ticker)
    |> HTTPoison.get
  end

  defp parsed_result(body) do
    Jason.decode!(body)
    |> dig(["quoteSummary", "result"])
    |> List.first
  end

  defp ticker_url(ticker) do
    "https://query1.finance.yahoo.com/v10/finance/quoteSummary/#{ticker}?modules=summaryDetail%2CdefaultKeyStatistics%2CfinancialData%2CearningsHistory"
  end
end
