defmodule ExMCP.Tool do
  @moduledoc """
  Behaviour for an MCP tool. `spec/0` returns the tool descriptor
  (`%{"name" => ..., "description" => ..., "inputSchema" => ...}`); `call/1`
  receives the decoded `arguments` map and returns an MCP result map.
  Alternatively, a tool may implement `call/2`, which additionally receives
  an `ExMCP.Tool.Context` (carrying the request's `progressToken` and a
  notifier) so it can emit `notifications/progress`.
  """

  @doc """
  Return the tool descriptor:
  `%{"name" => ..., "description" => ..., "inputSchema" => ...}`.
  """
  @callback spec() :: map()

  @doc """
  Handle a call, given the decoded `arguments` map. Return an MCP result map.
  """
  @callback call(arguments :: map()) :: map()

  @doc """
  Like `c:call/1`, but also receives the `ExMCP.Tool.Context` so the tool can
  emit progress notifications. Implement this instead of `c:call/1` when the tool
  needs the context.
  """
  @callback call(arguments :: map(), context :: ExMCP.Tool.Context.t()) :: map()

  @optional_callbacks call: 1, call: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour ExMCP.Tool
    end
  end
end
