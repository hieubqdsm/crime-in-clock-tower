extends Node

## F-001 auto-test: mannequin movement in the isometric room, headless.
## Run:  godot --headless --path . res://tests/test_movement.tscn
## Exit code 0 = all checks passed.

var failures := 0

var _main: Node3D
var _player: CharacterBody3D
var _model: Node3D
var _anim_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback


func _tree_state() -> String:
	return _playback.get_current_node()


func _ready() -> void:
	await _run()
	print("[test] %s (%d fail)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _run() -> void:
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(_main)
	for i in 30:
		await get_tree().physics_frame

	_player = _main.get_node("Player")
	_check(_player != null, "player exists in Main")
	if _player == null:
		return
	_model = _player.get_node("Mannequin")
	_anim_tree = _player.get_node("AnimTree")
	_playback = _anim_tree["parameters/playback"]

	_check(absf(_player.global_position.y) < 0.1,
		"player settles on the floor (y=%.2f)" % _player.global_position.y)
	_check(_tree_state() == "Idle", "starts in the Idle state (%s)" % _tree_state())

	# move_up must be camera-relative: the iso camera looks from (+x,+z) at the
	# origin, so up-screen is the (-x,-z) diagonal.
	var start := _player.global_position
	Input.action_press("move_up")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_up")
	var d := _player.global_position - start
	_check(d.x < -0.3 and d.z < -0.3,
		"move_up moves up-screen (dx=%.2f dz=%.2f)" % [d.x, d.z])
	_check(d.length() > 0.7 and d.length() < 2.1,
		"~walk speed for 1 s (moved %.2f m, expect ~1.44)" % d.length())

	var want_rot := atan2(-0.7071, -0.7071)
	_check(_angle_diff(_model.rotation.y, want_rot) < 0.15,
		"model faces its movement direction (rot=%.2f want=%.2f)" % [_model.rotation.y, want_rot])
	_check(_tree_state() == "Walk", "Walk state while moving (%s)" % _tree_state())
	for i in 20:
		await get_tree().physics_frame
	_check(_tree_state() == "Idle", "crossfades back to Idle when stopped (%s)" % _tree_state())
	_check(_player.velocity.length() < 0.05,
		"velocity is zero when idle (%.2f)" % _player.velocity.length())

	# Fast walk (Shift): Run state at run speed; release Shift -> Walk.
	var run_start := _player.global_position
	Input.action_press("move_up")
	Input.action_press("fast_walk")
	for i in 60:
		await get_tree().physics_frame
	_check(_tree_state() == "Run", "Run state while fast-walking (%s)" % _tree_state())
	var run_d := _player.global_position - run_start
	_check(run_d.length() > 2.2 and run_d.length() < 4.2,
		"fast-walk speed for 1 s (moved %.2f m, expect ~3.08)" % run_d.length())
	Input.action_release("fast_walk")
	for i in 25:
		await get_tree().physics_frame
	_check(_tree_state() == "Walk", "back to Walk when Shift released (%s)" % _tree_state())

	# True sprint (Ctrl): Sprint state at sprint speed, camera follows along.
	var cam := _main.get_node("IsometricCamera") as Camera3D
	var sprint_start := _player.global_position
	var cam_start := cam.global_position
	Input.action_press("sprint")
	for i in 60:
		await get_tree().physics_frame
	_check(_tree_state() == "Sprint", "Sprint state while Ctrl held (%s)" % _tree_state())
	var sprint_d := _player.global_position - sprint_start
	_check(sprint_d.length() > 3.4 and sprint_d.length() < 5.8,
		"sprint speed for 1 s (moved %.2f m, expect ~4.63)" % sprint_d.length())
	var cam_d := cam.global_position - cam_start
	_check(cam_d.length() > 1.0 and cam_d.normalized().dot(sprint_d.normalized()) > 0.7,
		"camera follows the player (cam moved %.2f m, same direction)" % cam_d.length())
	Input.action_release("sprint")
	Input.action_release("move_up")
	for i in 20:
		await get_tree().physics_frame
	_check(_tree_state() == "Idle", "back to Idle after sprint stop (%s)" % _tree_state())

	# North wall (24 m room): park just south of it and sprint into it 1.5 s.
	_player.global_position = Vector3(0, 0.1, -11.2)
	_player.velocity = Vector3.ZERO
	for i in 5:
		await get_tree().physics_frame
	Input.action_press("move_up")
	Input.action_press("sprint")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("move_up")
	Input.action_release("sprint")
	_check(_player.global_position.z > -11.75,
		"north wall blocks movement (z=%.2f, inner face -11.85 + radius 0.28)" % _player.global_position.z)


func _check(ok: bool, what: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _angle_diff(a: float, b: float) -> float:
	return absf(wrapped_angle(a - b))


func wrapped_angle(angle: float) -> float:
	return wrapf(angle, -PI, PI)
