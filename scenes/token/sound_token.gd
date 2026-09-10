extends Node3D

## Corner sound token (F-002): audible only when the player is near, louder
## with proximity, panned so the corner it sits in is readable by ear.
##
## Implementation note: this deliberately uses a NON-positional
## AudioStreamPlayer + a per-token panner bus instead of
## AudioStreamPlayer3D. The 3D pipeline never produced samples on the
## tester's machines (voice "playing" yet Master bus peak at -200 dB on both
## Windows and web), while plain 2D playback is audible everywhere — so the
## distance curve and stereo pan are computed here, in code, where they can
## be tested. Belongs to the "sound_tokens" group.

@export var stream: AudioStream
@export var glow_color := Color(1.0, 0.8, 0.4)

## Falloff: full volume inside FULL_RADIUS, inverse-square to -inf, silent
## beyond RANGE. Matches the values the F-002 playtest tuned.
const RANGE := 9.0
const FULL_RADIUS := 3.5
const BASE_DB := 2.0

@onready var _glow: OmniLight3D = $Glow

var _audio: AudioStreamPlayer
var _panner: AudioEffectPanner


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

	# Per-token audio bus with a panner (the pan is set per-frame in _process).
	var bus_name := "Token_%d" % get_instance_id()
	var bus_idx := AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, bus_name)
	AudioServer.set_bus_send(bus_idx, "Master")
	_panner = AudioEffectPanner.new()
	AudioServer.add_bus_effect(bus_idx, _panner)

	_audio = AudioStreamPlayer.new()
	_audio.name = "Sound"  # stable path for tests/HUD/telemetry
	_audio.stream = stream
	_audio.bus = bus_name
	_audio.volume_db = BASE_DB
	add_child(_audio)
	_glow.light_color = glow_color


func _process(_delta: float) -> void:
	if _audio == null:
		return
	var listener := get_viewport().get_audio_listener_3d() as AudioListener3D
	if listener == null:
		if _audio.playing:
			_audio.stop()
		return
	var offset := global_position - listener.global_position
	var d := offset.length()
	if d > RANGE:
		if _audio.playing:
			_audio.stop()
		return
	# Inverse-square falloff clamped to full volume inside FULL_RADIUS.
	var gain := 1.0 if d <= FULL_RADIUS else (FULL_RADIUS / d) ** 2
	_audio.volume_db = BASE_DB + linear_to_db(gain)
	# Pan by the token's direction on the listener's right axis.
	var right := listener.global_transform.basis.x
	right.y = 0.0
	_panner.pan = 0.8 * (right.normalized().dot(offset.normalized()) if not right.is_zero_approx() and d > 0.01 else 0.0)
	if not _audio.playing:
		_audio.play()


func distance_to(player: Node3D) -> float:
	return global_position.distance_to(player.global_position)
