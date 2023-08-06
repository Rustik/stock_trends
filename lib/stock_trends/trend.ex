defmodule StockTrends.Trend do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trends" do
    field :date, :date
    field :ticker, :string
    field :type, :string
    field :trailing_pe, :float
    field :forward_pe, :float
    field :peg_ratio_5yr, :float
    field :price_sales_ttm, :float
    field :industry_earnings_pe_ivv, :float
    field :total_debt, :integer
    field :enterprise_value, :integer
    field :short_percent_of_shares, :float
    field :earnings_history_surprise_percent_current_qr, :float
    field :earnings_history_surprise_percent_minus_1_qr, :float
    field :earnings_history_surprise_percent_minus_2_qr, :float
    field :earnings_history_surprise_percent_minus_3_qr, :float
    field :zacks_rank, :integer
    field :zacks_style_scores, :string
    field :earnings_exp_eps_growth_3_5yrs, :float
    field :gurufocus_financial_strength, :integer
    field :gurufocus_profitability_rank, :integer
    field :lasts, :integer, virtual: true

    timestamps()
  end

  @doc false
  def changeset(trend, attrs) do
    trend
    |> cast(attrs, [:ticker, :type, :date, :trailing_pe, :forward_pe, :peg_ratio_5yr, :price_sales_ttm, :industry_earnings_pe_ivv, :total_debt,
      :enterprise_value, :short_percent_of_shares, :earnings_history_surprise_percent_current_qr, :earnings_history_surprise_percent_minus_1_qr,
      :earnings_history_surprise_percent_minus_2_qr, :earnings_history_surprise_percent_minus_3_qr, :zacks_rank, :zacks_style_scores,
      :earnings_exp_eps_growth_3_5yrs, :gurufocus_financial_strength, :gurufocus_profitability_rank])
    |> validate_required([:ticker, :type, :date])
  end
end
