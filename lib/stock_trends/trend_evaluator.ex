defmodule StockTrends.TrendEvaluator do
  alias StockTrends.TickerData
  # Evaluates ticker financial data against strategy testers. The strongest strategies should be on top.
  # The hard coded values is not a constants and should be pulled from a different sources, but for now its ok.
  #
  def call(%TickerData{} = data) when
    data.trailing_pe > data.industry_earnings_pe_ivv + 3 and
    data.forward_pe > data.industry_earnings_pe_ivv + 3 and
    data.peg_ratio_5yr < 3 and
    data.price_sales_ttm < 3 and
    data.short_percent_of_shares <= 0.1 and
    data.total_debt * 3 < data.enterprise_value and
    data.earnings_history_surprise_percent_current_qr > 0 and
    data.zacks_rank <= 3 and
    (data.zacks_style_scores == "A" or data.zacks_style_scores == "B" or data.zacks_style_scores == "C") and
    (data.gurufocus_financial_strength + data.gurufocus_profitability_rank) >= 12,
    do: "long"

  def call(%TickerData{} = data) when
    data.trailing_pe < data.industry_earnings_pe_ivv - 3 and
    data.forward_pe < data.industry_earnings_pe_ivv - 3 and
    #data.total_debt * 3 >= data.enterprise_value and
    data.earnings_history_surprise_percent_current_qr < 0 and
    (data.earnings_history_surprise_percent_minus_1_qr < 0 or data.earnings_history_surprise_percent_minus_2_qr < 0) and
    #data.earnings_history_surprise_percent_minus_3_qr < 0 and
    data.zacks_rank >= 4 and
    (data.zacks_style_scores != "A" and data.zacks_style_scores != "B") and
    (data.gurufocus_financial_strength + data.gurufocus_profitability_rank) < 12,
    do: "short"

  def call(%TickerData{}), do: nil
end
