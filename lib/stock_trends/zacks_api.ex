defmodule StockTrends.ZacksApi do
  # Get zacks rank for ticker
  def get_rank(ticker) do
    case request_quote_summary(ticker) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parsed_result(body)
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        "[ZacksApi] Ticker not found"
      {:ok, %HTTPoison.Response{status_code: 302}} ->
        "[ZacksApi] Ticker not found(got redirect)"
      {:error, %HTTPoison.Error{reason: reason}} ->
        "[ZacksApi] Error: #{reason}"
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
    |> string_to_integer
  end

  defp find_score(body) do
    Regex.run(~r/(?<=(<span class="composite_val composite_val_vgm">))(\w)(?=(<\/span>&nbsp;VGM))/, body)
    |> List.wrap
    |> List.first
  end

  defp ticker_url(ticker) do
    "https://www.zacks.com/stock/quote/#{ ticker }?q=#{ ticker }"
  end

  defp string_to_integer(value) when not is_nil(value), do: String.to_integer(value)
  defp string_to_integer(value), do: value
end
