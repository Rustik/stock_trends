defmodule StockTrends.ZacksApi do
  use Retry
  import Stream

  # Get zacks rank for ticker
  def get_rank(ticker) do
    case request_quote_summary_with_retry(ticker) do
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

  # Get common infustry earnings rate
  def get_industry_earnings() do
    case request_industry_earnings_with_retry() do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parsed_industry_earnings(body)
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        "[ZacksApi] Ticker not found"
      {:ok, %HTTPoison.Response{status_code: 302}} ->
        "[ZacksApi] Ticker not found(got redirect)"
      {:error, %HTTPoison.Error{reason: reason}} ->
        "[ZacksApi] Error: #{reason}"
    end
  end

  defp request_industry_earnings_with_retry() do
    retry_while with: linear_backoff(10, 1) |> take(15) do
      request_industry_rank()
      |> case do
        result = {:ok, %HTTPoison.Response{status_code: 200}} -> {:halt, result}
        result -> {:cont, result}
        #result = {:ok, %HTTPoison.Response{status_code: 404}} -> {:cont, result}
        #result = {:ok, %HTTPoison.Response{status_code: 302}} -> {:cont, result}
        #result = {:error, %HTTPoison.Error{reason: results}} -> {:cont, result}
        #result -> {:halt, result}
      end
    end
  end

  defp request_quote_summary_with_retry(ticker) do
    retry_while with: linear_backoff(10, 1) |> take(15) do
      request_quote_summary(ticker)
      |> case do
        result = {:ok, %HTTPoison.Response{status_code: 200}} -> {:halt, result}
        result -> {:cont, result}
        #result = {:ok, %HTTPoison.Response{status_code: 404}} -> {:cont, result}
        #result = {:ok, %HTTPoison.Response{status_code: 302}} -> {:cont, result}
        #result = {:error, %HTTPoison.Error{reason: results}} -> {:cont, result}
        #result -> {:halt, result}
      end
    end
  end

  defp request_quote_summary(ticker) do
    request(ticker_url(ticker))
  end

  # industry rank is the same for all industries, so we just get it from a random industry
  defp request_industry_rank() do
    request("https://www.zacks.com/stocks/industry-rank/industry/uniform-and-related-93")
  end

  defp request(url) do
    HTTPoison.get(url, ["Referer": "https://www.zacks.com", "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"], hackney: [cookie: "incap_ses_130_2944342=5WO5bTBT7x0dTNoIUtrNAeGJtmQAAAAAnSmkk2zliCS5sFXNW7hqMQ==; visid_incap_2944342=2yTjz5SZRYaN+AC9agQd5eGJtmQAAAAAQUIPAAAAAAAEgOTjJ7Titia2CAgQtNfL"])
  end

  defp parsed_result(body) do
    %{zacks_rank: find_rank(body), zacks_style_scores: find_score(body), earnings_exp_eps_growth_3_5yrs: find_exp_growth(body)}
  end

  defp parsed_industry_earnings(body) do
    #Regex.run(~r/todo:add regex here/, body)
    18.52
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

  defp find_exp_growth(body) do
    Regex.run(~r/(?<=(Exp EPS Growth <span class=\"year\">\(3-5yr\)<\/span><\/a><\/dt>\n\s{4}<dd><p class=\"up float_right\">))(\d*\.?\d+)(?=(%<\/p><\/dd>))/, body)
    |> List.wrap
    |> List.first
    |> string_to_float
  end

  defp ticker_url(ticker) do
    "https://www.zacks.com/stock/quote/#{ ticker }?q=#{ ticker }"
  end

  defp string_to_integer(value) when not is_nil(value), do: String.to_integer(value)
  defp string_to_integer(value), do: value

  defp string_to_float(value) when not is_nil(value), do: String.to_float(value)
  defp string_to_float(value), do: value
end
