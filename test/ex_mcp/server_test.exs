defmodule ExMCP.ServerTest do
  use ExUnit.Case, async: true
  alias ExMCP.Server

  defmodule TokenTool do
    use ExMCP.Tool
    @impl true
    def spec, do: %{"name" => "tok", "description" => "d", "inputSchema" => %{"type" => "object", "properties" => %{}}}
    @impl true
    def call(_args, context), do: %{"content" => [%{"type" => "text", "text" => to_string(context.progress_token)}]}
  end

  @opts [
    server_info: %{"name" => "test", "version" => "9.9"},
    protocol_version: "2025-06-18",
    tools: [ExMCP.TestTools.Echo]
  ]

  defp req(method, params \\ %{}, id \\ 1) do
    %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
  end

  test "initialize returns configured protocol version, capability, and serverInfo" do
    resp = Server.handle(req("initialize"), @opts)
    assert resp["result"]["protocolVersion"] == "2025-06-18"
    assert resp["result"]["capabilities"]["tools"] == %{}
    assert resp["result"]["serverInfo"] == %{"name" => "test", "version" => "9.9"}
  end

  test "tools/list returns configured tools" do
    resp = Server.handle(req("tools/list"), @opts)
    assert [%{"name" => "echo"}] = resp["result"]["tools"]
  end

  test "an injected :registry is used in preference to building from :tools" do
    registry = ExMCP.Registry.build([ExMCP.TestTools.Echo])
    # :tools is empty, so only the injected registry can supply "echo".
    opts = [tools: [], registry: registry]
    resp = Server.handle(req("tools/list"), opts)
    assert [%{"name" => "echo"}] = resp["result"]["tools"]
  end

  test "tools/call runs the named tool" do
    resp = Server.handle(req("tools/call", %{"name" => "echo", "arguments" => %{"text" => "hi"}}), @opts)
    assert resp["result"]["content"] == [%{"type" => "text", "text" => "hi"}]
  end

  test "unknown method returns -32601" do
    assert Server.handle(req("does/not/exist"), @opts)["error"]["code"] == -32601
  end

  test "unknown tool returns -32602" do
    assert Server.handle(req("tools/call", %{"name" => "nope"}), @opts)["error"]["code"] == -32602
  end

  test "missing tool name returns -32602" do
    assert Server.handle(req("tools/call", %{}), @opts)["error"]["code"] == -32602
  end

  test "tools/call with non-map params returns -32602" do
    resp = Server.handle(%{"jsonrpc" => "2.0", "id" => 5, "method" => "tools/call", "params" => []}, @opts)
    assert resp["error"]["code"] == -32602
  end

  test "notification returns :noreply" do
    assert Server.handle(%{"jsonrpc" => "2.0", "method" => "initialized"}, @opts) == :noreply
  end

  test "batch array returns -32600 with null id" do
    resp = Server.handle([%{"jsonrpc" => "2.0", "method" => "ping"}], @opts)
    assert resp["id"] == nil and resp["error"]["code"] == -32600
  end

  test "request with null id returns -32600" do
    resp = Server.handle(%{"jsonrpc" => "2.0", "id" => nil, "method" => "tools/list"}, @opts)
    assert resp["id"] == nil and resp["error"]["code"] == -32600
  end

  test "internal exception in a tool yields -32603 with generic message" do
    resp = Server.handle(req("tools/call", %{"name" => "boom", "arguments" => %{}}), tools: [ExMCP.TestTools.Boom])
    assert resp["error"]["code"] == -32603
    assert resp["error"]["message"] == "Internal error"
  end

  test "tools/call threads params._meta.progressToken into the tool context" do
    req = %{
      "jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
      "params" => %{"name" => "tok", "arguments" => %{}, "_meta" => %{"progressToken" => "abc"}}
    }

    resp = ExMCP.Server.handle(req, tools: [TokenTool])
    assert resp["result"]["content"] == [%{"type" => "text", "text" => "abc"}]
  end
end
