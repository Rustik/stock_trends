defmodule StockTrends.Puller do
  alias StockTrends.TickerData
  alias StockTrends.TrendQuery
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
        ticker: row["Symbol"],
        #market_category: row["Market Category"] # Not used yet
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
  def process_ticker(%{ticker: ticker}) do
    IO.puts("Processing #{ticker}..")

    get_yahoo_ticker(ticker)
    |> transform_yahoo_response(ticker)
    |> apply_zacks_rank
    |> filter_zacks_data
    |> apply_gurufocus_score
    |> evaluate_and_populate_trend
    |> filter_trend
    |> set_date
    |> log_trend_found
    |> save_trend
  end

  def get_yahoo_ticker(name) do
    StockTrends.YahooApi.pull_ticker(name)
  end

  def transform_yahoo_response({:error, _}, _), do: %TickerData{}

  def transform_yahoo_response({:ok,
    %{
      "summaryDetail" => %{
        "trailingPE" => %{
          "raw" => trailing_pe
        },
        "forwardPE" => %{
          "raw" => forward_pe
        },
        "priceToSalesTrailing12Months" => %{
          "raw" => price_sales_ttm
        }
      },
      "defaultKeyStatistics" => %{
        "enterpriseValue" => %{
          "raw" => enterprise_value
        },
        "shortPercentOfFloat" => %{
          "raw" => short_percent_of_shares
        },
        "pegRatio" => %{
          "raw" => peg_ratio_5yr
        },
      },
      "earningsHistory" => %{
        "history" => [
          %{
          "surprisePercent" => %{
            "raw" => earnings_history_surprise_percent_minus_3_qr
          },
          "period" => "-4q"
        }, %{
          "surprisePercent" => %{
            "raw" => earnings_history_surprise_percent_minus_2_qr
          },
          "period" => "-3q"
        }, %{
          "surprisePercent" => %{
            "raw" => earnings_history_surprise_percent_minus_1_qr
          },
          "period" => "-2q"
        }, %{
          "surprisePercent" => %{
            "raw" => earnings_history_surprise_percent_current_qr
          },
          "period" => "-1q"
        }
        ],
      },
      "financialData" => %{
        "totalDebt" => %{
          "raw" => total_debt
        }
      }
    }} = ticker_data, ticker_name) do

    %TickerData{
      ticker:                                       ticker_name,
      trailing_pe:                                  trailing_pe || yahoo_response_alt_trailing_pe(ticker_data),
      forward_pe:                                   forward_pe  || yahoo_response_alt_forward_pe(ticker_data),
      peg_ratio_5yr:                                peg_ratio_5yr,
      price_sales_ttm:                              price_sales_ttm,
      total_debt:                                   total_debt,
      enterprise_value:                             enterprise_value,
      short_percent_of_shares:                      short_percent_of_shares || 0,
      earnings_history_surprise_percent_current_qr: earnings_history_surprise_percent_current_qr,
      earnings_history_surprise_percent_minus_1_qr: earnings_history_surprise_percent_minus_1_qr,
      earnings_history_surprise_percent_minus_2_qr: earnings_history_surprise_percent_minus_2_qr,
      earnings_history_surprise_percent_minus_3_qr: earnings_history_surprise_percent_minus_3_qr,
      industry_earnings_pe_ivv:                     20.33 # TODO pull real value from external source
    }
  end

  def transform_yahoo_response({:ok, _}, ticker_name) do
    IO.puts("Missing data for #{ticker_name}, skipped")
    %TickerData{}
  end

  # Alternative places for pe values
  defp yahoo_response_alt_trailing_pe({:ok,
    %{
      "defaultKeyStatistics" => %{
        "trailingPE" => %{
          "raw" => value
        }
      }
    }
  }) do
    value
  end

  defp yahoo_response_alt_forward_pe({:ok,
    %{
      "defaultKeyStatistics" => %{
        "forwardPE" => %{
          "raw" => value
        }
      }
    }
  }) do
    value
  end

  # Skip data without zacks rank
  defp filter_zacks_data(%TickerData{zacks_rank: nil}), do: %TickerData{}

  defp filter_zacks_data(%TickerData{} = ticker_data), do: ticker_data

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

  defp set_date(%TickerData{ticker: nil}), do: %TickerData{}
  defp set_date(%TickerData{} = ticker_data) do
    %TickerData{ticker_data| date: Date.utc_today}
  end

  # Filter trend after evaluation
  defp filter_trend(%TickerData{type: nil}), do: %TickerData{}
  defp filter_trend(%{} = ticker_data) when map_size(ticker_data) == 0, do: %TickerData{}
  defp filter_trend(%{} = ticker_data), do: ticker_data

  # Check if trend is already exists
  defp trend_exists?(%{} = ticker_data) when map_size(ticker_data) == 0, do: false
  defp trend_exists?(%TickerData{type: nil}), do: false

  defp trend_exists?(%TickerData{ticker: ticker, date: date, type: type}) do
    TrendQuery.count(
      ticker: ticker,
      type: type,
      date: date
    ) > 0
  end

  defp save_trend(%{} = ticker_data) when map_size(ticker_data) == 0, do: false

  defp save_trend(%TickerData{} = ticker_data) do
    !trend_exists?(ticker_data) && TrendQuery.create_trend(ticker_data)
  end

  # Log and return data
  defp log_trend_found(%TickerData{type: nil} = data), do: data

  defp log_trend_found(%TickerData{ticker: ticker, type: trend_type} = data) do
    IO.puts("Got #{trend_type} trend for: #{ticker}")
    data
  end
end
