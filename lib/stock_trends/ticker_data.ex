defmodule StockTrends.TickerData do
  defstruct [:ticker, :trailing_pe, :forward_pe, :peg_ratio_5yr, :price_sales_ttm, :total_debt, :enterprise_value, :short_percent_of_shares,
  :earnings_history_surprise_percent_current_qr, :earnings_history_surprise_percent_minus_1_qr, :earnings_history_surprise_percent_minus_2_qr,
  :earnings_history_surprise_percent_minus_3_qr, :type, :date]
end
