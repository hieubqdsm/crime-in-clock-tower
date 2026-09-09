# SETUP — ask the user once, write it down, never ask again

> The agent reads this file when it needs information that lives on the user's machine.
> Communication rules: `AGENTS.md` §1b. Short version: LOCAL.md → which/env → ASK.
> **Asking = a plain chat message, then wait** — no select-lists, no choice boxes.
> **Never scan disks to find paths.**

## Why

By default an agent will try to "find" godot itself across drives — slow, and it
rummages through the user's personal data. Information only the user certainly knows
(what's installed where on their machine) is fastest asked: 10 seconds of their time
instead of 10 minutes of probing. After asking you **must write it down** — the next
session reads the file and never re-asks an answered question.

## What to ask (standard checklist)

| Information | Ask when | Used for |
|---|---|---|
| Godot exe path (the `_console` build on Windows) | first run / headless test | auto-test, export |
| Godot version | first time | project.godot features |
| Export templates installed? (matching version?) | when web/desktop export is needed | builds |
| Node.js / Python + libs | when tooling is needed (Playwright, PIL...) | pipelines |

## `docs/LOCAL.md` format

This file is **gitignored** — write machine paths freely, they never get pushed.
Create it upon the first answer:

```markdown
# LOCAL — machine config (gitignored, never committed)

- godot_exe: "D:\\Tools\\Godot_v4.7.1\\Godot_v4.7.1-stable_win64_console.exe"
- godot_version: 4.7.1
- export_templates: yes (4.7.1.stable, including web)
- node: v24.11.1
- python: 3.10 (PIL, numpy available)
- note: the _console build shows stdout in a Windows terminal
```

Next session: read this file at step 1 of the protocol (`AGENTS.md` §1) — if
`godot_exe` is there, use it directly; don't re-ask, don't `find`.
