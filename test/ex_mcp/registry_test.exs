defmodule ExMCP.RegistryTest do
  use ExUnit.Case, async: true
  alias ExMCP.Registry

  defmodule CtxTool do
    use ExMCP.Tool
    @impl true
    def spec, do: %{"name" => "ctxtool", "description" => "d", "inputSchema" => %{"type" => "object", "properties" => %{}}}
    @impl true
    def call(_args, context), do: %{"content" => [%{"type" => "text", "text" => context.progress_token || "none"}]}
  end

  test "builds specs from multiple behaviour modules" do
    reg = Registry.build([ExMCP.TestTools.Echo, ExMCP.TestTools.Accounts])
    names = reg |> Registry.specs() |> Enum.map(& &1["name"]) |> Enum.sort()
    assert names == ["echo", "get_user"]
  end

  test "invoke routes to a behaviour tool" do
    reg = Registry.build([ExMCP.TestTools.Echo])
    assert {:ok, %{"content" => [%{"text" => "hi"}]}} = Registry.invoke(reg, "echo", %{"text" => "hi"})
  end

  test "invoke routes to a second behaviour tool" do
    reg = Registry.build([ExMCP.TestTools.Accounts])
    assert {:ok, %{"content" => [%{"text" => "user:42"}]}} = Registry.invoke(reg, "get_user", %{"id" => "42"})
  end

  test "invoke returns :unknown for an unregistered name" do
    reg = Registry.build([ExMCP.TestTools.Echo])
    assert Registry.invoke(reg, "nope", %{}) == :unknown
  end

  test "duplicate tool names raise at build time" do
    assert_raise ArgumentError, ~r/duplicate/i, fn ->
      Registry.build([ExMCP.TestTools.Echo, ExMCP.TestTools.Echo])
    end
  end

  test "cached/1 memoizes by module list and returns a working registry" do
    r1 = Registry.cached([ExMCP.TestTools.Echo])
    r2 = Registry.cached([ExMCP.TestTools.Echo])

    # Same memoized term, and the stored term is what subsequent calls read.
    assert r1 == r2
    assert :persistent_term.get({Registry, [ExMCP.TestTools.Echo]}) == r1
    assert {:ok, %{"content" => [%{"text" => "hi"}]}} = Registry.invoke(r1, "echo", %{"text" => "hi"})
  end

  test "cached/1 keys distinct tool lists separately" do
    echo = Registry.cached([ExMCP.TestTools.Echo])
    accounts = Registry.cached([ExMCP.TestTools.Accounts])

    assert Registry.specs(echo) |> Enum.map(& &1["name"]) == ["echo"]
    assert Registry.specs(accounts) |> Enum.map(& &1["name"]) == ["get_user"]
  end

  test "invoke/4 routes to call/2 with the context when the tool exports it" do
    reg = Registry.build([CtxTool])
    ctx = %ExMCP.Tool.Context{progress_token: "tok"}
    assert {:ok, %{"content" => [%{"text" => "tok"}]}} = Registry.invoke(reg, "ctxtool", %{}, ctx)
  end

  test "invoke/3 still works for a call/1-only tool (back-compat)" do
    reg = Registry.build([ExMCP.TestTools.Echo])
    assert {:ok, %{"content" => [%{"text" => "hi"}]}} = Registry.invoke(reg, "echo", %{"text" => "hi"})
  end
end
