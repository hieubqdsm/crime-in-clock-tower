extends Node3D

## Corner sound token (F-002): loops one distinct sound, audible only when
## the player is near (inverse-square falloff), panned in 3D so the corner
## it comes from is readable by ear. Belongs to the "sound_tokens" group.

@export var stream: AudioStream
@export var glow_color := Color(1.0, 0.8, 0.4)

@onready var _audio: AudioStreamPlayer3D = $Sound
@onready var _glow: OmniLight3D = $Glow


func _ready() -> void:
	add_to_group("sound_tokens")
	if stream == null:
		return
	# Looping: the WAV importer ignores its loop params in 4.7, so enable it
	# here (guarded one-time mutation of the shared imported stream).
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if stream is AudioStreamMP3 and not stream.loop:
		stream.loop = true
	_audio.stream = stream
	_glow.light_color = glow_color


func _process(_delta: float) -> void:
	# Lifecycle by listener distance. A single play() in _ready is NOT enough:
	# the engine deactivates out-of-range 3D players and (in Godot 4) never
	# resumes them, so tokens that START beyond max_distance stayed silent
	# forever (the F-002 "no sound" bug). Restart on entry instead.
	if stream == null:
		return
	var listener := get_viewport().get_audio_listener_3d()
	if listener == null:
		return
	var d := global_position.distance_to(listener.global_position)
	if d <= _audio.max_distance:
		if not _audio.playing:
			_audio.play()
	elif _audio.playing:
		_audio.stop()


func distance_to(player: Node3D) -> float:
	return global_position.distance_to(player.global_position)
