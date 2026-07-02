defmodule ExMCP.NotifierTest do
  use ExUnit.Case, async: true

  test "Stdio writes exactly one JSON line to the sink device" do
    {:ok, io} = StringIO.open("")
    assert :ok = ExMCP.Notifier.Stdio.notify(io, %{"method" => "notifications/progress"})
    {_in, out} = StringIO.contents(io)
    assert out == ~s({"method":"notifications/progress"}\n)
  end

  test "Null ignores the message" do
    assert :ok = ExMCP.Notifier.Null.notify(:anything, %{"x" => 1})
  end
end
