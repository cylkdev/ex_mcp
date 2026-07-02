defmodule ExMCP.ToolTest do
  use ExUnit.Case, async: true

  test "Echo fixture implements the behaviour" do
    assert ExMCP.TestTools.Echo.spec()["name"] == "echo"
    assert ExMCP.TestTools.Echo.call(%{"text" => "hi"}) ==
             %{"content" => [%{"type" => "text", "text" => "hi"}]}
  end
end
