defmodule ExMCP.Tool.ContextTest do
  use ExUnit.Case, async: true

  alias ExMCP.Tool.Context

  defmodule Capture do
    @behaviour ExMCP.Notifier
    @impl true
    def notify(pid, message), do: send(pid, {:notified, message}) && :ok
  end

  defmodule Boom do
    @behaviour ExMCP.Notifier
    @impl true
    def notify(_sink, _message), do: raise("nope")
  end

  test "progress/4 sends a notifications/progress with token, progress, total, message" do
    ctx = %Context{progress_token: "tok", notifier: Capture, sink: self()}
    assert :ok = Context.progress(ctx, 3, 7, message: "auditing")

    assert_receive {:notified, msg}
    assert msg["method"] == "notifications/progress"
    assert msg["params"] == %{"progressToken" => "tok", "progress" => 3, "total" => 7, "message" => "auditing"}
  end

  test "progress/4 omits message when not given" do
    ctx = %Context{progress_token: "tok", notifier: Capture, sink: self()}
    Context.progress(ctx, 1, 7)
    assert_receive {:notified, msg}
    refute Map.has_key?(msg["params"], "message")
  end

  test "progress/4 is a no-op when progress_token is nil" do
    ctx = %Context{progress_token: nil, notifier: Capture, sink: self()}
    assert :ok = Context.progress(ctx, 1, 7, message: "x")
    refute_receive {:notified, _}
  end

  test "progress/4 swallows a notifier error (best-effort)" do
    ctx = %Context{progress_token: "tok", notifier: Boom, sink: self()}
    assert :ok = Context.progress(ctx, 1, 7, message: "x")
  end

  test "default struct has a Null notifier and nil token" do
    ctx = %Context{}
    assert ctx.progress_token == nil
    assert ctx.notifier == ExMCP.Notifier.Null
  end
end
