defmodule StockTrends.TrendEvaluator.Guards do
  # Long trend Earnings Surpise
  #
  # Last QR Earning is positive and other QRs are positive or its absolute values is less then positives
  # Example: 30, 40, -39, -10 valid
  # 10, -100, 50, 90 is not valid
  defguard earnings_list_match_long(e1, e2, e3, e4) when
    e1 > 0 and
    (e2 > 0 or (abs(e2) < e1 or abs(e2) < e3 or abs(e2) < e4)) and
    (e3 > 0 or (abs(e3) < e1 or abs(e3) < e2 or abs(e3) < e4)) and
    (e4 > 0 or (abs(e3) < e1 or abs(e4) < e2 or abs(e4) < e3))
  # Short trend Earnings Surpise
  #
  # Last QR Earning is negative and other QRs are negative or its values is less then absolute positives
  # Example: -30, 39, -40, 10 valid
  # -10, 100, -50, -90 is not valid
  defguard earnings_list_match_short(e1, e2, e3, e4) when
    e1 < 0 and
    (e2 < 0 or (e2 < abs(e1) or e2 < abs(e3) or e2 < abs(e4))) and
    (e3 < 0 or (e3 < abs(e1) or e3 < abs(e2) or e3 < abs(e4))) and
    (e4 < 0 or (e4 < abs(e1) or e4 < abs(e2) or e4 < abs(e3)))

  defguard good_zacks_score(zacks_score) when zacks_score == "A" or zacks_score == "B"

  defguard average_zacks_score(zacks_score) when zacks_score == "C"

  defguard good_zacks_rank(zacks_rank) when zacks_rank < 3

  defguard average_zacks_rank(zacks_rank) when zacks_rank == 3

  defguard good_zacks_rank_and_score(zacks_rank, zacks_score) when good_zacks_score(zacks_score) and good_zacks_rank(zacks_rank)

  defguard average_zacks_rank_but_good_exp_growth_rate(zacks_rank, zacks_score, exp_growth) when
    (good_zacks_score(zacks_score) and average_zacks_rank(zacks_rank)) or
    (average_zacks_score(zacks_score) and good_zacks_rank(zacks_rank)) or
    (
      average_zacks_score(zacks_score) and average_zacks_rank(zacks_rank) and exp_growth >= 15
    )

  defguard good_gurufocus_rank(strength, rank) when (strength + rank) >= 12
  defguard average_gurufocus_rank(strength, rank) when (strength + rank) >= 11

end
defmodule StockTrends.TrendEvaluator do
  import StockTrends.TrendEvaluator.Guards
  alias StockTrends.TickerData
  # Evaluates ticker financial data against strategy testers. The strongest strategies should be on top.
  # The hard coded values is not a constants and should be pulled from a different sources, but for now its ok.
  #
  def call(%TickerData{} = data) when
    data.trailing_pe > data.industry_earnings_pe_ivv + 3 and
    data.forward_pe > data.industry_earnings_pe_ivv + 3 and
    data.peg_ratio_5yr < 4 and
    #data.price_sales_ttm < 15 and
    data.short_percent_of_shares <= 0.1 and
    data.total_debt * 3 < data.enterprise_value and
    earnings_list_match_long(
      data.earnings_history_surprise_percent_current_qr,
      data.earnings_history_surprise_percent_minus_1_qr,
      data.earnings_history_surprise_percent_minus_2_qr,
      data.earnings_history_surprise_percent_minus_3_qr
    ) and
    (
      good_zacks_rank_and_score(data.zacks_rank, data.zacks_style_scores) or
      average_zacks_rank_but_good_exp_growth_rate(data.zacks_rank, data.zacks_style_scores, data.earnings_exp_eps_growth_3_5yrs)
    ),# and
    #(
    #  good_gurufocus_rank(data.gurufocus_financial_strength, data.gurufocus_profitability_rank) or
    #  average_gurufocus_rank(data.gurufocus_financial_strength, data.gurufocus_profitability_rank)
    #),
    do: "long"

  def call(%TickerData{} = data) when
    data.trailing_pe < data.industry_earnings_pe_ivv - 3 and
    data.forward_pe < data.industry_earnings_pe_ivv - 3 and
    #data.total_debt * 3 >= data.enterprise_value and
    earnings_list_match_short(
      data.earnings_history_surprise_percent_current_qr,
      data.earnings_history_surprise_percent_minus_1_qr,
      data.earnings_history_surprise_percent_minus_2_qr,
      data.earnings_history_surprise_percent_minus_3_qr
    ) and
    data.zacks_rank >= 3 and
    (data.zacks_style_scores != "A" and data.zacks_style_scores != "B"), #and
    #(data.gurufocus_financial_strength + data.gurufocus_profitability_rank) < 12,
    do: "short"

  def call(%TickerData{}), do: nil
end
