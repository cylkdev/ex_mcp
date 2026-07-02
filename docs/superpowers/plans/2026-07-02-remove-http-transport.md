# Remove HTTP Transport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce ExMCP to a stdio-only MCP server by deleting the Plug/Router HTTP transport and its dead config.

**Architecture:** Surgical removal. Delete the HTTP transport modules, their tests, the `:plug` dep, and the three HTTP-only config keys. Leave the pure core (`Server`/`Protocol`/`Registry`), the `Tool` behaviour, and the transport seam (`Notifier`/`Tool.Context`/`sink`) untouched.

**Tech Stack:** Elixir ~> 1.15, Mix, ExUnit, ExDoc.

## Global Constraints

- Do not change runtime behavior of the surviving stdio path, the pure core, or the notifier/sink seam.
- This is not a git repository — the "commit" step of TDD is replaced by a verification checkpoint (`mix compile --warnings-as-errors && mix test`).
- After every task, `mix compile --warnings-as-errors` must be clean.

---

### Task 1: Delete HTTP transport modules and their tests

**Files:**
- Delete: `lib/ex_mcp/plug.ex`
- Delete: `lib/ex_mcp/router.ex`
- Delete: `test/ex_mcp/plug_test.exs`
- Delete: `test/ex_mcp/router_test.exs`

**Interfaces:**
- Consumes: nothing.
- Produces: removal of modules `ExMCP.Plug`, `ExMCP.Router` from the codebase.

- [ ] **Step 1: Delete the four files**

```bash
rm lib/ex_mcp/plug.ex lib/ex_mcp/router.ex \
   test/ex_mcp/plug_test.exs test/ex_mcp/router_test.exs
```

- [ ] **Step 2: Remove the `:plug` dependency from `mix.exs`**

In `defp deps`, delete the line `{:plug, "~> 1.15"},` so only `:jason` and `:ex_doc` remain.

- [ ] **Step 3: Unlock the now-unused deps**

Run: `mix deps.unlock plug plug_crypto mime telemetry`
Expected: those four entries removed from `mix.lock`.

- [ ] **Step 4: Verify compile fails only on stale references (checkpoint)**

Run: `mix compile --warnings-as-errors`
Expected: PASS. (`Server`/`Registry` reference `ExMCP.Plug` only inside comments, so compilation succeeds. If it fails, a real code reference exists — fix in Task 3.)

---

### Task 2: Remove dead config keys

**Files:**
- Modify: `lib/ex_mcp/config.ex`
- Test: `test/ex_mcp/config_test.exs`

**Interfaces:**
- Consumes: nothing.
- Produces: `ExMCP.Config.get/2` recognises exactly `:server_info`, `:protocol_version`, `:tools`; any other key raises `KeyError`.

- [ ] **Step 1: Update the failing test first**

In `test/ex_mcp/config_test.exs`, replace the "falls back to built-in default" test body so it no longer asserts the removed keys:

```elixir
  test "falls back to built-in default" do
    assert Config.get([], :protocol_version) == "2025-06-18"
    assert Config.get([], :tools) == []
    assert Config.get([], :server_info) == %{"name" => "ex_mcp", "version" => "0.1.0"}
  end

  test "unknown key raises" do
    assert_raise KeyError, fn -> Config.get([], :allowed_origins) end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ex_mcp/config_test.exs`
Expected: FAIL — `:allowed_origins` still resolves to a default, so `assert_raise KeyError` fails.

- [ ] **Step 3: Remove the dead keys from `@defaults`**

In `lib/ex_mcp/config.ex`, reduce `@defaults` to:

```elixir
  @defaults %{
    server_info: %{"name" => "ex_mcp", "version" => "0.1.0"},
    protocol_version: "2025-06-18",
    tools: []
  }
```

- [ ] **Step 4: Update the `get/2` doc**

Change the "Recognised keys are ..." sentence in the `@doc` to:

```
  Recognised keys are `:server_info`, `:protocol_version`, and `:tools`. Raises
  `KeyError` for an unknown key.
```

- [ ] **Step 5: Run tests (checkpoint)**

Run: `mix test test/ex_mcp/config_test.exs`
Expected: PASS.

---

### Task 3: Scrub docs and comments referencing the removed modules

**Files:**
- Modify: `lib/ex_mcp.ex`
- Modify: `lib/ex_mcp/server.ex`
- Modify: `lib/ex_mcp/registry.ex`
- Modify: `mix.exs`
- Modify: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: no remaining reference to `ExMCP.Plug` / `ExMCP.Router` in source, docs, or config.

- [ ] **Step 1: Update `ExMCP` moduledoc (`lib/ex_mcp.ex`)**

Replace the `## Transports` section listing both transports with a single-transport framing: describe `ExMCP.Stdio` as the transport over the pure `ExMCP.Server` core, and drop the `ExMCP.Plug` bullet and the "Both dispatch through the same pure core" sentence. Keep the "Running a stdio server" and "Rules" sections.

- [ ] **Step 2: Reword the `ExMCP.Plug` code comments**

In `lib/ex_mcp/server.ex`, the comment above `registry/1` reads "A caller (e.g. `ExMCP.Plug`) may inject an already-built `:registry`...". Change `ExMCP.Plug` → `ExMCP.Stdio`.

In `lib/ex_mcp/registry.ex`, the `cached/1` doc says "do not call it at compile time (see `ExMCP.Plug`)". Change to "(see `ExMCP.Stdio`)".

- [ ] **Step 3: Update `mix.exs` docs group**

In `docs/0`, replace the `Transports: [ExMCP.Plug, ExMCP.Router, ExMCP.Stdio]` line with `Transport: [ExMCP.Stdio]`.

- [ ] **Step 4: Update `README.md`**

Delete the "## HTTP transport" section (the `plug ExMCP.Plug, ...` block and the `ExMCP.Router` sentence). Leave the stdio and tool-definition sections intact.

- [ ] **Step 5: Grep for leftovers**

Run: `grep -rn "Plug\|Router\|allowed_origins\|supported_versions" lib README.md mix.exs`
Expected: no line referencing a deleted module or removed key (incidental prose matches are acceptable, but there should be none here).

- [ ] **Step 6: Full verification (checkpoint)**

Run: `mix compile --warnings-as-errors && mix test && mix docs`
Expected: compile clean; all tests pass; `mix docs` builds with no warnings and no dangling `ExMCP.Plug`/`ExMCP.Router` references.

---

## Self-Review

- **Spec coverage:** Deletions (Task 1), config keys + config_test (Task 2), moduledoc/README/mix.exs docs/comment scrub (Task 3), verification (each task checkpoint + Task 3 Step 6). All spec sections covered.
- **Placeholder scan:** none.
- **Type consistency:** `Config.get/2` key set (`:server_info`, `:protocol_version`, `:tools`) consistent across Task 2 steps and interfaces.
