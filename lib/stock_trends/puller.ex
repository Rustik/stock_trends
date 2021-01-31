defmodule StockTrends.Puller do
  import StockTrends.Dig
  alias StockTrends.TickerData
  # Get tickers from CSV, queries Yahoo API for finance data,
  # evaluate this data to get trend for ticker and save trend to database.
  #
  def call() do
    System.get_env("TICKERS_CSV_PATH")
    |> File.stream!(read_ahead: 100_000)
    |> CSV.decode!(separator: ?|, headers: true)
    |> Flow.from_enumerable()
    # Get ticker name and market category from CSV row.
    |> Flow.map(fn row ->
     %{
        ticker:          row["Symbol"],
        market_category: row["Market Category"] # Not used yet
      }
    end)
    |> Flow.partition()
    |> Flow.each(fn row ->
      process_ticker(row)
    end)
    # Don't know what should be there, we don't need to return anything here..
    |> Enum.to_list
  end

  # Get ticker data from Yahoo API, evaluate trend on it and save it to database.
  def process_ticker(%{ticker: ticker, market_category: market_category}) do
    IO.puts("Processing #{ticker}..")

    get_yahoo_ticker(ticker)
    |> transform_yahoo_response(ticker)
    |> apply_zacks_rank
    |> apply_gurufocus_score
    |> evaluate_and_populate_trend
    |> log_trend_found
    |> save_trend
  end

  defp get_yahoo_ticker(name) do
    StockTrends.YahooApi.pull_ticker(name)
  end

  defp transform_yahoo_response({:error, _}, _), do: %TickerData{}

  defp transform_yahoo_response({:ok, ticker_data}, ticker_name) do
    earnings = dig(ticker_data, ["earningsHistory", "history"]) || []
    q1 = Enum.find(earnings, fn e -> e["period"] == "-1q" end)
    q2 = Enum.find(earnings, fn e -> e["period"] == "-2q" end)
    q3 = Enum.find(earnings, fn e -> e["period"] == "-3q" end)
    q4 = Enum.find(earnings, fn e -> e["period"] == "-4q" end)
    %TickerData{
      ticker:                                       ticker_name,
      trailing_pe:                                  dig(ticker_data, ["summaryDetail", "trailingPE", "raw"]),
      forward_pe:                                   dig(ticker_data, ["summaryDetail", "forwardPE", "raw"]),
      peg_ratio_5yr:                                dig(ticker_data, ["defaultKeyStatistics", "pegRatio", "raw"]),
      price_sales_ttm:                              dig(ticker_data, ["summaryDetail", "priceToSalesTrailing12Months", "raw"]),
      total_debt:                                   dig(ticker_data, ["financialData", "totalDebt", "raw"]),
      enterprise_value:                             dig(ticker_data, ["defaultKeyStatistics", "enterpriseValue", "raw"]),
      short_percent_of_shares:                      dig(ticker_data, ["defaultKeyStatistics", "shortPercentOfFloat", "raw"]) || 0,
      earnings_history_surprise_percent_current_qr: dig(q1, ["surprisePercent", "raw"]),
      earnings_history_surprise_percent_minus_1_qr: dig(q2, ["surprisePercent", "raw"]),
      earnings_history_surprise_percent_minus_2_qr: dig(q3, ["surprisePercent", "raw"]),
      earnings_history_surprise_percent_minus_3_qr: dig(q4, ["surprisePercent", "raw"])
    }
  end

  # Zacks rank processing
  defp apply_zacks_rank(%TickerData{ticker: nil}), do: %TickerData{}

  defp apply_zacks_rank(%TickerData{ticker: ticker} = ticker_data) do
    get_zacks_rank(ticker)
    |> add_zacks_rank(ticker_data)
  end

  defp get_zacks_rank(ticker) do
    StockTrends.ZacksApi.get_rank(ticker)
  end

  defp add_zacks_rank({:error, _}, _), do: %TickerData{}

  defp add_zacks_rank({:ok, %{zacks_rank: zacks_rank, zacks_style_scores: zacks_style_scores}}, ticker_data) do
    %TickerData{ticker_data| zacks_rank: zacks_rank, zacks_style_scores: zacks_style_scores}
  end

  # Gurufocus processing
  defp apply_gurufocus_score(%TickerData{ticker: nil}), do: %TickerData{}

  defp apply_gurufocus_score(%TickerData{ticker: ticker} = ticker_data) do
    get_gurufocus_score(ticker)
    |> add_gurufocus_score(ticker_data)
  end

  defp get_gurufocus_score(ticker) do
    StockTrends.GurufocusApi.get_score(ticker)
  end

  defp add_gurufocus_score({:error, _}, _), do: %TickerData{}

  defp add_gurufocus_score({:ok, %{financial_strength: financial_strength, profitability_rank: profitability_rank}}, ticker_data) do
    %TickerData{ticker_data| gurufocus_financial_strength: financial_strength, gurufocus_profitability_rank: profitability_rank}
  end

  # Trend evaluation
  defp evaluate_and_populate_trend(%TickerData{ticker: nil}), do: %TickerData{}

  defp evaluate_and_populate_trend(%TickerData{} = ticker_data) do
    %TickerData{ticker_data| type: StockTrends.TrendEvaluator.call(ticker_data)}
  end

  defp save_trend(%{} = ticker_data) when map_size(ticker_data) == 0, do: false

  defp save_trend(%TickerData{} = ticker_data) do
    StockTrends.Trend.changeset(%StockTrends.Trend{}, %{Map.from_struct(ticker_data)| date: Date.utc_today})
    |> StockTrends.Repo.insert
  end

  # Log and return data
  defp log_trend_found(%TickerData{type: nil} = data), do: data

  defp log_trend_found(%TickerData{ticker: ticker, type: trend_type} = data) do
    IO.puts("Got #{trend_type} trend for: #{ticker}")
    data
  end
end
