defmodule ExMCP.Registry do
  @moduledoc """
  Flattens a list of `ExMCP.Tool` behaviour modules into a
  `name => %{spec: spec, handler: handler}` map.
  """

  @doc """
  Build a `name => %{spec: spec, handler: handler}` registry from tool modules.

  Each module is loaded and inspected for its `spec/0`. Raises `ArgumentError`
  if a module has no `spec/0`, or if two tools resolve to the same name.
  """
  def build(modules) when is_list(modules) do
    Enum.reduce(modules, %{}, fn module, acc ->
      module
      |> entries()
      |> Enum.reduce(acc, fn {name, spec, handler}, inner ->
        if Map.has_key?(inner, name) do
          raise ArgumentError, "duplicate MCP tool name: #{inspect(name)}"
        end

        Map.put(inner, name, %{spec: spec, handler: handler})
      end)
    end)
  end

  @doc """
  Like `build/1`, but memoizes the result in `:persistent_term` keyed by the
  module list. A static tool set is built (loading each module and calling
  `spec/0`) once, then reused on every later call — letting a
  request handler avoid rebuilding the registry per request. Call it lazily on
  the first request; do not call it at compile time (see `ExMCP.Stdio`), where
  tool modules may not be loaded yet.
  """
  def cached(modules) when is_list(modules) do
    key = {__MODULE__, modules}

    case :persistent_term.get(key, :__miss__) do
      :__miss__ ->
        registry = build(modules)
        :persistent_term.put(key, registry)
        registry

      registry ->
        registry
    end
  end

  @doc """
  Return the list of tool spec maps in a registry, for a `tools/list` reply.
  """
  def specs(registry), do: registry |> Map.values() |> Enum.map(& &1.spec)

  @doc """
  Invoke the tool registered under `name` with the given `arguments` map.

  `context` is passed to tools that export `call/2`; a behaviour tool exporting
  only `call/1` is called without it. Returns `{:ok, result}` with the tool's
  MCP result map, or `:unknown` if no tool is registered under `name`.
  """
  def invoke(registry, name, arguments, context \\ %ExMCP.Tool.Context{}) do
    case Map.fetch(registry, name) do
      {:ok, %{handler: {:behaviour, module}}} -> {:ok, call_behaviour(module, arguments, context)}
      :error -> :unknown
    end
  end

  defp call_behaviour(module, arguments, context) do
    if function_exported?(module, :call, 2) do
      module.call(arguments, context)
    else
      module.call(arguments)
    end
  end

  defp entries(module) do
    Code.ensure_loaded!(module)

    if function_exported?(module, :spec, 0) do
      spec = module.spec()
      [{spec["name"], spec, {:behaviour, module}}]
    else
      raise ArgumentError, "#{inspect(module)} is not an MCP tool (missing spec/0)"
    end
  end
end
