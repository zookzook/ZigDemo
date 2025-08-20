defmodule ZigDemoTest do
  use ExUnit.Case
  doctest ZigDemo

  test "greets the world" do
    assert ZigDemo.hello() == :world
  end
end
