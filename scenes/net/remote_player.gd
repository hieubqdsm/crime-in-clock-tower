extends Node3D

## RemotePlayer: another browser's mannequin. Receives 12 Hz states from the
## server via Main and interpolates position/heading; plays the glb's own
## Walk/Idle clips directly (no blendspace needed for remote view).

const INTERP := 12.0
## Voice falloff (slightly wider than the music tokens — talking carries):
## full inside FULL_RADIUS, inverse-square beyond, silent past RANGE.
const FULL_RADIUS := 4.0
const RANGE := 15.0
const MIX_RATE := 48000.0

@onready var _anim: AnimationPlayer = $Mannequin/AnimationPlayer
@onready var _label: Label3D = $NameLabel

var _voice_player: AudioStreamPlayer
var _voice_playback: AudioStreamGeneratorPlayback
var _speak_decay := 0.0

var _target := Vector3.ZERO
var _target_ry := 0.0
var _seen := false


func setup(display_name: String) -> void:
	_label.text = display_name


func set_display_name(display_name: String) -> void:
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


func setup_voice() -> void:
	# Per-remote generator stream; frames are pushed by receive_voice().
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = int(MIX_RATE)
	stream.buffer_length = 0.3
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "Voice"
	_voice_player.stream = stream
	_voice_player.bus = "Master"
	add_child(_voice_player)
	_voice_player.play()
	_voice_playback = _voice_player.get_stream_playback()


func receive_voice(pcm: PackedByteArray, listener_pos: Vector3) -> void:
	if _voice_playback == null:
		return
	_speak_decay = 0.4   # keeps the speaking indicator lit between chunks
	var d := global_position.distance_to(listener_pos)
	if d > RANGE:
		return
	var gain := 1.0 if d <= FULL_RADIUS else (FULL_RADIUS / d) ** 2
	var n := pcm.size() / 2
	var frames := PackedVector2Array()
	frames.resize(n)
	for i in n:
		var v := pcm.decode_s16(i * 2) / 32768.0 * gain
		frames[i] = Vector2(v, v)
	_voice_playback.push_buffer(frames)


func is_speaking() -> bool:
	return _speak_decay > 0.0


func _process(delta: float) -> void:
	_speak_decay = maxf(0.0, _speak_decay - delta)
	_label.modulate = Color(0.55, 1.0, 0.55) if _speak_decay > 0.0 else Color.WHITE
	if _seen:
		global_position = global_position.lerp(_target, minf(1.0, INTERP * delta))
		rotation.y = lerp_angle(rotation.y, _target_ry, minf(1.0, INTERP * delta))
