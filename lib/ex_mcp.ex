defmodule ExMCP do
  @moduledoc """
  Reusable MCP (Model Context Protocol) server over JSON-RPC 2.0.

  ## Transport

  `ExMCP.Stdio` is the transport: stdio (newline-delimited JSON-RPC), used by MCP
  hosts that launch a server as a local subprocess. It dispatches through the
  pure core, `ExMCP.Server`. Tools and server identity are passed **explicitly**
  as options — there is no global application env. A host app injects them when
  it runs the transport.

  ## Running a stdio server

  The host app starts its application, then runs the loop with its tools and
  identity passed in. A tiny `mix` task is the usual entry point:

      defmodule Mix.Tasks.MyApp.Stdio do
        use Mix.Task

        def run(_args) do
          Mix.Task.run("app.start")

          ExMCP.Stdio.run(
            tools: [MyApp.Tools.Foo, MyApp.Tools.Bar],
            server_info: %{"name" => "my_app", "version" => "0.1.0"}
          )
        end
      end

  ### Rules

    * The host app's `Application` MUST NOT start its own stdio reader, or stdin
      would be read twice.
    * stdout carries ONLY JSON-RPC. `ExMCP.Stdio.run/1` redirects the default
      logger to stderr automatically.
  """
end
