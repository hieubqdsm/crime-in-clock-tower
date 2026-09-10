# ROADMAP — Crime in Clock Tower

> The game's overall plan. The agent/dev updates feature status here.
> Detailed source of truth lives in `docs/features/F-xxx.md` (this file is just the big map).
> Full workflow: `docs/WORKFLOW.md`.

## Game

- **Name:** Crime in Clock Tower
- **Description (1 line):** 3D isometric detective game — explore rooms, gather
  clues, solve the murder in the clock tower. (Core feel: calm investigation.)
- **Engine:** Godot 4.7.1 (headless-driven, MCP + CLI)
- **Target platform:** PC

## Milestones

| Milestone | Goal | Status |
|---|---|---|
| **M0 — Vertical slice** | Wooden mannequin walks a 3D room in isometric view (player + camera + room) | done (F-001 shipped) |
| **M1 — Investigation loop** | Interactable clue objects, inventory, one solvable case | planned |
| **M2 — Clock tower floors** | Multi-room/multi-floor tower progression | planned |

## Feature register

| ID | Name | Priority | Status | Auto-test | Playtest | Assigned | Branch | Depends on |
|---|---|---|---|---|---|---|---|---|
| F-001 | Wooden mannequin isometric room movement | P1 | shipped | pass | pass | agent | feat/F-001-mannequin-isometric-room | — |
| F-002 | Proximity sound tokens | P1 | pass | pass | pass | agent | feat/F-002-proximity-sound-tokens | F-001 |

_(Add a row when creating a new feature. The status/auto-test/playtest columns follow the feature file.)_

## Legend

- **Status:** `planned` → `in_dev` → `dev_done` → `playtesting` → `pass` → `shipped` (× `fail` loops back to `in_dev`).
- **Priority:** `P0` blocker · `P1` important · `P2` normal · `P3` nice-to-have.
- **Auto-test:** `—` none yet · `pass` · `fail`.
- **Playtest:** `—` not reached · `pending` awaiting tester · `pass` · `fail`.
