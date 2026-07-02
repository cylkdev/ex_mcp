defmodule ExMCP.Tool.Context do
  @moduledoc """
  Per-call context handed to a tool's `call/2`. Carries the request's
  `progressToken` and the transport's notifier module + sink, so a tool can emit
  `notifications/progress` without knowing the transport. When `progress_token`
  is nil (client asked for no progress), `progress/4` is a no-op.
  """

  alias ExMCP.Protocol

  @enforce_keys []
  defstruct progress_token: nil, notifier: ExMCP.Notifier.Null, sink: nil

  @typedoc """
  A per-call context. `progress_token` is the client-supplied token (or `nil` if
  the client asked for no progress), `notifier` the transport's `ExMCP.Notifier`
  module, and `sink` the transport-specific target that notifier writes to.
  """
  @type t :: %__MODULE__{progress_token: term() | nil, notifier: module(), sink: term()}

  @doc """
  Emit a `notifications/progress` update for the in-flight call.

  `progress` is the amount done so far and `total` the expected total. Supported
  `opts`: `:message`, a human-readable status string added to the notification.

  A no-op (returning `:ok`) when the call carried no `progressToken`. The
  notification is best-effort: any error from the notifier is swallowed so
  reporting progress can never crash the tool.
  """
  @spec progress(t(), number(), number(), keyword()) :: :ok
  def progress(ctx, progress, total, opts \\ [])

  def progress(%__MODULE__{progress_token: nil}, _progress, _total, _opts), do: :ok

  def progress(%__MODULE__{} = ctx, progress, total, opts) do
    params =
      %{"progressToken" => ctx.progress_token, "progress" => progress, "total" => total}
      |> put_message(opts[:message])

    payload = Protocol.notification("notifications/progress", params)

    try do
      ctx.notifier.notify(ctx.sink, payload)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end

    :ok
  end

  defp put_message(params, nil), do: params
  defp put_message(params, message), do: Map.put(params, "message", message)
end
