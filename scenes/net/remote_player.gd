extends Node3D

## RemotePlayer: another browser's mannequin. Receives 12 Hz states from the
## server via Main and interpolates position/heading; plays the glb's own
## Walk/Idle clips directly (no blendspace needed for remote view).

const INTERP := 12.0

@onready var _anim: AnimationPlayer = $Mannequin/AnimationPlayer
@onready var _label: Label3D = $NameLabel

var _target := Vector3.ZERO
var _target_ry := 0.0
var _seen := false


func setup(display_name: String) -> void:
	_label.text = display_name


func apply_state(x: float, z: float, ry: float, moving: bool) -> void:
	if not _seen:
		_seen = true
		global_position = Vector3(x, 0.0, z)
		rotation.y = ry
	_target = Vector3(x, 0.0, z)
	_target_ry = ry
	var anim := "Walk" if moving else "Idle"
	if _anim.current_animation != anim:
		_anim.play(anim)


func _process(delta: float) -> void:
	if _seen:
		global_position = global_position.lerp(_target, minf(1.0, INTERP * delta))
		rotation.y = lerp_angle(rotation.y, _target_ry, minf(1.0, INTERP * delta))
