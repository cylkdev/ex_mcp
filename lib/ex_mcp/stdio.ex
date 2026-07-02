defmodule ExMCP.Stdio do
  @moduledoc """
  Stdio transport for MCP. Reads newline-delimited JSON-RPC messages from an
  input device, dispatches each via `ExMCP.Server` (the pure core), and writes
  responses to an output device. This is the transport MCP hosts (e.g. Claude
  Code) use when launching a server as a local subprocess.

  Per the MCP stdio spec, stdout carries ONLY JSON-RPC messages: each message is
  a single line of JSON, and logging must not touch stdout. `run/1` redirects
  the default logger to stderr (`redirect_logs_to_stderr/0`) so the stream stays
  clean.

  Tools and server identity are passed explicitly in `opts` (defaults from
  `ExMCP.Config`), exactly as for `ExMCP.Server`. The registry is
  built once and injected, so a static tool set isn't rebuilt per request.

  ## Options

    * `:input`  — IO device read line-by-line (default `:stdio`).
    * `:output` — IO device responses are written to (default `:stdio`).
    * `:redirect_logs` — redirect the default logger to stderr (default `true`;
      set `false` in tests to leave the suite's logger config intact).
    * `:tools`, `:server_info`, ... — passed explicitly (see `ExMCP.Config` defaults).

  ## Concurrency

  Each request is handled in a task under a per-run `Task.Supervisor`, so a slow
  `tools/call` doesn't block subsequent reads. Responses may complete out of
  order; JSON-RPC ids let the client match them. Each response is written in a
  single `IO.binwrite/2` call, which the BEAM group leader treats as one atomic
  IO request — so concurrent responses never interleave byte-wise.

  `run/1` blocks until EOF on the input, awaits in-flight requests, then returns.
  """
  require Logger

  alias ExMCP.{Config, Protocol, Registry, Server}

  @doc """
  Run the stdio loop until EOF. Returns `:ok` on clean EOF, or
  `{:error, reason}` if reading the input device fails.
  """
  def run(opts \\ []) do
    if Keyword.get(opts, :redirect_logs, true), do: redirect_logs_to_stderr()

    input = Keyword.get(opts, :input, :stdio)
    output = Keyword.get(opts, :output, :stdio)

    opts =
      Keyword.put_new_lazy(opts, :registry, fn ->
        Registry.cached(Config.get(opts, :tools))
      end)

    {:ok, sup} = Task.Supervisor.start_link()

    try do
      {result, tasks} = loop(input, output, opts, sup, [])
      Task.await_many(tasks, :infinity)
      result
    after
      Supervisor.stop(sup)
    end
  end

  @doc """
  Point the default logger handler at stderr so stdout stays pure JSON-RPC.
  Idempotent; safe for host apps to call themselves.
  """
  def redirect_logs_to_stderr do
    _ = :logger.update_handler_config(:default, :config, %{type: :standard_error})
    :ok
  end

  # Tail-recursive read loop. Returns {result, spawned_tasks}.
  defp loop(input, output, opts, sup, tasks) do
    case IO.read(input, :line) do
      :eof ->
        {:ok, tasks}

      {:error, reason} ->
        Logger.error("MCP stdio read error: #{inspect(reason)}")
        {{:error, reason}, tasks}

      data when is_binary(data) ->
        case String.trim(data) do
          "" ->
            loop(input, output, opts, sup, tasks)

          line ->
            task = Task.Supervisor.async_nolink(sup, fn -> handle_line(line, output, opts) end)
            loop(input, output, opts, sup, [task | tasks])
        end
    end
  end

  defp handle_line(line, output, opts) do
    case Jason.decode(line) do
      {:error, _} ->
        write(output, Protocol.error(nil, Protocol.parse_error(), "Parse error"))

      {:ok, decoded} ->
        opts = Keyword.merge(opts, notifier: ExMCP.Notifier.Stdio, sink: output)

        case Server.handle(decoded, opts) do
          :noreply -> :ok
          response -> write(output, response)
        end
    end
  end

  # One binwrite per message: the group leader makes a single IO request atomic,
  # so concurrent responses can't interleave.
  defp write(output, payload), do: IO.binwrite(output, [Jason.encode!(payload), ?\n])
end
