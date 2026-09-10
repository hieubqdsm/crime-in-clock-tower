extends SceneTree

## One-off: build the mannequin AnimationTree state machine resource.
## godot --headless --path . -s res://tools/make_anim_fsm.gd
## Output: res://scenes/player/mannequin_fsm.tres (committed, human-editable).
## Clips come from assets/models/mannequin.glb (Idle / Walk / Run).

func _init() -> void:
	var sm := AnimationNodeStateMachine.new()

	var idle := AnimationNodeAnimation.new()
	idle.animation = &"Idle"
	sm.add_node("Idle", idle, Vector2(100, 100))

	var walk := AnimationNodeAnimation.new()
	walk.animation = &"Walk"
	sm.add_node("Walk", walk, Vector2(320, 100))

	var run := AnimationNodeAnimation.new()
	run.animation = &"Run"
	sm.add_node("Run", run, Vector2(540, 100))

	var idle_to_walk := AnimationNodeStateMachineTransition.new()
	idle_to_walk.xfade_time = 0.12
	sm.add_transition("Idle", "Walk", idle_to_walk)

	var walk_to_idle := AnimationNodeStateMachineTransition.new()
	walk_to_idle.xfade_time = 0.2
	sm.add_transition("Walk", "Idle", walk_to_idle)

	var walk_to_run := AnimationNodeStateMachineTransition.new()
	walk_to_run.xfade_time = 0.15
	sm.add_transition("Walk", "Run", walk_to_run)

	var run_to_walk := AnimationNodeStateMachineTransition.new()
	run_to_walk.xfade_time = 0.15
	sm.add_transition("Run", "Walk", run_to_walk)

	var err := ResourceSaver.save(sm, "res://scenes/player/mannequin_fsm.tres")
	print("[fsm] saved err=%s path=res://scenes/player/mannequin_fsm.tres" % err)
	quit(0)
