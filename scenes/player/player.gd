extends CharacterBody3D

## Wooden mannequin movement for the isometric room.
##
## Movement directions are relative to the active camera, flattened onto the
## floor plane: "up" on the keyboard always moves up-screen in the isometric
## view, whichever way the camera is aimed. The model itself faces +Z
## (built facing -Y in Blender; see tools/blender/make_mannequin.py).

## The glb clip is authored "Walk_loop"; Godot's importer strips the loop token,
## enables looping, and registers it as "Walk".
const WALK_ANIM := "Walk"
## One animation cycle (1 s) covers two steps of 2 * 0.82 * sin(26°) m each,
## per the stride math in tools/blender/make_mannequin.py.
const METERS_PER_ANIM_CYCLE := 0.72

@export var walk_speed := 2.2

@onready var _model: Node3D = $Mannequin
@onready var _anim: AnimationPlayer = $Mannequin/AnimationPlayer

var _was_moving := false
var _web_frame := 0


func _physics_process(delta: float) -> void:
	# y = +1 when pressing move_up (get_vector returns positive_y - negative_y,
	# and screen-space y grows downward, so up-screen must be the positive arg).
	var input := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	var dir := _floor_direction(input)

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	move_and_slide()

	_update_visuals(dir)
	_web_frame += 1
	if _web_frame % 10 == 0:
		_push_web_state()


func _push_web_state() -> void:
	## Test telemetry for the browser build (web + Playwright smoke test).
	## No-op outside the web platform; see docs/features/F-001.md.
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameState={px:%.3f,py:%.3f,pz:%.3f,vx:%.3f,vz:%.3f,moving:%s,anim:%s}"
		% [global_position.x, global_position.y, global_position.z,
			velocity.x, velocity.z, str(_was_moving), JSON.stringify(_anim.current_animation)])


func _floor_direction(input: Vector2) -> Vector3:
	"""Camera-relative input mapped onto the floor plane (XZ)."""
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(input.x, 0.0, input.y)
	var forward := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.is_zero_approx() or right.is_zero_approx():
		return Vector3(input.x, 0.0, input.y)
	var dir := forward.normalized() * input.y + right.normalized() * input.x
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.ZERO


func _update_visuals(dir: Vector3) -> void:
	var moving := dir != Vector3.ZERO
	if moving:
		_model.rotation.y = atan2(dir.x, dir.z)
		if not _was_moving:
			_anim.play(WALK_ANIM)
		_anim.speed_scale = walk_speed / METERS_PER_ANIM_CYCLE
	elif _was_moving:
		# Return to the rest pose (frame 0 of the walk is a standing pose).
		_anim.seek(0.0, true)
		_anim.stop()
	_was_moving = moving
