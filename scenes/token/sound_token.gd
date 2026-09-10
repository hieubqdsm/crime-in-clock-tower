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
	# The WAVs import with compress/mode=0 (raw PCM in RAM) — Disk-streamed
	# audio hangs single-threaded web builds at scene load. The importer's
	# edit/loop_mode param is ignored in 4.7, so enable looping here (guarded,
	# one-time mutation of the shared imported stream).
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_audio.stream = stream
	_glow.light_color = glow_color
	_audio.play()


func distance_to(player: Node3D) -> float:
	return global_position.distance_to(player.global_position)
