defmodule ExMCP.Notifier.Null do
  @moduledoc "No-op notifier: for transports without an out-of-band channel, or when no progressToken was requested."

  @behaviour ExMCP.Notifier

  @impl true
  def notify(_sink, _message), do: :ok
end
