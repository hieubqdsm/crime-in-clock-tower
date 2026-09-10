extends Node

## VoiceCapture (F-004): microphone → 16 kHz-ish mono PCM chunks on the
## websocket while push-to-talk (V) is held.
##
## Capture chain: an AudioStreamPlayer fed by AudioStreamMicrophone plays on
## the dedicated "MicCapture" bus (volume −80 dB, so you never hear
## yourself). That bus carries an AudioEffectCapture; every 100 ms we drain
## its frames and ship them as one binary websocket frame. The project mix
## rate resamples nothing — we send whatever the engine hands us (mono mix,
## 48 kHz by default; remote playback uses a generator at the same rate).

const CHUNK_SEC := 0.1
const MIX_RATE := 48000.0   # must match the project audio mix rate

signal captured(pcm: PackedByteArray)

var _mic_player: AudioStreamPlayer
var _capture_effect: AudioEffectCapture
var _accum := 0.0
var _enabled := false


func enable() -> bool:
	# Idempotent; returns success. On web the browser permission prompt
	# appears when the microphone stream starts.
	if _enabled:
		return true
	var bus_idx := _ensure_bus()
	if bus_idx < 0:
		return false
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = AudioServer.get_bus_name(bus_idx)
	add_child(_mic_player)
	_mic_player.play()
	_enabled = true
	return true


func is_enabled() -> bool:
	return _enabled


func _ensure_bus() -> int:
	const BUS := "MicCapture"
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == BUS:
			return i
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, -80.0)   # never hear yourself
	_capture_effect = AudioEffectCapture.new()
	_capture_effect.buffer_length = 1.0
	AudioServer.add_bus_effect(idx, _capture_effect)
	return idx


func _process(delta: float) -> void:
	if not _enabled or _capture_effect == null:
		return
	_accum += delta
	if _accum < CHUNK_SEC:
		return
	_accum = 0.0
	var frames := _capture_effect.get_frames_available()
	if frames <= 0:
		return
	var stereo: PackedVector2Array = _capture_effect.get_frames(frames)
	# Bus frames are Stereo PCM floats; mono-mix into 16-bit LE.
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	for i in frames:
		var mono: float = (stereo[i].x + stereo[i].y) * 0.5
		var v := int(clampf(mono, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, v)
	captured.emit(pcm)
