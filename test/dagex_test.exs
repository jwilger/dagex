defmodule DagexTest do
  use ExUnit.Case
  doctest Dagex

  test "greets the world" do
    assert Dagex.hello() == :world
  end
end
