defmodule StockTrends.Repo.Migrations.CreateTrends do
  use Ecto.Migration

  def change do
    create table(:trends) do
      add :ticker, :string, null: false
      add :type, :string, null: false
      add :date, :date, null: false, default: fragment("current_date")
      add :trailing_pe, :float
      add :forward_pe, :float
      add :peg_ratio_5yr, :float
      add :price_sales_ttm, :float
      add :industry_earnings_pe_ivv, :float
      add :total_debt, :bigint
      add :enterprise_value, :bigint
      add :short_percent_of_shares, :float
      add :earnings_history_surprise_percent_current_qr, :float
      add :earnings_history_surprise_percent_minus_1_qr, :float
      add :earnings_history_surprise_percent_minus_2_qr, :float
      add :earnings_history_surprise_percent_minus_3_qr, :float
      add :zacks_rank, :integer
      add :zacks_style_scores, :string
      add :earnings_exp_eps_growth_3_5yrs, :float
      add :gurufocus_financial_strength, :integer
      add :gurufocus_profitability_rank, :integer
      add :position, :integer

      timestamps()
    end
    create index(:trends, [:ticker])
    create index(:trends, [:type])
    create index(:trends, [:date])
    create index(:trends, [:date, :type])
    create index(:trends, [:position])
    create unique_index(:trends, [:ticker, :date])
  end
end
