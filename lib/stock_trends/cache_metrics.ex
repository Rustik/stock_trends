defmodule StockTrends.CacheMetrics do
  @table __MODULE__
  #
  # Generic Cache functions, used by Puller and LinkPuller
  #
  def generate_info do
    Map.put(metrics(), :processed_percent, processed_percent(metrics()))
  end

  def init_metrics do
    :ets.new(@table, [:set, :public, :named_table])
  end

  def metrics do
    if metrics_exists?(), do: read_table_content(), else: %{}
  end

  def metrics_exists? do
    Enum.member?(:ets.all(), @table)
  end

  def increase_metric(key, value \\ 1) do
    :ets.update_counter(@table, key, {2, value}, {key, 0}) # increment second element of tuple by 1
  end

  def set_metric(key, value) do
    :ets.insert(@table, {key, value})
  end

  defp read_table_content do
    :ets.tab2list(@table)
    |> Enum.into(%{})
  end

  # Calculate percentage of processed records
  defp processed_percent(%{processed: processed, count: count}) when is_number(processed) and is_number(count) and count > 0 and processed == count, do: 100

  defp processed_percent(%{processed: processed, count: count}) when is_number(processed) and is_number(count) and count > 0 and processed < count do
    round(processed * 100 / count)
  end

  defp processed_percent(_), do: nil
end
