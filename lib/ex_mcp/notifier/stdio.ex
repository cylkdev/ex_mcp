defmodule ExMCP.Notifier.Stdio do
  @moduledoc """
  Writes a JSON-RPC message as one line to its IO-device sink, via the same
  atomic `IO.binwrite/2` the stdio response writer uses — so notifications never
  interleave byte-wise with responses.
  """

  @behaviour ExMCP.Notifier

  @impl true
  def notify(device, message) do
    IO.binwrite(device, [Jason.encode!(message), ?\n])
    :ok
  end
end
