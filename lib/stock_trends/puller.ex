defmodule StockTrends.Puller do
  alias StockTrends.TickerData
  alias StockTrends.TrendQuery
  @table __MODULE__
  #
  # Get tickers from CSV, queries financial APIs, process the data, evaluates trends and save it to database.
  #
  def call() do
    init_cache()
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
    |> log_csv_size()
    |> Flow.from_enumerable()
    |> Flow.map(fn row -> TickerData.new(row["Symbol"]) end)
    |> Flow.partition()
    |> record_processing_started()
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

  #
  # Logging functions
  #
  def log_csv_size(enumerable) do
    count = Enum.count(enumerable)
    log("processing tickers csv #{ count } rows")
    set_metric(:count, count)
    enumerable
  end

  def record_processing_started(flow) do
    flow
    |> Flow.each(fn ticker_data ->
      log("processing #{ ticker_data.ticker }..")
      increase_metric(:processed)
    end)
  end

  defp log(message), do: IO.puts(message)

  #
  # Metrics functions
  #
  def init_cache do
    :ets.new(@table, [:set, :public, :named_table])
  end

  def metrics do
    if metrics_exists?(), do: :ets.tab2list(@table), else: %{}
  end

  def metrics_exists? do
    Enum.member?(:ets.all(), @table)
  end

  def increase_metric(key) do
    :ets.update_counter(@table, key, {2, 1}, {key, 0}) # increment second element of tuple by 1
  end

  def set_metric(key, value) do
    :ets.insert(@table, {key, value})
  end

  defp get_yahoo_data(ticker) do
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
end
