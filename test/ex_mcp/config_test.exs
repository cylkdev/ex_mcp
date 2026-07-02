defmodule ExMCP.ConfigTest do
  use ExUnit.Case, async: true
  alias ExMCP.Config

  test "explicit opts win" do
    assert Config.get([protocol_version: "X"], :protocol_version) == "X"
  end

  test "falls back to built-in default" do
    assert Config.get([], :protocol_version) == "2025-06-18"
    assert Config.get([], :tools) == []
    assert Config.get([], :server_info) == %{"name" => "ex_mcp", "version" => "0.1.0"}
  end

  test "unknown key raises" do
    assert_raise KeyError, fn -> Config.get([], :allowed_origins) end
  end

end
