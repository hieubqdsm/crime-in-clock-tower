extends Camera3D

## Isometric follow camera: keeps the fixed iso angle, smoothly tracks the
## target (player) around the room. The offset is captured at startup from the
## scene layout, so the camera is still placed/angled in the editor.

@export var target_path: NodePath
@export var follow_smooth := 5.0

var target: Node3D
var _offset: Vector3


func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	if target != null:
		_offset = global_position - target.global_position


func _physics_process(delta: float) -> void:
	if target == null:
		return
	global_position = global_position.lerp(
		target.global_position + _offset,
		1.0 - exp(-follow_smooth * delta))
