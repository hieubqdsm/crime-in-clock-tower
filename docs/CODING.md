# CODING — Game code design policy

> **Fixed rules about HOW to write code** (policy — never mixed with state).
> Feature process/lifecycle lives in `docs/WORKFLOW.md`; agent operations in `AGENTS.md`.
>
> The spirit in one sentence: **the repo must be an ORDINARY Godot project** — the
> agent can write & test it headless, a human (dev/tester) opens the editor and
> understands it immediately. The "agent generates one giant script that builds the
> whole scene tree at runtime" style is not acceptable.

## 0. Principle zero — headless-testable & human-editable

Two constraints of this harness, **above every other principle**:

- **Scenes must run standalone.** The agent cannot press F6 (headless only —
  `AGENTS.md` §0.2). The agent's F6 is:
  ```sh
  godot --headless --path . res://scenes/player.tscn --quit
  ```
  Every entity-level scene must pass this command without errors.
- **Logic separated from presentation.** Gameplay logic goes into classes testable
  without a window (headless GUT). `_process` stays thin — dispatch only, no logic.
- **A human opening the editor understands it.** Self-explanatory node names, wiring
  done in the editor, NEVER instantiating the whole scene tree from code at runtime —
  the scene tree must be statically visible, because human testers/devs work on it.

## 1. Everything is a Scene — at entity level

- One entity = one scene (`Player.tscn`, `Coin.tscn`, `HUD.tscn`), runnable and
  testable standalone (principle 0).
- **Valid exception:** intermediate fragments (one HUD row, a small hitbox, a private
  sub-scene) don't need a "meaningful" standalone run — don't force the F6 rule onto
  every child scene; that just generates pointless scaffolding.

## 2. Call Down, Signal Up — the default, not an absolute

- Parents call child functions directly; **reusable components NEVER `get_parent()`**.
- Children report upward via signals — but pick the channel by relationship, don't
  signal-ize everything:
  - **Known 1:1** (a HealthBar always belongs to a HUD) → pass the reference down
    (`@export var bar: HealthBar`) — easier to trace than a signal.
  - **Broadcast** (whoever cares listens) → signal up to the parent / owning scene.
  - **Truly global** → EventBus (principle 5).
- Legit exceptions: private wiring inside a sub-scene, `%UniqueName` within one scene.
- Signal spaghetti is harder to debug than calls — only signal when several parties
  genuinely listen.

## 3. Moderate composition — no node bloat

- **Component nodes** for things that belong in the scene tree: `HitboxComponent`
  (Area2D), `HealthComponent` (Node)... drag-and-drop reuse instead of deep
  inheritance (script inheritance >1 level is suspicious).
- **Plain `RefCounted` classes for pure logic** (damage math, AI decisions,
  shuffling...): testable headless without building a scene, no node overhead. This
  is the most test-friendly level — prefer it for game logic.
- Not "everything is a component": 5-7 component nodes per entity × hundreds of
  entities = a scene tree humans can't read + needless node cost.

## 4. Data-driven with Resources — mind the sharing trap

- Config separated from logic: `class_name` extends `Resource` (`ItemData.gd`,
  `EnemyStats.gd`), variants saved as `.tres`, nodes just `@export` and drag-and-drop —
  **humans tweak numbers in the Inspector without touching code**.
- ⚠ **Resources are shared by default:** two nodes pointing at the same
  `GoblinStats.tres` share ONE runtime instance; mutating `stats.hp` on one leaks to
  the others. Need a private copy → `duplicate()` or enable `local_to_scene`.
- Don't promote every config to a Resource class — for 2-3 variables plain `@export`
  is usually enough.

## 5. Autoload = pure signal bus, NOT a variable store

- Autoloads **hold no state** (global variables) — the root of test leaks,
  init-order dependencies, and state surviving scene changes undisciplined.
- An EventBus autoload (e.g. `Events.gd`) only declares signals, and is used only for
  **truly cross-cutting** events (game_over, scene_changed). Everything else uses
  principle 2.
- **Auto-tests must reset the bus between tests** — autoloads survive across tests;
  connections leak from one test into the next without cleanup.

## Code review checklist (agent + dev)

- [ ] Does every entity scene pass `godot --headless --path . <scene> --quit`?
- [ ] Any component calling `get_parent()` / upward into its parent?
- [ ] Pure logic stuck inside a Node/`_process`? (move it to `RefCounted`)
- [ ] Any runtime mutation of a shared Resource?
- [ ] Does any autoload hold state variables? Do tests reset the bus?
- [ ] Open the editor: do the scene tree + node names explain themselves?
