defmodule StockTrends.Dig do
  # Similar to Ruby's Hash#dig
  #
  def dig(nil, _), do: nil
  def dig(data, [key | keys]) when is_map(data) do
    dig(Map.get(data, key), keys)
  end

  def dig(data, [key | keys]) when is_list(data) do
    dig(Enum.at(data, key), keys)
  end

  def dig(data, []) do
    data
  end
end
