defmodule StockTrends.TrendEvaluator do
  alias StockTrends.TickerData
  # Evaluates ticker financial data against strategy testers. The strongest strategies should be on top.
  # The hard coded values is not a constants and should be pulled from a different sources, but for now its ok.
  #
  def call(%TickerData{} = data) when
    data.trailing_pe > 21 and
    data.forward_pe > 21 and
    data.peg_ratio_5yr < 3 and
    data.price_sales_ttm < 3 and
    data.short_percent_of_shares <= 10 and
    data.total_debt * 3 < data.enterprise_value and
    data.earnings_history_surprise_percent_current_qr > 0,
    do: "long"

  def call(%TickerData{} = data) when
    data.trailing_pe < 18 and
    data.forward_pe < 18 and
    data.total_debt * 3 >= data.enterprise_value and
    data.earnings_history_surprise_percent_current_qr < 0 and
    data.earnings_history_surprise_percent_minus_1_qr < 0 and
    data.earnings_history_surprise_percent_minus_2_qr < 0,
    do: "short"

  def call(%TickerData{}), do: nil
end
