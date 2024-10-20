defmodule StockTrends.YahooApi do
  # Get ticker data from Yahoo API
  def pull_ticker(ticker) do
    case request_quote_summary(ticker) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parsed_result(body)
      {:error, %HTTPoison.Error{reason: reason}} ->
        "[YahooApi] Error: #{reason}"
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        "[YahooApi] Ticker not found"
      {:ok, %HTTPoison.Response{status_code: 429}} ->
        IO.puts("[YahooApi] too many requests (#{ticker}), waiting..")
        :timer.sleep(1000)
      {status, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("[YahooApi] unknown error: #{status} #{status_code}")
        pull_ticker(ticker)
      #{:ok, %HTTPoison.Response{status_code: 502, body: body}} ->
      #  pull_ticker(ticker)
      #{:error, %HTTPoison.Error{reason: "timeout"}} ->
      #  pull_ticker(ticker)
      #{:error, %HTTPoison.Error{reason: reason}} ->
      #  "[YahooApi] Error: #{reason}"
    end
  end

  defp request_quote_summary(ticker) do
    ticker_url(ticker)
    |> HTTPoison.get(%{}, hackney: [cookie: "GUCS=AViGPulN; GUC=AQABCAFllahlx0IgfAR9&s=AQAAAAOTb0N2&g=ZZRapg; A1=d=AQABBIO3s2QCEI55_qD5fJc1uRyNu0xDqvoFEgABCAGolWXHZei6H5kB9qMAAAcIg7ezZExDqvo&S=AQAAAlvqVssKj79FHAgU2YoMsII; A3=d=AQABBIO3s2QCEI55_qD5fJc1uRyNu0xDqvoFEgABCAGolWXHZei6H5kB9qMAAAcIg7ezZExDqvo&S=AQAAAlvqVssKj79FHAgU2YoMsII; A1S=d=AQABBIO3s2QCEI55_qD5fJc1uRyNu0xDqvoFEgABCAGolWXHZei6H5kB9qMAAAcIg7ezZExDqvo&S=AQAAAlvqVssKj79FHAgU2YoMsII; cmp=t=1704221342&j=1&u=1---&v=103; EuConsent=CPvQekAPvQekAAOACBENDfCoAP_AAEfAACiQJhNB9G7WTXNncXp-YPs0OYUX0VBJ4MAwBgCBAcABzBIUIAwGRmAzJEyIICgCGAIAIGJBIABtGAlAQEAQYIAFAAFIAEEAJBAAIGAAECAAAABACAAAAAAAAAAQgUAXMBQgkAZEAFoIQUhAlgAgAQAAIAAEIIhBAgQAEAAAQABICAAIgCgAAgAAAAAAAAAEAFAIEQAAAAECBo9kfQTBABINSogCbAgJCYQMIoUQIgoCACgQAAAAECAAAAmCAoQBgEiMBkAIEQABAAAAAAQEQCAAACABCAAIAgwQAAAAAQAAAAQCAAAEAAAAAAAAAAAAAAAAAAAAAAAgAIAAhBAACAACAAgoAAIABAAAAAAAAIARCAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAQIAAAAAAACAgILADDQAYAAiCgIgAwABEFAVABgACIKA;"])
  end

  defp parsed_result(body) do
    Jason.decode!(body)
    |> extract_result
    |> transform_yahoo_data
  end

  defp extract_result(%{"quoteSummary" => %{"error" => nil, "result" => [result]}}), do: result

  defp transform_yahoo_data(%{ "summaryDetail" => summary_detail, "defaultKeyStatistics" => default_key_statistics, "earningsHistory" => earnings_history, "financialData" => financial_data }) do
    trailing_pe = lookup_map(summary_detail, "trailingPE") || lookup_map(default_key_statistics, "trailingPE")
    forward_pe = lookup_map(summary_detail, "forwardPE") || lookup_map(default_key_statistics, "forwardPE")

    %{
      trailing_pe:                                  trailing_pe,
      forward_pe:                                   forward_pe,
      peg_ratio_5yr:                                lookup_map(default_key_statistics, "pegRatio"),
      price_sales_ttm:                              lookup_map(summary_detail, "priceToSalesTrailing12Months"),
      total_debt:                                   lookup_map(financial_data, "totalDebt"),
      enterprise_value:                             lookup_map(default_key_statistics, "enterpriseValue"),
      short_percent_of_shares:                      lookup_map(default_key_statistics, "shortPercentOfFloat"),
      earnings_history_surprise_percent_current_qr: lookup_earnings_history(earnings_history, "-1q"),
      earnings_history_surprise_percent_minus_1_qr: lookup_earnings_history(earnings_history, "-2q"),
      earnings_history_surprise_percent_minus_2_qr: lookup_earnings_history(earnings_history, "-3q"),
      earnings_history_surprise_percent_minus_3_qr: lookup_earnings_history(earnings_history, "-4q")
    }
  end

  defp transform_yahoo_data(data) do
    "Yahoo response does not contain all required fields, only #{ listed_keys(data) }"
  end

  defp listed_keys(data) do
    Map.keys(data)
    |> Enum.join(", ")
  end

  defp lookup_map(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> get_raw_data(value)
      :error -> nil
    end
  end

  defp lookup_earnings_history(earnings_history, period) do
    #IO.inspect(earnings_history["history"])
    earnings_history["history"]
    |> Enum.find(fn h -> earnings_history_match?(h, period) end)
    |> get_value_from_result
  end

  defp get_value_from_result(nil), do: nil
  defp get_value_from_result(%{ "surprisePercent" => result }), do: get_raw_data(result)

  defp earnings_history_match?(%{ "period" => period }, match_period), do: period == match_period

  # Gets value from `raw` block:
  # When `number`
  defp get_raw_data(val) when is_number(val), do: val
  # When `raw => {"raw" => value}`
  defp get_raw_data(%{ "raw" => val }), do: val
  # When `raw => {}`
  defp get_raw_data(%{}), do: nil

  defp ticker_url(ticker) do
    "https://query#{:rand.uniform(2)}.finance.yahoo.com/v10/finance/quoteSummary/#{ticker}?modules=summaryDetail%2CdefaultKeyStatistics%2CfinancialData%2CearningsHistory&crumb=.twOtouHgjS"
  end
end
