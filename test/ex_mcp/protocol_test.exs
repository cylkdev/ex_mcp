defmodule ExMCP.ProtocolTest do
  use ExUnit.Case, async: true
  alias ExMCP.Protocol

  test "standard error codes" do
    assert Protocol.parse_error() == -32700
    assert Protocol.invalid_request() == -32600
    assert Protocol.method_not_found() == -32601
    assert Protocol.invalid_params() == -32602
    assert Protocol.internal_error() == -32603
  end

  test "classify a well-formed request" do
    msg = %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping", "params" => %{"a" => 1}}
    assert Protocol.classify(msg) == {:request, 1, "ping", %{"a" => 1}}
  end

  test "classify a request with null id is invalid" do
    assert {:invalid, nil, _} = Protocol.classify(%{"jsonrpc" => "2.0", "id" => nil, "method" => "ping"})
  end

  test "classify a notification has no id" do
    assert Protocol.classify(%{"jsonrpc" => "2.0", "method" => "initialized"}) == {:notification, "initialized", %{}}
  end

  test "missing jsonrpc field is invalid request" do
    assert {:invalid, 1, _} = Protocol.classify(%{"id" => 1, "method" => "ping"})
  end

  test "non-string method is invalid request" do
    assert {:invalid, 1, _} = Protocol.classify(%{"jsonrpc" => "2.0", "id" => 1, "method" => 5})
  end

  test "batch array is rejected" do
    assert {:invalid, nil, _} = Protocol.classify([%{"jsonrpc" => "2.0", "method" => "ping"}])
  end

  test "result/2 builds a spec-shaped response" do
    assert Protocol.result(7, %{"ok" => true}) == %{"jsonrpc" => "2.0", "id" => 7, "result" => %{"ok" => true}}
  end

  test "error/3 builds a spec-shaped error object" do
    assert Protocol.error(nil, -32700, "Parse error") ==
             %{"jsonrpc" => "2.0", "id" => nil, "error" => %{"code" => -32700, "message" => "Parse error"}}
  end

  test "notification/2 builds a JSON-RPC notification (no id)" do
    msg = ExMCP.Protocol.notification("notifications/progress", %{"progressToken" => "t", "progress" => 1})
    assert msg == %{
             "jsonrpc" => "2.0",
             "method" => "notifications/progress",
             "params" => %{"progressToken" => "t", "progress" => 1}
           }
    refute Map.has_key?(msg, "id")
  end
end
