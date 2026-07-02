defmodule ExMCP.Protocol do
  @moduledoc """
  Pure JSON-RPC 2.0 primitives: reserved error codes, message classification,
  and envelope builders. Knows nothing about MCP methods or HTTP.
  """

  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603

  @doc "The `-32700` JSON-RPC reserved code for malformed JSON."
  def parse_error, do: @parse_error
  @doc "The `-32600` JSON-RPC reserved code for an invalid request object."
  def invalid_request, do: @invalid_request
  @doc "The `-32601` JSON-RPC reserved code for an unknown method."
  def method_not_found, do: @method_not_found
  @doc "The `-32602` JSON-RPC reserved code for invalid method parameters."
  def invalid_params, do: @invalid_params
  @doc "The `-32603` JSON-RPC reserved code for an internal server error."
  def internal_error, do: @internal_error

  @doc """
  Classify a decoded JSON-RPC message.

  Returns one of:

    * `{:request, id, method, params}` — a well-formed request with a non-null id;
    * `{:notification, method, params}` — a message with no `"id"` key;
    * `{:invalid, id, message}` — anything else (missing/blank `"jsonrpc"`,
      non-string method, null id, or a batch array, which is not supported).
  """
  def classify(decoded)

  def classify(list) when is_list(list),
    do: {:invalid, nil, "JSON-RPC batching is not supported"}

  def classify(%{"jsonrpc" => "2.0", "method" => method} = msg) when is_binary(method) do
    params = Map.get(msg, "params", %{})

    cond do
      not Map.has_key?(msg, "id") -> {:notification, method, params}
      is_nil(Map.get(msg, "id")) -> {:invalid, nil, "Invalid Request: id must not be null"}
      true -> {:request, Map.get(msg, "id"), method, params}
    end
  end

  def classify(%{"id" => id}), do: {:invalid, id, "Invalid Request"}
  def classify(_), do: {:invalid, nil, "Invalid Request"}

  @doc "Build a JSON-RPC success response wrapping `result` under the given `id`."
  def result(id, result), do: %{"jsonrpc" => "2.0", "id" => id, "result" => result}

  @doc "Build a JSON-RPC notification (a message with a `method` and no `id`)."
  def notification(method, params),
    do: %{"jsonrpc" => "2.0", "method" => method, "params" => params}

  @doc "Build a JSON-RPC error response with the given `id`, `code`, and `message`."
  def error(id, code, message),
    do: %{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}}
end
