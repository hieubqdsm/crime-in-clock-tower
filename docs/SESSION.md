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

next_action: "Open F-003 (M1 investigation loop). Candidate per tester's party
vision: a MOVING sound token (an 'NPC voice' the mannequin can approach) as
the seed of proximity voice chat, or clue-object interaction + journal UI.
Follow docs/WORKFLOW.md §2: copy the feature template, create branch
feat/F-003-<slug>, add the ROADMAP row, commit."

# Evidence — work DONE in this session, with proof (commit/file).
done:
  - "F-002 SHIPPED: proximity sound tokens — audible on web + desktop
    (tester: 'nghe được rồi'), 4 corner tokens always-play the tester's
    10-min mashup on independent timelines, inverse-square volume falloff
    (full in 3.5 m at -6 dB, floor -30 dB), headless 19/19 + 17/17."
  - "F-002 TRUE ROOT CAUSE (the whole no-sound saga): enabling LOOP_FORWARD
    on an imported AudioStreamWAV leaves loop_end=0 -> ZERO-LENGTH loop ->
    mixer emits zero samples while playing=true and peak reads -200 on all
    platforms. Fix: set loop_begin/loop_end to the full range; regression
    test asserts loop_end > loop_begin. Found via the tester's background-log
    idea (log v=+2 P next to peak -200 was the tell)."
  - "F-002 architecture lessons: AudioStreamPlayer3D mixed ZERO samples on
    the tester's machines (playing=true, peak -200, desktop+web) — the
    mechanic now runs on 2D AudioStreamPlayer + code-computed falloff (reuse
    this pattern for proximity voice chat). Tester design principle adopted:
    sources ALWAYS play from load on their own timeline; distance changes
    VOLUME only."
  - "F-001 shipped earlier this session (movement + sprint + follow cam,
    see git history / F-001.md changelog)"

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
- Godot exe: `docs/LOCAL.md` (4.7.1 console build); Blender 5.2.1 LTS for assets
  (skill `blender-3d-headless`); web build served via
  `python -m http.server 8741 --directory build/web`.
- Web smoke pipeline (rebuild/serve/drive browser, gameState telemetry):
  docs/features/F-001.md §"Web + browser smoke test".
- Audio on web/nothreads — hard-won rules (each one bit once):
  - ONLY raw-PCM WAV in RAM (compress/mode=0) loads safely; Disk-stream WAV,
    AudioStreamMP3, and AudioStreamPlayer3D.get_playback_position() each
    DEADLOCK the engine silently (3 boot lines then nothing — diagnose via
    same-origin iframe with patched console).
  - AudioStreamPlayer3D mixed zero samples on the tester's machines even when
    "playing" — proximity audio is done with 2D players + code falloff.
  - Enabling LOOP_FORWARD on an imported WAV leaves loop_end=0 -> zero-length
    loop -> silent (playing=true, peak -200). ALWAYS set the full range.
  - Web bus peak meters are NOT populated (-200 always) — meaningless on web;
    desktop meters are real. Assert wiring in tests, verify audio by ear.
  - Godot 4 culls out-of-range 3D players permanently (no auto-resume).
  - WAV importer ignores its loop params AND the RIFF smpl chunk; mp3 importer
    honors loop. soundfile (python) decodes mp3 without ffmpeg.
- Other engine lessons (tscn row-major transforms, glTF _loop suffix,
  BlendSpace1D locomotion, rotation sign per bone direction, knee clamps,
  NodePath exports) — see git history of this file; all remain valid.
- Tester's vision: ONLINE PARTY GAME like Blood on the Clocktower, web-based.
  Proximity audio mechanic (F-002) is its first seed.
