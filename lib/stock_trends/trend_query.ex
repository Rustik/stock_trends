defmodule StockTrends.TrendQuery do

  import Ecto.Query, warn: false
  alias StockTrends.Repo

  alias StockTrends.Trend

  def list_trends do
    Repo.all(Trend)
  end

  def list_trends(criteria) when is_list(criteria) do
    build_from_criteria(criteria)
    |> Repo.all()
  end

  def count(criteria) when is_list(criteria) do
    build_from_criteria(criteria)
    |> Repo.aggregate(:count)
  end

  def last_updated_at(criteria) when is_list(criteria) do
    build_from_criteria(criteria)
    |> Repo.aggregate(:max, :updated_at)
  end

  def get_trend!(id), do: Repo.get!(Trend, id)

  def create_trend(attrs \\ %{}) do
    Trend.changeset(%Trend{}, Map.from_struct(attrs))
    |> Repo.insert
  end

  # TODO move `lasts` column to db (cache)
  defp build_from_criteria(criteria) do
    query = from t in Trend,
      select: %{
         t |
         lasts: fragment("
         (
          SELECT
        		MAX(ROW_NUMBER)
        	FROM
        		(
        			SELECT
        				ROW_NUMBER() OVER (
        					PARTITION BY ticker,
        					TYPE,
        					grp
        					ORDER BY
        						DATE
        				)
        			FROM
        				(
        					SELECT
        						*,
        						DATE - '2000-01-01'::DATE - ROW_NUMBER() OVER (
        							PARTITION BY ticker,
        							TYPE
        							ORDER BY
        								DATE
        						) AS grp
        					FROM
        						trends
        					WHERE
        						ticker = t0.ticker
        						AND TYPE = t0.type
        				) sub0
        		) sub1
          )
         ")
       }

    Enum.reduce(criteria, query, fn
      {:paginate, %{page: page, per_page: per_page}}, query ->
        from q in query,
          offset: ^((page - 1) * per_page),
          limit: ^per_page

      {:sort, %{sort_by: sort_by, sort_order: sort_order}}, query ->
        from q in query, order_by: [{^sort_order, ^sort_by}]

      {:type, type}, query ->
        from q in query, where: q.type == ^type

      {:date, date}, query ->
        from q in query, where: q.date == ^date

      {:ticker, ticker}, query ->
        from q in query, where: q.ticker == ^ticker
    end)
  end
end
