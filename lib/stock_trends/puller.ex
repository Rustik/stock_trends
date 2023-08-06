defmodule StockTrends.Puller do
  alias StockTrends.TickerData
  alias StockTrends.TrendQuery
  import StockTrends.CacheMetrics
  #
  # Get tickers from CSV, queries financial APIs, process the data, evaluates trends and save it to database.
  #
  def call() do
    on_start()
    with_tickers()
    |> process_external_apis
    |> evaluate_trend
    |> save_trend
    |> finalize
  end

  def with_tickers() do
    System.get_env("TICKERS_CSV_PATH")
    |> File.stream!(read_ahead: 10_000)
    |> CSV.decode!(separator: ?|, headers: true)
    |> on_csv_read()
    |> Flow.from_enumerable()
    |> Flow.map(fn row -> TickerData.new(row["Symbol"], metrics()[:industry_earnings_pe_ivv]) end)
    |> Flow.partition(stages: 4) # 4 request per sec for yahoo api
    |> on_tickers_read()
  end

  def process_external_apis(flow) do
    flow
    |> process_yahoo_data
    |> process_zacks_rank
    #|> process_gurufocus_score
  end

  def process_yahoo_data(flow) do
    flow
    |> Flow.map(fn ticker_data ->
      Process.sleep(1000)
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
      #log(ticker_data)
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
    on_complete()
  end

  def flow_log(flow, message) do
    flow
    |> Flow.each(fn ticker_data ->
      log("#{ ticker_data.ticker } : #{ message }")
    end)
  end

  #
  # Callbacks
  #
  def on_start do
    init_metrics()
    log("puller started")
    set_metric(:status, "started")
    log("[ZacksApi] getting industry earnings rate..")
    #industry_earnings_rate = StockTrends.ZacksApi.get_industry_earnings()
    industry_earnings_rate = 17.13
    log("Setting industry earnings rate value of #{ industry_earnings_rate }")
    set_metric(:industry_earnings_pe_ivv, industry_earnings_rate)
  end

  def on_tickers_read(flow) do
    flow
    |> Flow.each(fn ticker_data ->
      log("processing #{ ticker_data.ticker }..")
      increase_metric(:processed)
    end)
  end

  def on_csv_read(enumerable) do
    count = Enum.count(enumerable)
    log("processing tickers csv #{ count } rows")
    set_metric(:count, count)
    enumerable
  end

  def on_complete do
    set_metric(:status, "ready")
  end

  defp log(message), do: IO.puts(message)

  defp get_yahoo_data(ticker) do
    log("pull yahoo api for #{ ticker }..")
    StockTrends.YahooApi.pull_ticker(ticker)
  end

  defp get_zacks_rank(ticker) do
    log("pull zacks api for #{ ticker }..")
    StockTrends.ZacksApi.get_rank(ticker)
  end

  defp get_gurufocus_score(ticker) do
    log("pull gurufocus api for #{ ticker }..")
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
end
