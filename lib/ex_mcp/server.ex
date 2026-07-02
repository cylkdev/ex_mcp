defmodule ExMCP.Server do
  @moduledoc """
  MCP method dispatch over decoded JSON-RPC messages. Pure: no HTTP. Tools and
  server identity come from `opts` (resolved via `ExMCP.Config`).
  """
  require Logger

  alias ExMCP.{Config, Protocol, Registry}

  @doc """
  Dispatch one decoded JSON-RPC message and return its reply.

  `decoded` is an already-parsed JSON value (map, or list for a rejected batch).
  `opts` supply tools and server identity (see `ExMCP.Config`); a caller may
  inject a prebuilt `:registry` to skip rebuilding it per request, and a
  `:notifier`/`:sink` pair to let tools emit progress notifications.

  Returns a JSON-RPC response map for a request, or `:noreply` for a
  notification (which has no reply). Invalid messages become a JSON-RPC error
  map; an exception raised inside a tool is logged and reported as a generic
  `-32603` internal error rather than propagating.
  """
  @spec handle(map() | list(), keyword()) :: map() | :noreply
  def handle(decoded, opts \\ []) do
    case Protocol.classify(decoded) do
      {:notification, _method, _params} ->
        :noreply

      {:invalid, id, message} ->
        Protocol.error(id, Protocol.invalid_request(), message)

      {:request, id, method, params} ->
        try do
          dispatch(method, params, opts) |> envelope(id)
        rescue
          e ->
            Logger.error("MCP internal error for id=#{inspect(id)}: " <>
                           Exception.format(:error, e, __STACKTRACE__))

            Protocol.error(id, Protocol.internal_error(), "Internal error")
        end
    end
  end

  defp dispatch("initialize", _params, opts) do
    {:ok,
     %{
       "protocolVersion" => Config.get(opts, :protocol_version),
       "capabilities" => %{"tools" => %{}},
       "serverInfo" => Config.get(opts, :server_info)
     }}
  end

  defp dispatch("tools/list", _params, opts) do
    {:ok, %{"tools" => opts |> registry() |> Registry.specs()}}
  end

  defp dispatch("tools/call", %{"name" => name} = params, opts) do
    context = %ExMCP.Tool.Context{
      progress_token: get_in(params, ["_meta", "progressToken"]),
      notifier: Keyword.get(opts, :notifier, ExMCP.Notifier.Null),
      sink: Keyword.get(opts, :sink)
    }

    case Registry.invoke(registry(opts), name, Map.get(params, "arguments", %{}), context) do
      {:ok, result} -> {:ok, result}
      :unknown -> {:error, Protocol.invalid_params(), "unknown tool: #{name}"}
    end
  end

  defp dispatch("tools/call", _params, _opts),
    do: {:error, Protocol.invalid_params(), "missing tool name"}

  defp dispatch(_method, _params, _opts),
    do: {:error, Protocol.method_not_found(), "method not found"}

  # A caller (e.g. ExMCP.Stdio) may inject an already-built `:registry` to avoid
  # rebuilding per request; otherwise build fresh from the configured tools.
  defp registry(opts) do
    case Keyword.fetch(opts, :registry) do
      {:ok, registry} -> registry
      :error -> opts |> Config.get(:tools) |> Registry.build()
    end
  end

  defp envelope({:ok, result}, id), do: Protocol.result(id, result)
  defp envelope({:error, code, message}, id), do: Protocol.error(id, code, message)
end
