defmodule ExMCP.Notifier do
  @moduledoc """
  Behaviour for delivering an out-of-band JSON-RPC message (e.g.
  `notifications/progress`) to a transport's output. The `sink` is whatever the
  transport needs to address its output — for stdio, the output IO device.
  """

  @doc """
  Deliver `message` (a JSON-RPC map) to `sink`, the transport's output target.
  Return `:ok`.
  """
  @callback notify(sink :: term(), message :: map()) :: :ok
end
