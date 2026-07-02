# ExMCP

A reusable [MCP (Model Context Protocol)](https://modelcontextprotocol.io)
server for Elixir, speaking JSON-RPC 2.0 over a stdio transport
(`ExMCP.Stdio`) — newline-delimited JSON-RPC, used by MCP hosts that launch a
server as a local subprocess.

It dispatches through the pure core, `ExMCP.Server`. Tools and server identity
are passed **explicitly** as options — there is no global application env, so a
host app injects them where it runs the transport.

## Installation

Add `:ex_mcp` to your deps:

```elixir
def deps do
  [
    {:ex_mcp, "~> 0.1"}
  ]
end
```

## Defining a tool

A tool is a module implementing the `ExMCP.Tool` behaviour:

```elixir
defmodule MyApp.Tools.Echo do
  use ExMCP.Tool

  @impl true
  def spec do
    %{
      "name" => "echo",
      "description" => "Echoes the given text.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{"text" => %{"type" => "string"}}
      }
    }
  end

  @impl true
  def call(%{"text" => text}), do: %{"content" => [%{"type" => "text", "text" => text}]}
end
```

## stdio transport

Run the loop from a `mix` task after starting your application:

```elixir
defmodule Mix.Tasks.MyApp.Stdio do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    ExMCP.Stdio.run(
      tools: [MyApp.Tools.Echo],
      server_info: %{"name" => "my_app", "version" => "0.1.0"}
    )
  end
end
```

stdout carries ONLY JSON-RPC; `ExMCP.Stdio.run/1` redirects the default logger
to stderr so the stream stays clean.

## Documentation

See the module docs (`ExMCP`, `ExMCP.Server`, `ExMCP.Tool`) for the full API.
Generate them with `mix docs`.
