---
# ── Structured handoff ─────────────────────────────────────────────
# Rule: every field is a "logged fact". A resuming agent/dev can ONLY read
# from here — never keep state in the conversation (model-visible ⟺ logged).
# Full schema: docs/WORKFLOW.md §"State discipline".
last_updated: "2026-09-10"
phase: planned
branch: main
handoff_kind: planned-next     # planned-next = just continue | pause = wait for a human decision
current_focus: none           # feature id being worked on, or "none"

next_action: "Open F-002 (M1 investigation loop, first slice): clue object the
player can approach and examine — highlight when near, press E to inspect,
clue data as a Resource (.tres). Follow docs/WORKFLOW.md §2: copy the feature
template, create branch feat/F-002-<slug>, add the ROADMAP row, commit."

# Evidence — work DONE in this session, with proof (commit/file).
# No evidence = considered not done. (Ralph-handoff: evidence field)
done:
  - "F-001 SHIPPED: playtest pass approved in chat ('tốt, chốt move set'),
    merged to main (cdd1637), feature branch kept. Final move set: WASD walk
    1.44 / Shift fast-walk 3.08 (belly-out, kept per tester) / Ctrl sprint
    4.63 m/s (forward lean + head tuck + alternating back arms), synced
    BlendSpace1D gait blending, accel/decel glide stops, 24x24 room, smooth
    follow camera. Headless 17/17; web verified end to end."
  - "Stop behavior fixed (chat 2026-09-10): legs no longer spin back on key
    release — locomotion is now Idle <-> Loco(BlendSpace1D sync, Walk/Run/
    Sprint points at 1.44/3.08/4.63, blend_position = real speed) + accel/
    decel (14/9 m/s²). Headless 17/17 (blend-position gait checks); web decel
    curve verified: 4.63 -> 3.99 -> 1.87 -> Idle over ~0.45 s"
  - "Sprint pose fixed (chat 2026-09-10): the lean sign was INVERTED for
    up-pointing bones (+x = forward for the chest; legs are the opposite) —
    sprint now +14° forward chest lean + 8° head tuck (neck animated, clips
    11 ch) + arms biased back (alternating full back-swing). Run unchanged
    (intentional belly-out on Shift)."
  - "True sprint + 24x24 room + follow camera (chat 2026-09-10); fast-walk on
    Shift, sprint on Ctrl; camera_follow.gd smooth follow"
  - "Earlier this feature: mannequin glb (4 clips) via tools/blender/
    make_mannequin.py, knee-direction fix + invariant asserts, Player/Room/
    Main scenes, isometric camera, web smoke-test pipeline (export preset +
    gameState bridge), see docs/features/F-001.md changelog for the full list"

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
- Web smoke pipeline (how to rebuild/serve/drive the browser build): see
  docs/features/F-001.md §"Web + browser smoke test".
- Lessons learned (apply next time — hard-won, all bit once):
  - .tscn `Transform3D(...)` serializes the basis ROW-major (columns-as-triplets
    = transposed node).
  - Godot's glTF importer strips the `_loop` suffix and enables looping
    ("Walk_loop" → "Walk").
  - `Input.get_vector(nx, px, ny, py)`: up-screen must be the POSITIVE y arg.
  - `JavaScriptBridge.available` doesn't exist in 4.7; guard web code with
    `OS.has_feature("web")`.
  - Web input: key events must hit the CANVAS element and the webview needs one
    REAL click first (`document.hasFocus()`).
  - Web audio on nothreads builds: ONLY raw-PCM WAV in RAM works
    (compress/mode=0). Disk-streamed WAV (mode 2), AudioStreamMP3, AND
    AudioStreamPlayer3D.get_playback_position() each deadlock the engine
    SILENTLY at load/call (3 separate incidents — console shows 3 boot lines
    then nothing). Diagnose by loading the game in a same-origin iframe with
    patched console; convert music via tools/audio/convert_mashup.py
    (soundfile decodes mp3 without ffmpeg).
  - AnimationPlayer 4.7 has NO `play_with_crossfade` — use AnimationTree.
  - Multi-clip glb: shared slotted actions + per-object NLA strips
    (strip.action_slot), then clear animation_data.action.
  - Locomotion gaits: ONE synced BlendSpace1D keyed by real speed + accel/decel
    (never per-gait FSM states — legs spin back on stop).
  - Rotation sign flips with bone direction: +x = backward for hanging limbs,
    forward for up-pointing bones (the belly-out bug).
  - Per-leg clamps: clamp BEFORE applying the leg sign (knee direction bug).
  - Exported Node3D from tscn does NOT auto-resolve at runtime — export a
    NodePath and get_node_or_null it.
  - IAB tab gets rAF-throttled after a failed screenshot capture — reopen tab.
