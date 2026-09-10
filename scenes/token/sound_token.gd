extends Node3D

## Corner sound token (F-002).
##
## Design (per tester): ALWAYS playing from scene load — each token advances
## through the 10-minute track on its own timeline, so different corners play
## different sections; walking closer only raises the volume.
##
## Implementation postmortem: AudioStreamPlayer3D mixed ZERO samples on the
## tester's machines (playing=true yet Master peak -200 dB on both Windows
## and web), while a plain 2D AudioStreamPlayer directly on the Master bus
## was clearly audible on both. So: non-positional player, distance only
## drives volume_db here — no engine culling, no dynamic buses, no panner
## (re-added later, one layer at a time).

@export var stream: AudioStream
@export var glow_color := Color(1.0, 0.8, 0.4)

const FULL_RADIUS := 3.5
const RANGE := 9.0        # beyond this the token clamps to the floor — the
                          # room center (14.1 m from every corner) must be
                          # silent, not a 4-source murmur (playtest feedback)
const BASE_DB := -6.0     # tuned in playtest: +2 was too loud up close
const FLOOR_DB := -45.0   # near-inaudible when far — still "always playing"

@onready var _audio: AudioStreamPlayer = $Sound
@onready var _glow: OmniLight3D = $Glow


func _ready() -> void:
	add_to_group("sound_tokens")
	if stream == null:
		return
	# Looping: the WAV importer ignores its loop params in 4.7, so enable it
	# here — WITH an explicit full-range loop_end. THE F-002 ROOT CAUSE:
	# imported streams carry loop_end=0, so enabling LOOP_FORWARD alone makes
	# a ZERO-LENGTH loop (begin=0..end=0) — the mixer emits no samples while
	# `playing` stays true (silent on every platform, peak -200 forever).
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var wav := stream as AudioStreamWAV
		var frames := wav.data.size() / 2 / (2 if wav.stereo else 1)
		wav.loop_begin = 0
		wav.loop_end = frames - 1
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if stream is AudioStreamMP3 and not stream.loop:
		stream.loop = true
	_audio.stream = stream
	_audio.play()
	_glow.light_color = glow_color


func _process(_delta: float) -> void:
	if _audio == null:
		return
	var listener := get_viewport().get_audio_listener_3d()
	var d := 999.0
	if listener != null:
		d = global_position.distance_to(listener.global_position)
	var vol := FLOOR_DB
	if d <= RANGE:
		var gain := 1.0 if d <= FULL_RADIUS else (FULL_RADIUS / maxf(d, FULL_RADIUS)) ** 2
		vol = maxf(FLOOR_DB, BASE_DB + linear_to_db(gain))
	_audio.volume_db = vol
	# Self-heal: some drivers (e.g. headless dummy) drop a play() issued in
	# _ready; the design is "always playing", so keep it alive.
	if not _audio.playing:
		_audio.play()


func volume_db() -> float:
	return _audio.volume_db if _audio != null else -999.0


func is_playing() -> bool:
	return _audio != null and _audio.playing


func distance_to(player: Node3D) -> float:
	return global_position.distance_to(player.global_position)
