defmodule StockTrends.TrendsEvaluatorTest do
  use ExUnit.Case
  doctest StockTrends.TrendEvaluator.Guards

  test "Long trend Earnings Surpise" do
    assert StockTrends.TrendEvaluator.Guards.earnings_list_match_long(30, 40, -39, -10) == true
    assert StockTrends.TrendEvaluator.Guards.earnings_list_match_long(10, -100, 50, 90) == false
  end

  test "Short trend Earnings Surpise" do
    assert StockTrends.TrendEvaluator.Guards.earnings_list_match_short(-30, 39, -40, 10) == true
    assert StockTrends.TrendEvaluator.Guards.earnings_list_match_short(-10, 100, -50, -90) == false
  end
end
