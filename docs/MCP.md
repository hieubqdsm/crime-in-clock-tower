# Godot MCP — setup (optional, recommended)

> The harness **works without MCP** (the agent uses the `godot` CLI — `AGENTS.md` §6).
> With a Godot MCP server installed, the agent can create scenes/nodes, validate
> scripts and **read debug output directly** — a much tighter feedback loop.
> **HARD RULE (`AGENTS.md` §0.2):** window-opening tools (`run_project`,
> `launch_editor`) are never called by the agent on its own — only when the user
> explicitly asks.

## Server

**`@tugcantopaloglu/godot-mcp`** (<https://github.com/tugcantopaloglu/godot-mcp>, MIT)
— a fork extending [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)
from ~20 to **157 tools** (runtime game control, script validation, resource
creation, export/CI...). It is a **superset** of the original toolset this harness
used to document — every tool referenced by older harness versions still exists.

Requirements: Godot **4.4+** (tested with 4.7), Node.js ≥ 18.
**"4.4+" is a minimum, not a pin** — always use the machine's Godot recorded as
`godot_exe` in `docs/LOCAL.md` (here: 4.7.1). The MCP server itself also resolves
exactly one executable via `GODOT_PATH` — the agent cannot and should not pick or
install another version (AGENTS.md §1b, §0.3).

### Install & configure

Build locally (what this machine uses):

```sh
git clone https://github.com/tugcantopaloglu/godot-mcp.git
cd godot-mcp && npm install && npm run build
```

MCP config (ZCode / Claude Desktop / Cline / Cursor JSON — scope **user** for every
project, or **workspace** for one project):

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["/absolute/path/to/godot-mcp/build/index.js"],
      "env": {
        "GODOT_PATH": "/path/to/godot",
        "DEBUG": "true"
      }
    }
  }
}
```

### Environment variables

| Var | Meaning |
|---|---|
| `GODOT_PATH` | Godot executable path (overrides auto-detection) |
| `DEBUG` | `"true"` for server-side debug logging |
| `GODOT_MCP_ALLOWED_DIRS` | Optional. Restricts `run_project` to projects under these roots (`;`, `,` or `:` separated). Unset = any project path allowed. |

## Architecture (2 channels)

1. **Headless CLI** — operations that need no running game (scene read/modify,
   script validation, resource creation). The server runs Godot with
   `--headless --script godot_operations.gd <operation> <json_params>`.
2. **TCP socket** — runtime interaction with a RUNNING game: the
   `mcp_interaction_server.gd` autoload listens on `127.0.0.1:9090` and processes
   JSON commands sent by the MCP server.

## Runtime tools setup (`game_*`)

To use the `game_*` runtime tools, the game project needs the interaction server
autoload:

1. Copy `build/scripts/mcp_interaction_server.gd` from the MCP repo into the project.
2. Godot: **Project > Project Settings > Autoload** → add the script named
   `McpInteractionServer`.

## Tool groups (what the agent uses)

**Headless project/scene operations** — no running game needed, safe under §0.2:
`get_godot_version`, `get_project_info`, `list_projects`, `create_project`,
`read_scene` / `modify_scene_node` / `remove_scene_node`, `create_scene` / `add_node`
/ `save_scene`, `attach_script`, `create_script`, `create_resource` (.tres files —
pairs with `docs/CODING.md` §4), `manage_autoloads`, `manage_input_map`,
`read_project_settings` / `modify_project_settings`, `read_file` / `write_file`,
`list_project_files`, `get_uid` / `update_project_uids`, `export_project` (headless
export), `manage_export_presets`, `validate_script` / `validate_scripts`,
`get_debug_output`.

**Runtime tools** (`game_*`) — need the game RUNNING + the autoload above:
`game_eval` (execute GDScript in the live game, with return values), `game_get_property`
/ `game_set_property`, `game_call_method`, `game_get_logs` / `game_get_errors`,
`game_key_press` / `game_key_hold` / `game_mouse_drag`, `game_wait`, `game_screenshot`,
`game_pause`, `game_performance`, and ~100 more (full list in the server README).

**Window openers — HARD RULE §0.2, never call on your own:**
`launch_editor` (opens the editor window), `run_project` (runs the game with a
window). Only on an explicit user request in the session.

## Runtime tools × headless policy

`game_*` tools connect to an already-running game, so the window question is about
how the game was **started**:

- Game started **by the user** (they ran it, or asked you to run it) → `game_*` tools
  are fine.
- Game started **by the agent** → must be `godot --headless --path . ...` (§0.2). The
  autoload + TCP server still run headless, so logic-oriented tools (`game_eval`,
  `game_get_errors`, `game_key_press`, `game_wait`...) should work — **assumption not
  yet verified: test with the first real game repo, then update this note**.
  Render-dependent tools (`game_screenshot`, viewport operations) will not work
  headless.

## Relationship with the harness workflow

- MCP is only **how the agent drives Godot**. **State still lives in markdown**
  (SESSION / features) — unchanged.
- Auto-tests in `AGENTS.md` §6 still run via the `godot --headless` CLI (GUT
  headless). MCP does not replace that. `validate_script` / `validate_scripts` are a
  cheap pre-check (syntax/type errors, autoload-aware) before the smoke test.

## Link

- Repo: <https://github.com/tugcantopaloglu/godot-mcp>
- Original (foundation): <https://github.com/Coding-Solo/godot-mcp>
