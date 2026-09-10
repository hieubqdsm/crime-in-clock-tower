extends CharacterBody3D

## Wooden mannequin movement for the isometric room.
##
## Movement directions are relative to the active camera, flattened onto the
## floor plane: "up" on the keyboard always moves up-screen in the isometric
## view, whichever way the camera is aimed. The model itself faces +Z
## (built facing -Y in Blender; see tools/blender/make_mannequin.py).
##
## Animations run through an AnimationTree state machine ($AnimTree +
## mannequin_fsm.tres): Idle <-> Walk with xfade crossfades, and the model
## heading eases toward the movement direction (no instant snaps).

## One walk cycle (1 s) covers two steps of 2 * 0.82 * sin(26°) m each
## (= 1.44 m), per the stride math in tools/blender/make_mannequin.py —
## keep the default in sync with the clip or the feet will slide.
const WALK_SPEED := 1.44
const TURN_SMOOTH := 12.0
const IDLE_STATE := "Idle"
const WALK_STATE := "Walk"

@export var walk_speed := WALK_SPEED

@onready var _model: Node3D = $Mannequin
@onready var _anim_tree: AnimationTree = $AnimTree
@onready var _playback: AnimationNodeStateMachinePlayback = _anim_tree["parameters/playback"]

var _heading := 0.0
var _was_moving := false
var _web_frame := 0


func _ready() -> void:
	_playback.start(IDLE_STATE)
	_anim_tree.active = true


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

	_update_visuals(dir, delta)
	_web_frame += 1
	if _web_frame % 10 == 0:
		_push_web_state()


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


func _update_visuals(dir: Vector3, delta: float) -> void:
	var moving := dir != Vector3.ZERO
	if moving:
		# Exponential ease toward the movement heading — smooth 8-way turns.
		_heading = lerp_angle(_heading, atan2(dir.x, dir.z),
			1.0 - exp(-TURN_SMOOTH * delta))
		_model.rotation.y = _heading
		if _playback.get_current_node() != WALK_STATE:
			_playback.travel(WALK_STATE)
	elif _playback.get_current_node() != IDLE_STATE:
		_playback.travel(IDLE_STATE)
	_was_moving = moving


func _push_web_state() -> void:
	## Test telemetry for the browser build (web + Playwright smoke test).
	## No-op outside the web platform; see docs/features/F-001.md.
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.gameState={px:%.3f,py:%.3f,pz:%.3f,vx:%.3f,vz:%.3f,moving:%s,anim:%s}"
		% [global_position.x, global_position.y, global_position.z,
			velocity.x, velocity.z, str(_was_moving),
			JSON.stringify(_playback.get_current_node())])
