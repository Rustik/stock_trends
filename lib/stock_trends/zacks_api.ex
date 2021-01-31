defmodule StockTrends.ZacksApi do
  # Get zacks rank for ticker
  def get_rank(ticker) do
    case request_quote_summary(ticker) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, parsed_result(body)}
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, "[ZacksApi] Ticker not found"}
      {:ok, %HTTPoison.Response{status_code: 302}} ->
        {:error, "[ZacksApi] Ticker not found(got redirect)"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "[ZacksApi] Error: #{reason}"}
    end
  end

  defp request_quote_summary(ticker) do
    ticker_url(ticker)
    |> HTTPoison.get
  end

  defp parsed_result(body) do
    %{zacks_rank: find_rank(body), zacks_style_scores: find_score(body)}
  end

  defp find_rank(body) do
    Regex.run(~r/(?<=(<span class="rank_chip rankrect_\d">))(\d)(?=(<\/span>))/, body)
    |> List.wrap
    |> List.first
  end

  defp find_score(body) do
    Regex.run(~r/(?<=(<span class="composite_val composite_val_vgm">))(\w)(?=(<\/span>&nbsp;VGM))/, body)
    |> List.wrap
    |> List.first
  end

  defp ticker_url(ticker) do
    "https://www.zacks.com/stock/quote/#{ticker}?q=#{ticker}"
  end
end
