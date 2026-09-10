extends SceneTree

## One-off: build the mannequin AnimationTree state machine resource.
## godot --headless --path . -s res://tools/make_anim_fsm.gd
## Output: res://scenes/player/mannequin_fsm.tres (committed, human-editable).
##
## Idle <-> Loco(BlendSpace1D). The gaits (Walk 1.44 / Run 3.08 / Sprint 4.63,
## from assets/models/mannequin.glb) live INSIDE one synced BlendSpace1D keyed
## by real movement speed, so gait changes blend continuously with matched
## cycle phase — no per-gait states, no frame-0 resets, no legs "spinning back"
## when stopping. The player drives `parameters/Loco/blend_position`.

func _init() -> void:
	var sm := AnimationNodeStateMachine.new()

	var idle := AnimationNodeAnimation.new()
	idle.animation = &"Idle"
	sm.add_node("Idle", idle, Vector2(100, 100))

	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 5.0
	loco.sync = true

	var walk := AnimationNodeAnimation.new()
	walk.animation = &"Walk"
	loco.add_blend_point(walk, 1.44)

	var run := AnimationNodeAnimation.new()
	run.animation = &"Run"
	loco.add_blend_point(run, 3.08)

	var sprint := AnimationNodeAnimation.new()
	sprint.animation = &"Sprint"
	loco.add_blend_point(sprint, 4.63)

	sm.add_node("Loco", loco, Vector2(380, 100))

	var idle_to_loco := AnimationNodeStateMachineTransition.new()
	idle_to_loco.xfade_time = 0.15
	sm.add_transition("Idle", "Loco", idle_to_loco)

	var loco_to_idle := AnimationNodeStateMachineTransition.new()
	loco_to_idle.xfade_time = 0.3
	sm.add_transition("Loco", "Idle", loco_to_idle)

	var err := ResourceSaver.save(sm, "res://scenes/player/mannequin_fsm.tres")
	print("[fsm] saved err=%s path=res://scenes/player/mannequin_fsm.tres" % err)
	quit(0)
