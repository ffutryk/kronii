defmodule KroniiTest do
  use ExUnit.Case
  doctest Kronii

  test "greets the world" do
    assert Kronii.hello() == :world
  end
end
