# godot-agent-harness

> A harness (process framework) for developing **Godot 4** games with an
> **AI agent + dev + human tester**. All state lives in committed Markdown
> → any agent / dev / tester can resume, independent of any AI session.

> **AI agent — read first:** [`AGENTS.md`](AGENTS.md) (session entry/exit protocol, frontmatter schemas, discipline).

Built by borrowing patterns from production-grade agent harnesses:
**model-visible ⟺ logged** (state always in files, never in conversation),
**structured handoff**, and **durable / in-flight / policy separation**.

---

## For a new Godot project

**Option 1 — GitHub "Use this template"** (enable *Template repository* in this
repo's Settings): click the button → name the new game repo → clone it locally.

**Option 2 — manual clone:**
```sh
git clone --depth 1 https://github.com/hieubqdsm/godot-agent-harness.git my-game
cd my-game
rm -rf .git
git init
```
_(change the URL to your own repo)_

**Name the project** (run once; `init.sh` replaces the name + date in every doc file):
```sh
bash scripts/init.sh "Your Game Name"
```

**Start developing:**
1. `git add -A && git commit -m "init project"`
2. Create `project.godot` (**user** step): open Godot → New Project at this directory
   (or `godot --path . -e`). If you are an agent: write the `project.godot` file
   directly as text, **do not open the editor** (`AGENTS.md` §0.2).
3. Read `docs/SESSION.md` → follow `next_action`.

> After running `init.sh` you may delete it if you want (it's only used once).

### Updating the harness for a game repo generated from this template

The template has a new patch (e.g. hard rules) and your game repo wants it? Don't
hand-copy files one by one — use git:

```sh
cd my-game
git remote add template https://github.com/hieubqdsm/godot-agent-harness.git   # once
git fetch template

# Pull only the HARNESS files (game repos don't customize them):
git checkout template/main -- \
  AGENTS.md README.md LICENSE docs/CODING.md docs/MCP.md docs/SETUP.md docs/WORKFLOW.md \
  scripts/status.sh scripts/init.sh

git commit -m "sync harness from template"
```

- The harness files above are taken **verbatim** from the latest template — even if
  the game repo was generated from a much older template.
- Do **NOT** checkout `docs/SESSION.md`, `docs/ROADMAP.md`, `docs/features/`,
  `docs/PLAYTEST_QUEUE.md`, `docs/LOCAL.md` — those are the game's own state.
- To keep history clean (repo generated from a recent template): `git cherry-pick`
  the template commits (e.g. `cf60610 a5e2e21`) instead of checkout; resolve
  conflicts manually.

## What you get

| File | Role |
|---|---|
| `docs/WORKFLOW.md` | Full process: roles, state machine, session start/end protocols, state discipline |
| `docs/CODING.md` | Code-writing policy: scene-first, headless-testable, moderate composition, disciplined Resource/autoload use |
| `docs/ROADMAP.md` | Overall plan: milestones + feature table |
| `docs/SESSION.md` | **Resume entry point** — current work + next step (structured handoff) |
| `docs/SETUP.md` | Standard ask-the-user machine setup + `docs/LOCAL.md` format (gitignored) |
| `docs/PLAYTEST_QUEUE.md` | Tester's daily worklist |
| `docs/features/F-xxx.md` | 1 feature / file. Frontmatter = source of truth |
| `docs/features/_TEMPLATE.md` | Template for new features (copy → `F-00X.md`) |
| `scripts/status.sh` | Live status table from every feature's frontmatter |
| `scripts/init.sh` | Name the project (run once) |
| `.gitignore` | Godot 4 ignores |

## Workflow summary

Every feature goes through:
```
planned → in_dev → dev_done → playtesting → pass → shipped
                                              ↘ fail → in_dev
```
Two **independent** test channels: `auto_test` (agent runs it headless, e.g. GUT) and
`playtest` (human tester). A feature merges into `main` only when
`auto_test != fail` **AND** `playtest.result == pass`.

At the start of any session, read in order:
`docs/SESSION.md` → `docs/ROADMAP.md` → `bash scripts/status.sh`.

Details: `docs/WORKFLOW.md`.

## State discipline (3 kinds, never mixed)

| Kind | Where it goes |
|---|---|
| **Durable** (facts that survive reload: status, test results) | frontmatter `docs/features/F-xxx.md` |
| **In-flight** (what's being done, what's next) | frontmatter `docs/SESSION.md` |
| **Policy** (fixed rules: merge conditions, code policy) | `docs/WORKFLOW.md` + `docs/CODING.md` |

## Requirements
- Godot 4.x
- Bash (Git Bash on Windows ships with Git for Windows)
- (optional) [GUT](https://github.com/bitwes/gut) for headless auto-tests
- (optional, recommended) **Godot MCP** — lets the agent drive Godot over MCP: see [`docs/MCP.md`](docs/MCP.md)

## License
MIT — see `LICENSE`.
