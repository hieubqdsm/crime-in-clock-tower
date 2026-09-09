extends Node

## F-001 auto-test: mannequin movement in the isometric room, headless.
## Run:  godot --headless --path . res://tests/test_movement.tscn
## Exit code 0 = all checks passed.

var failures := 0

var _main: Node3D
var _player: CharacterBody3D
var _model: Node3D
var _anim: AnimationPlayer


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
	_anim = _model.get_node("AnimationPlayer")

	_check(absf(_player.global_position.y) < 0.1,
		"player settles on the floor (y=%.2f)" % _player.global_position.y)

	# move_up must be camera-relative: the iso camera looks from (+x,+z) at the
	# origin, so up-screen is the (-x,-z) diagonal.
	var start := _player.global_position
	Input.action_press("move_up")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_up")
	var d := _player.global_position - start
	_check(d.x < -0.5 and d.z < -0.5,
		"move_up moves up-screen (dx=%.2f dz=%.2f)" % [d.x, d.z])
	_check(d.length() > 1.0 and d.length() < 3.4,
		"~walk speed for 1 s (moved %.2f m, expect ~2.2)" % d.length())

	var want_rot := atan2(-0.7071, -0.7071)
	_check(_angle_diff(_model.rotation.y, want_rot) < 0.15,
		"model faces its movement direction (rot=%.2f want=%.2f)" % [_model.rotation.y, want_rot])
	_check(_anim.is_playing() and _anim.current_animation == "Walk",
		"Walk plays while moving")
	for i in 10:
		await get_tree().physics_frame
	_check(not _anim.is_playing(), "animation stops when idle")
	_check(_player.velocity.length() < 0.05,
		"velocity is zero when idle (%.2f)" % _player.velocity.length())

	# North wall: park just south of it and walk into it for 1.5 s.
	_player.global_position = Vector3(0, 0.1, -5.2)
	_player.velocity = Vector3.ZERO
	for i in 5:
		await get_tree().physics_frame
	Input.action_press("move_up")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("move_up")
	_check(_player.global_position.z > -5.6,
		"north wall blocks movement (z=%.2f, inner face -5.7 + radius 0.28)" % _player.global_position.z)


func _check(ok: bool, what: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _angle_diff(a: float, b: float) -> float:
	return absf(wrapped_angle(a - b))


func wrapped_angle(angle: float) -> float:
	return wrapf(angle, -PI, PI)
