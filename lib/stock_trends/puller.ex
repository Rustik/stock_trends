defmodule StockTrends.Puller do
  alias StockTrends.TickerData
  alias StockTrends.TrendQuery
  # Get tickers from CSV, queries Yahoo API for finance data,
  # evaluate this data to get trend for ticker and save trend to database.
  #
  def call() do
    with_tickers()
    |> process_external_apis
    |> evaluate_trend
    |> save_trend
    |> finalize
  end

  def with_tickers() do
    System.get_env("TICKERS_CSV_PATH")
    |> File.stream!(read_ahead: 100_000)
    |> CSV.decode!(separator: ?|, headers: true)
    |> Flow.from_enumerable()
    |> Flow.map(fn row -> TickerData.new(row["Symbol"]) end)
    |> Flow.partition()
  end

  def process_external_apis(flow) do
    flow
    |> process_yahoo_data
    |> process_zacks_rank
    |> process_gurufocus_score
  end

  def process_yahoo_data(flow) do
    flow
    |> Flow.map(fn ticker_data ->
      get_yahoo_data(ticker_data.ticker)
      |> TickerData.apply_yahoo_data(ticker_data)
    end)
    |> Flow.filter(&TickerData.valid_yahoo_data?(&1))
    |> flow_log("got valid yahoo data..")
  end

  def process_zacks_rank(flow) do
    flow
    |> Flow.map(fn ticker_data ->
      get_zacks_rank(ticker_data.ticker)
      |> TickerData.apply_zacks_rank(ticker_data)
    end)
    |> Flow.filter(&TickerData.valid_zacks_rank?(&1))
    |> flow_log("got valid zacks rank..")
  end

  def process_gurufocus_score(flow) do
    flow
    |> Flow.map(fn ticker_data ->
      get_gurufocus_score(ticker_data.ticker)
      |> TickerData.apply_gurufocus_score(ticker_data)
    end)
    |> Flow.filter(&TickerData.valid_gurufocus_score?(&1))
    |> flow_log("got valid gurufocus score..")
  end

  def evaluate_trend(flow) do
    flow
    |> Flow.map(fn ticker_data ->
      _evaluate_trend(ticker_data)
      |> TickerData.set_trend(ticker_data)
    end)
    |> Flow.filter(&TickerData.trend_present?(&1))
    |> flow_log("trend evaluated..")
  end

  def save_trend(flow) do
    flow
    |> flow_log("saving trend..")
    |> Flow.each(fn ticker_data ->
      _save_trend(ticker_data)
    end)
  end

  def finalize(flow) do
    flow
    |> Enum.to_list
  end

  def flow_log(flow, message) do
    flow
    |> Flow.each(fn ticker_data ->
      log("#{ ticker_data.ticker } : #{ message }")
    end)
  end

  def get_yahoo_data(ticker) do
    StockTrends.YahooApi.pull_ticker(ticker)
  end

  defp get_zacks_rank(ticker) do
    StockTrends.ZacksApi.get_rank(ticker)
  end

  defp get_gurufocus_score(ticker) do
    StockTrends.GurufocusApi.get_score(ticker)
  end

  defp _evaluate_trend(ticker_data) do
    StockTrends.TrendEvaluator.call(ticker_data)
  end

  defp _save_trend(ticker_data) do
    !trend_exists?(ticker_data) && TrendQuery.create_trend(ticker_data)
  end

  # Check if trend is already exists in database
  defp trend_exists?(ticker_data) do
    TrendQuery.count(
      ticker: ticker_data.ticker,
      type: ticker_data.type,
      date: ticker_data.date
    ) > 0
  end

  defp log(message), do: IO.puts(message)
end
