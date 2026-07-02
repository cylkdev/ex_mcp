# Remove HTTP transport, keep stdio — Design

**Date:** 2026-07-02
**Status:** Approved

## Goal

Reduce ExMCP to a **stdio-only** MCP server. Delete the Plug/Router HTTP
transport and its now-dead configuration. Leave the pure core (`Server`,
`Protocol`, `Registry`), the `Tool` behaviour, and the transport seam
(`Notifier` / `Tool.Context` / `sink`) untouched, so HTTP can be re-added later
without rebuilding that seam.

## Decisions

1. **Surgical removal (not a deeper collapse).** Keep the transport-neutral
   internals — `Notifier` behaviour, `Notifier.Null`, `Notifier.Stdio`, and the
   `sink`/`notifier` fields on `Tool.Context`. Only the HTTP transport and its
   HTTP-only config leave.
2. **Remove dead config keys.** `:allowed_origins`, `:supported_versions`, and
   `:path` are read only by the HTTP transport; with it gone they are dead and
   are removed rather than left as unused defaults.

## Changes

### Deletions

- `lib/ex_mcp/plug.ex`
- `lib/ex_mcp/router.ex`
- `test/ex_mcp/plug_test.exs`
- `test/ex_mcp/router_test.exs`
- `{:plug, "~> 1.15"}` from `mix.exs` deps. Run
  `mix deps.unlock plug plug_crypto mime telemetry` to drop them from the lock
  (they are only pulled in transitively via `:plug`).

### Config — `lib/ex_mcp/config.ex`

- Remove `:allowed_origins`, `:supported_versions`, `:path` from `@defaults`.
  Remaining keys: `:server_info`, `:protocol_version`, `:tools`.
- Update the `get/2` `@doc` "recognised keys" list to the three survivors.
- Trim `test/ex_mcp/config_test.exs` to assert only the surviving defaults.

### Documentation

- `ExMCP` moduledoc (`lib/ex_mcp.ex`): drop the `## Transports` HTTP bullet and
  the "Both dispatch through the same pure core" dual-transport framing; describe
  `ExMCP.Stdio` as *the* transport over the pure `ExMCP.Server` core.
- `README.md`: delete the "HTTP transport" section and the `ExMCP.Router`
  mention. The stdio section and tool-definition sections stay.
- `mix.exs` `docs/0`: drop `ExMCP.Plug` and `ExMCP.Router` from the
  `groups_for_modules` `Transports` group. Rename the group to `Transport` with
  just `ExMCP.Stdio`.

### Code-comment scrub

- `lib/ex_mcp/server.ex` and `lib/ex_mcp/registry.ex` contain comments that name
  `ExMCP.Plug` (e.g. "a caller (e.g. `ExMCP.Plug`) may inject `:registry`").
  Reword to reference "a transport" / `ExMCP.Stdio` so no comment points at a
  deleted module.

### Untouched

`Server`, `Protocol`, `Registry`, `Tool`, `Tool.Context`, `Notifier`,
`Notifier.Null`, `Notifier.Stdio`, `Stdio`. The `sink`/`notifier` seam is
unchanged.

## Verification

- `mix compile --warnings-as-errors` — clean.
- `mix test` — green (the ~13 plug/router tests are removed along with their
  files; config tests trimmed).
- `mix docs` — builds with no warnings and no dangling references to
  `ExMCP.Plug` / `ExMCP.Router`.
- `grep -rn "Plug\|Router\|allowed_origins\|supported_versions\|:path" lib
  README.md mix.exs` — no reference to a deleted module or removed config key
  remains (incidental matches like the word "path" in unrelated prose are fine).

## Out of scope

- Collapsing the notifier/sink seam (explicitly deferred — decision 1).
- Any change to how tools are defined or invoked.
- Re-adding HTTP (future work; the seam is preserved to make it straightforward).
