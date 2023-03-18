defmodule StockTrends.TickerData do
  alias __MODULE__
  defstruct [:ticker, :trailing_pe, :forward_pe, :peg_ratio_5yr, :price_sales_ttm, :total_debt, :enterprise_value, :short_percent_of_shares,
  :earnings_history_surprise_percent_current_qr, :earnings_history_surprise_percent_minus_1_qr, :earnings_history_surprise_percent_minus_2_qr,
  :earnings_history_surprise_percent_minus_3_qr, :type, :date, :zacks_rank, :zacks_style_scores, :gurufocus_financial_strength,
  :gurufocus_profitability_rank, :industry_earnings_pe_ivv, :earnings_exp_eps_growth_3_5yrs]

  def new(name, industry_earnings_pe_ivv) do
    %TickerData{ ticker: name, industry_earnings_pe_ivv: industry_earnings_pe_ivv, date: Date.utc_today }
  end

  def apply_yahoo_data(yahoo_data, ticker_data) when is_map(yahoo_data) do
    %TickerData{ ticker_data |
      trailing_pe:                                  yahoo_data.trailing_pe,
      forward_pe:                                   yahoo_data.forward_pe,
      peg_ratio_5yr:                                yahoo_data.peg_ratio_5yr,
      price_sales_ttm:                              yahoo_data.price_sales_ttm,
      total_debt:                                   yahoo_data.total_debt,
      enterprise_value:                             yahoo_data.enterprise_value,
      short_percent_of_shares:                      yahoo_data.short_percent_of_shares,
      earnings_history_surprise_percent_current_qr: yahoo_data.earnings_history_surprise_percent_current_qr,
      earnings_history_surprise_percent_minus_1_qr: yahoo_data.earnings_history_surprise_percent_minus_1_qr,
      earnings_history_surprise_percent_minus_2_qr: yahoo_data.earnings_history_surprise_percent_minus_2_qr,
      earnings_history_surprise_percent_minus_3_qr: yahoo_data.earnings_history_surprise_percent_minus_3_qr
    }
  end

  def apply_yahoo_data(yahoo_data, ticker_data) do
    IO.puts("#{ ticker_data.ticker } Got error from yahoo: #{ yahoo_data }")
    ticker_data
  end

  # Validate presence of required fields
  def valid_yahoo_data?(ticker_data) do
    is_number(ticker_data.trailing_pe) and
    is_number(ticker_data.forward_pe) and
    is_number(ticker_data.peg_ratio_5yr) and
    is_number(ticker_data.price_sales_ttm) and
    is_number(ticker_data.total_debt) and
    is_number(ticker_data.enterprise_value) and
    is_number(ticker_data.earnings_history_surprise_percent_current_qr)
  end

  def apply_zacks_rank(zacks_rank, ticker_data) when is_map(zacks_rank) do
    %TickerData{ ticker_data |
      zacks_rank: zacks_rank.zacks_rank,
      zacks_style_scores: zacks_rank.zacks_style_scores,
      earnings_exp_eps_growth_3_5yrs: zacks_rank.earnings_exp_eps_growth_3_5yrs
    }
  end

  def apply_zacks_rank(zacks_rank, ticker_data) do
    IO.puts("#{ ticker_data.ticker } Got error from zacks: #{ zacks_rank }")
    ticker_data
  end

  # Validate presence of required fields
  def valid_zacks_rank?(ticker_data) do
    is_number(ticker_data.zacks_rank) and
    not is_nil(ticker_data.zacks_style_scores)
  end

  def apply_gurufocus_score(gurufocus_score, ticker_data) when is_map(gurufocus_score) do
    %TickerData{ ticker_data |
      gurufocus_financial_strength: gurufocus_score.financial_strength,
      gurufocus_profitability_rank: gurufocus_score.profitability_rank
    }
  end

  def apply_gurufocus_score(gurufocus_score, ticker_data) do
    IO.puts("#{ ticker_data.ticker } Got error from gurufocus: #{ gurufocus_score }")
    ticker_data
  end

  # Validate presence of required fields
  def valid_gurufocus_score?(ticker_data) do
    is_number(ticker_data.gurufocus_financial_strength) and
    is_number(ticker_data.gurufocus_profitability_rank)
  end

  def set_trend(trend, ticker_data) do
    %TickerData{ ticker_data | type: trend }
  end

  def trend_present?(ticker_data), do: not is_nil(ticker_data.type)
end
