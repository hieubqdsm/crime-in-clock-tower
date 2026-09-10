extends Node3D

## Corner sound token (F-002): loops one distinct sound, audible only when
## the player is near (inverse-square falloff), panned in 3D so the corner
## it comes from is readable by ear. Belongs to the "sound_tokens" group.

@export var stream: AudioStream
@export var glow_color := Color(1.0, 0.8, 0.4)

@onready var _audio: AudioStreamPlayer3D = $Sound
@onready var _glow: OmniLight3D = $Glow

var _watchdog := 0.0


func _ready() -> void:
	add_to_group("sound_tokens")
	if stream == null:
		return
	# Looping: the WAV importer ignores its loop params (runtime guard below);
	# the MP3 importer honors its loop param but keep a guard anyway. A
	# watchdog in _process restarts playback if a stream ever runs out.
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if stream is AudioStreamMP3 and not stream.loop:
		stream.loop = true
	_audio.stream = stream
	_glow.light_color = glow_color
	_audio.play()


func _process(delta: float) -> void:
	_watchdog += delta
	if _watchdog < 0.5:
		return
	_watchdog = 0.0
	if stream != null and not _audio.playing:
		_audio.play()


func distance_to(player: Node3D) -> float:
	return global_position.distance_to(player.global_position)
