---
# ── Structured handoff ─────────────────────────────────────────────
# Rule: every field is a "logged fact". A resuming agent/dev can ONLY read
# from here — never keep state in the conversation (model-visible ⟺ logged).
# Full schema: docs/WORKFLOW.md §"State discipline".
last_updated: "2026-09-09"
phase: dev
branch: feat/F-001-mannequin-isometric-room
handoff_kind: planned-next     # planned-next = just continue | pause = wait for a human decision
current_focus: F-001          # feature id being worked on, or "none"

next_action: "F-001 is dev_done + auto_test pass and sits in docs/PLAYTEST_QUEUE.md — WAIT for the tester's playtest.result. If pass → merge feat/F-001-mannequin-isometric-room into main (status: shipped) and open F-002 (first clue object / interaction, per ROADMAP M1). If fail → read playtest.notes in docs/features/F-001.md and fix on the same branch."

# Evidence — work DONE in this session, with proof (commit/file).
# No evidence = considered not done. (Ralph-handoff: evidence field)
done:
  - "Repo initialized as game repo: init.sh run, TEMPLATE removed, name 'Crime in Clock Tower' (commit 70c0249)"
  - "project.godot written directly (Godot 4.7.1, input actions move_up/down/left/right WASD+arrows) (commit 70c0249)"
  - "ROADMAP filled: game description, M0/M1/M2 milestones, F-001 row (commit 7ee050c)"
  - "Wooden mannequin glb built headless in Blender 5.2.1, generator committed at tools/blender/make_mannequin.py, asset at assets/models/mannequin.glb (in-place Walk_loop clip, 10 channels, verified via glb_probe) (commit c57cd97)"
  - "Scenes: scenes/player/Player.tscn (+player.gd), scenes/room/Room.tscn, scenes/main/Main.tscn (isometric ortho camera 35.264°/45°, sun + world env) (commit c57cd97)"
  - "Auto-test tests/test_movement.tscn: 9/9 PASS exit 0 — camera-relative movement, speed, model facing, walk anim play/stop, wall blocking; scene smoke tests 0 errors (commit c57cd97)"
  - "F-001 → dev_done, auto_test: pass; pushed to docs/PLAYTEST_QUEUE.md"
  - "docs/LOCAL.md written: godot_exe + blender_exe paths (gitignored)"

# Blockers — each line: '<what> (→ <condition to clear>)'. Empty = not stuck.
blockers: []

# Decisions waiting for a human (only required when handoff_kind: pause).
decisions_pending: []
---

# Session state — Crime in Clock Tower

> **Read this file first.** This is the resume entry point for any AI/dev entering a session.
> Full workflow: `docs/WORKFLOW.md`.

## Quick resume
1. Read the frontmatter above: `current_focus` + `next_action` = the next piece of work.
2. `done:` = evidence of finished work; `blockers:` = what's stuck.
3. `handoff_kind: planned-next` → continue `next_action` right away.

## Context (fits no field above)
- Godot exe: `docs/LOCAL.md` (4.7.1 console build); Blender 5.2.1 LTS for asset work
  (skill `blender-3d-headless`, previews land in `D:\GODOTPRJ\blender_out\`).
- Lessons learned this session (apply next time):
  - .tscn `Transform3D(...)` serializes the basis ROW-major — computing columns
    and writing them as triplets rotates the node by the transpose (camera looked
    mirrored; movement test caught it).
  - Godot's glTF importer strips the `_loop` suffix from clip names and enables
    looping: authored "Walk_loop" → plays as "Walk".
  - `Input.get_vector(nx, px, ny, py)`: up-screen must be the POSITIVE y arg.
- The mannequin model is intentionally stiff/toy-like (artist figure); visual
  polish (arm swing readability) can iterate after playtest feedback.
