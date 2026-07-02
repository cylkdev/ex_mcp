defmodule ExMCP.StdioTest do
  use ExUnit.Case, async: true

  @opts [
    server_info: %{"name" => "test", "version" => "9.9"},
    protocol_version: "2025-06-18",
    tools: [ExMCP.TestTools.Echo],
    # Leave the suite's logger config alone.
    redirect_logs: false
  ]

  # Feed `lines` (a list of JSON-RPC request maps or raw strings) through the
  # stdio loop and return the decoded responses, keyed by their JSON-RPC id.
  # Responses with no id (parse errors → nil) are collected under `nil`.
  defp run(lines) do
    payload =
      lines
      |> Enum.map(fn
        line when is_binary(line) -> line
        map -> Jason.encode!(map)
      end)
      |> Enum.map(&(&1 <> "\n"))
      |> IO.iodata_to_binary()

    {:ok, input} = StringIO.open(payload)
    {:ok, output} = StringIO.open("")

    assert :ok = ExMCP.Stdio.run(Keyword.merge(@opts, input: input, output: output))

    {_in, captured} = StringIO.contents(output)

    captured
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
    |> Map.new(fn resp -> {resp["id"], resp} end)
  end

  defp req(method, params, id) do
    %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
  end

  test "responds to a single request" do
    responses = run([req("initialize", %{}, 1)])
    assert responses[1]["result"]["protocolVersion"] == "2025-06-18"
  end

  test "handles multiple concurrent requests, matched by id" do
    responses =
      run([
        req("tools/list", %{}, 1),
        req("tools/call", %{"name" => "echo", "arguments" => %{"text" => "a"}}, 2),
        req("tools/call", %{"name" => "echo", "arguments" => %{"text" => "b"}}, 3)
      ])

    assert [%{"name" => "echo"}] = responses[1]["result"]["tools"]
    assert responses[2]["result"]["content"] == [%{"type" => "text", "text" => "a"}]
    assert responses[3]["result"]["content"] == [%{"type" => "text", "text" => "b"}]
  end

  test "notifications produce no output line" do
    responses = run([%{"jsonrpc" => "2.0", "method" => "initialized"}, req("tools/list", %{}, 7)])
    # Only the request gets a response.
    assert map_size(responses) == 1
    assert responses[7]["result"]["tools"]
  end

  test "malformed JSON line yields a -32700 parse error with null id" do
    responses = run(["this is not json"])
    assert responses[nil]["error"]["code"] == -32700
  end

  test "blank lines are skipped" do
    responses = run(["", "   ", req("tools/list", %{}, 1)])
    assert map_size(responses) == 1
    assert responses[1]["result"]["tools"]
  end

  test "EOF on empty input exits cleanly with no output" do
    responses = run([])
    assert responses == %{}
  end

  test "an error response does not stop the loop; later requests still answered" do
    responses =
      run([
        req("tools/call", %{"name" => "nope"}, 1),
        req("tools/list", %{}, 2)
      ])

    assert responses[1]["error"]["code"] == -32602
    assert responses[2]["result"]["tools"]
  end

  defmodule ProgressTool do
    use ExMCP.Tool
    @impl true
    def spec, do: %{"name" => "prog", "description" => "d", "inputSchema" => %{"type" => "object", "properties" => %{}}}
    @impl true
    def call(_args, context) do
      ExMCP.Tool.Context.progress(context, 1, 2, message: "one")
      ExMCP.Tool.Context.progress(context, 2, 2, message: "two")
      %{"content" => [%{"type" => "text", "text" => "done"}]}
    end
  end

  test "a tool's progress notifications are written to stdout before the result" do
    line =
      Jason.encode!(%{
        "jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
        "params" => %{"name" => "prog", "arguments" => %{}, "_meta" => %{"progressToken" => "abc"}}
      }) <> "\n"

    {:ok, input} = StringIO.open(line)
    {:ok, output} = StringIO.open("")

    assert :ok =
             ExMCP.Stdio.run(
               server_info: %{"name" => "t", "version" => "9"},
               tools: [ProgressTool],
               redirect_logs: false,
               input: input,
               output: output
             )

    {_in, captured} = StringIO.contents(output)
    msgs = captured |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)

    progress_notes = Enum.filter(msgs, &(&1["method"] == "notifications/progress"))
    assert length(progress_notes) == 2
    assert Enum.map(progress_notes, & &1["params"]["progress"]) == [1, 2]
    assert List.last(progress_notes)["params"]["progressToken"] == "abc"

    # the result line exists and comes after the notifications
    result_index = Enum.find_index(msgs, &Map.has_key?(&1, "id"))
    assert result_index == 2
    assert Enum.at(msgs, result_index)["result"]["content"] == [%{"type" => "text", "text" => "done"}]
  end
end
