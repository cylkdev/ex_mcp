defmodule ExMCP.Config do
  @moduledoc "Resolves ex_mcp settings: explicit opts → built-in default. No global app env."

  @defaults %{
    server_info: %{"name" => "ex_mcp", "version" => "0.1.0"},
    protocol_version: "2025-06-18",
    tools: []
  }

  @doc """
  Resolve a setting: return the value from `opts` if present, else the built-in
  default.

  Recognised keys are `:server_info`, `:protocol_version`, and `:tools`. Raises
  `KeyError` for an unknown key.
  """
  def get(opts, key) when is_list(opts) do
    Keyword.get(opts, key, Map.fetch!(@defaults, key))
  end
end
