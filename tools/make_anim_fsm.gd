extends SceneTree

## One-off: build the mannequin AnimationTree state machine resource.
## godot --headless --path . -s res://tools/make_anim_fsm.gd
## Output: res://scenes/player/mannequin_fsm.tres (committed, human-editable).

func _init() -> void:
	var sm := AnimationNodeStateMachine.new()

	var idle := AnimationNodeAnimation.new()
	idle.animation = &"Idle"
	sm.add_node("Idle", idle, Vector2(100, 100))

	var walk := AnimationNodeAnimation.new()
	walk.animation = &"Walk"
	sm.add_node("Walk", walk, Vector2(340, 100))

	var to_walk := AnimationNodeStateMachineTransition.new()
	to_walk.xfade_time = 0.12
	sm.add_transition("Idle", "Walk", to_walk)

	var to_idle := AnimationNodeStateMachineTransition.new()
	to_idle.xfade_time = 0.2
	sm.add_transition("Walk", "Idle", to_idle)

	var err := ResourceSaver.save(sm, "res://scenes/player/mannequin_fsm.tres")
	print("[fsm] saved err=%s path=res://scenes/player/mannequin_fsm.tres" % err)
	quit(0)
