defmodule StockTrends.GurufocusApi do
  # Get gurufocus score for ticker
  def get_score(ticker) do
    case request_quote_summary(ticker) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parsed_result(body)
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        "[GurufocusApi] Ticker not found"
      {:error, %HTTPoison.Error{reason: reason}} ->
        "[GurufocusApi] Error: #{reason}"
    end
  end

  defp request_quote_summary(ticker) do
    ticker_url(ticker)
    |> HTTPoison.get
  end

  defp parsed_result(body) do
    %{financial_strength: find_financial_strength(body), profitability_rank: find_profitability_rank(body)}
  end

  defp find_financial_strength(body) do
    Regex.run(~r/(?<=(Financial Strength\s<\/a><\/h2><\/td> <td width="40" class="fs-large fc-regular fw-bolder" data-v-\w{8}>\n))(\d*)(?=(\/(\d*)(\s*)<\/td>))/, body)
    |> List.wrap
    |> List.first
    |> string_to_integer
  end

  defp find_profitability_rank(body) do
    Regex.run(~r/(?<=(Profitability Rank\s<\/a><\/h2><\/td> <td width="40" class="fs-large fc-regular fw-bolder" data-v-\w{8}>\n))(\d*)(?=(\/(\d*)(\s*)<\/td>))/, body)
    |> List.wrap
    |> List.first
    |> string_to_integer
  end

  defp ticker_url(ticker) do
    "https://www.gurufocus.com/stock/#{ ticker }/summary?search=#{ ticker }"
  end

  defp string_to_integer(value) when not is_nil(value), do: String.to_integer(value)
  defp string_to_integer(value), do: value
end
