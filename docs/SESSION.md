---
# ── Structured handoff ─────────────────────────────────────────────
last_updated: "2026-09-10"
phase: planned
branch: main
handoff_kind: planned-next
current_focus: none

next_action: "Open F-004. Candidates from the tester's party-game vision:
proximity VOICE chat over the existing websocket/net layer (mic capture,
opus/pcm frames, only audible near other players), or gameplay (clues,
roles, night phase). Follow docs/WORKFLOW.md §2."

done:
  - "F-003 SHIPPED: online foundation — python room server (tools/server/
    server.py, takeover by browser id), NetClient + RemotePlayer + Options
    UI (press O: name + server URL + connect), names over heads, cloudflare
    quick-tunnel guide (docs/LOCAL.md). Tester confirmed 2 players see each
    other + movement sync via Pages + wss tunnel. Headless e2e 5/5."
  - "F-002 shipped: proximity sound tokens (2D + code falloff; zero-length-
    loop root cause). F-001 shipped: movement/sprint/follow-cam."

blockers: []
decisions_pending: []
---

# Session state — Crime in Clock Tower

## Quick resume
1. current_focus + next_action = next piece of work.
2. done = evidence; blockers empty.
3. handoff_kind: planned-next → continue right away.

## Context
- Live: https://hieubqdsm.github.io/crime-in-clock-tower/ — redeploy with
  `bash tools/deploy_web.sh` (Pages CDN/browser cache ~10 min).
- Multiplayer session: `python tools/server/server.py` (+ cloudflared for
  friends, see docs/LOCAL.md; quick-tunnel URLs are temporary).
- All engine lessons (audio web pitfalls, lambda captures, tscn connections,
  row-major transforms, etc.) are in this file's git history and
  docs/features/F-00x.md changelogs — read F-002's for the audio rules.
- Tester vision: online party game like Blood on the Clocktower, web-based.
