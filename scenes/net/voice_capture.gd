extends Node

## VoiceCapture v2 (F-004): mic -> 16 kHz mono PCM chunks.
##
## WEB: Godot's AudioStreamMicrophone never even triggers the browser's
## permission prompt on this build (tester-verified), so web capture is done
## in plain JavaScript: getUserMedia -> ScriptProcessor -> downsample ->
## base64 chunks queued in window.__citMicQueue; this node polls the queue.
## The granted device's label is logged + exposed.
##
## DESKTOP: AudioStreamMicrophone on a silent MicCapture bus, downsampled
## 48k->16k here. Input device name logged via AudioServer.

signal captured(pcm: PackedByteArray)

const TARGET_RATE := 16000
const CHUNK_SEC := 0.1

var last_level := 0.0
var chunks := 0
var device_name := ""
var error := ""

var _enabled := false
var _mic_player: AudioStreamPlayer
var _capture_effect: AudioEffectCapture
var _accum := 0.0

const JS_BOOT := """
(async function(){
  if (window.__citMicReady) return 'already';
  window.__citMicReady = true;
  window.__citMicQueue = [];
  window.__micLabel = null;
  window.__micError = null;
  window.__micLevel = 0;
  try {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia)
      throw new Error('mediaDevices unavailable');
    const stream = await navigator.mediaDevices.getUserMedia({audio: {echoCancellation: true, noiseSuppression: true}});
    const track = stream.getAudioTracks()[0];
    window.__micDeviceId = track && track.getSettings ? (track.getSettings().deviceId || null) : null;
    window.__micLabel = track && track.label ? track.label : 'default microphone';
    try {
      const devs = await navigator.mediaDevices.enumerateDevices();
      window.__citMicList = devs.filter(d => d.kind === 'audioinput')
        .map(d => ({id: d.deviceId, label: d.label || ('micro ' + String(d.deviceId).slice(0, 8))}));
    } catch (e) { window.__citMicList = []; }
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    if (ctx.state === 'suspended') await ctx.resume();
    window.__micCtx = ctx;
    const src = ctx.createMediaStreamSource(stream);
    const proc = ctx.createScriptProcessor(4096, 1, 1);
    const RATE_IN = ctx.sampleRate, RATE_OUT = 16000, CHUNK = Math.floor(RATE_OUT * 0.1);
    let carry = [];
    proc.onaudioprocess = (e) => {
      const d = e.inputBuffer.getChannelData(0);
      for (let i = 0; i < d.length; i++) carry.push(d[i]);
      const need = Math.floor(RATE_IN * 0.1);
      while (carry.length >= need) {
        const seg = carry.splice(0, need);
        const pcm16 = new Int16Array(CHUNK);
        let sq = 0;
        for (let j = 0; j < CHUNK; j++) {
          const a = Math.floor(j * RATE_IN / RATE_OUT), b = Math.floor((j + 1) * RATE_IN / RATE_OUT);
          let s = 0, n = 0;
          for (let k = a; k < b; k++) { s += seg[k] || 0; n++; }
          const v = (n ? s / n : 0) * (window.__citGain || 3.0);
          sq += v * v;
          pcm16[j] = Math.max(-32768, Math.min(32767, Math.round(v * 32767)));
        }
        window.__micLevel = Math.min(1.0, Math.sqrt(sq / CHUNK));
        const bytes = new Uint8Array(pcm16.buffer);
        let bin = '';
        for (let q = 0; q < bytes.length; q++) bin += String.fromCharCode(bytes[q]);
        window.__citMicQueue.push(btoa(bin));
        if (window.__citMicQueue.length > 20) window.__citMicQueue.shift();
      }
    };
    const sink = ctx.createGain(); sink.gain.value = 0;
    src.connect(proc); proc.connect(sink); sink.connect(ctx.destination);
    return 'granted';
  } catch (err) {
    window.__micError = String(err && err.name ? err.name + ': ' + err.message : err);
    return 'denied';
  }
})()
"""


func list_devices() -> Array:
	## [{id, label}] on web after permission; [] before grant or on desktop.
	if not OS.has_feature("web"):
		return []
	var raw = JavaScriptBridge.eval(
		"(function(){ var l = window.__citMicList || []; return JSON.stringify(l); })()")
	var arr = JSON.parse_string(String(raw)) if raw is String else []
	return arr if arr is Array else []


func select_device(device_id: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("(function(){ window.__citGain = 3.0; window.__citMicQueue = []; })()")
	JavaScriptBridge.eval("""
(async function(){
  try {
    if (window.__citMicStop) { try { window.__citMicStop(); } catch (e) {} }
    const stream = await navigator.mediaDevices.getUserMedia({audio: {deviceId: {exact: '%s'}, echoCancellation: true, noiseSuppression: true}});
    const track = stream.getAudioTracks()[0];
    window.__micDeviceId = (track.getSettings ? track.getSettings().deviceId : null) || null;
    window.__micLabel = track.label || 'selected micro';
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    if (ctx.state === 'suspended') await ctx.resume();
    const src = ctx.createMediaStreamSource(stream);
    const proc = ctx.createScriptProcessor(4096, 1, 1);
    const RATE_IN = ctx.sampleRate, RATE_OUT = 16000, CHUNK = Math.floor(RATE_OUT * 0.1);
    let carry = [];
    proc.onaudioprocess = (e) => {
      const d = e.inputBuffer.getChannelData(0);
      for (let i = 0; i < d.length; i++) carry.push(d[i]);
      const need = Math.floor(RATE_IN * 0.1);
      while (carry.length >= need) {
        const seg = carry.splice(0, need);
        const pcm16 = new Int16Array(CHUNK);
        let sq = 0;
        for (let j = 0; j < CHUNK; j++) {
          const a = Math.floor(j * RATE_IN / RATE_OUT), b = Math.floor((j + 1) * RATE_IN / RATE_OUT);
          let s = 0, n = 0;
          for (let k = a; k < b; k++) { s += seg[k] || 0; n++; }
          const v = (n ? s / n : 0) * (window.__citGain || 3.0);
          sq += v * v;
          pcm16[j] = Math.max(-32768, Math.min(32767, Math.round(v * 32767)));
        }
        window.__micLevel = Math.min(1.0, Math.sqrt(sq / CHUNK));
        const bytes = new Uint8Array(pcm16.buffer);
        let bin = '';
        for (let q = 0; q < bytes.length; q++) bin += String.fromCharCode(bytes[q]);
        window.__citMicQueue.push(btoa(bin));
        if (window.__citMicQueue.length > 20) window.__citMicQueue.shift();
      }
    };
    const sink = ctx.createGain(); sink.gain.value = 0;
    src.connect(proc); proc.connect(sink); sink.connect(ctx.destination);
    window.__citMicStop = () => { try { proc.disconnect(); src.disconnect(); track.stop(); ctx.close(); } catch (e) {} };
  } catch (err) {
    window.__micError = String(err && err.name ? err.name + ': ' + err.message : err);
  }
})()
""" % device_id, true)
	device_name = ""
	print("[mic] switching to device: ", device_id)


func enable() -> bool:
	if _enabled:
		return true
	if OS.has_feature("web"):
		JavaScriptBridge.eval(JS_BOOT, true)
		_enabled = true
		print("[mic] web capture requested - waiting for permission...")
		return true
	return _enable_desktop()


func is_enabled() -> bool:
	return _enabled


func _enable_desktop() -> bool:
	const BUS := "MicCapture"
	var idx := -1
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == BUS:
			idx = i
			break
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, -80.0)
		_capture_effect = AudioEffectCapture.new()
		_capture_effect.buffer_length = 1.0
		AudioServer.add_bus_effect(idx, _capture_effect)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = AudioServer.get_bus_name(idx)
	add_child(_mic_player)
	_mic_player.play()
	_enabled = true
	device_name = AudioServer.get_input_device()
	print("[mic] desktop capture on device: ", device_name)
	return true


func _process(delta: float) -> void:
	if not _enabled:
		return
	if OS.has_feature("web"):
		_poll_web()
	else:
		_poll_desktop(delta)


func _poll_web() -> void:
	if error.is_empty():
		var err = JavaScriptBridge.eval("window.__micError ?? null")
		if err is String and not String(err).is_empty():
			error = String(err)
			print("[mic] PERMISSION/ERROR: ", error)
			push_error("[mic] " + error)
	if device_name.is_empty():
		var label = JavaScriptBridge.eval("window.__micLabel ?? null")
		if label is String and not String(label).is_empty():
			device_name = String(label)
			print("[mic] granted - device: ", device_name)
	var level = JavaScriptBridge.eval("window.__micLevel ?? 0")
	last_level = float(level) if (level is float or level is int) else 0.0
	var raw = JavaScriptBridge.eval(
		"(function(){ var q = window.__citMicQueue || []; window.__citMicQueue = []; return JSON.stringify(q); })()")
	if raw is String and String(raw) != "[]":
		var arr = JSON.parse_string(String(raw))
		if arr is Array:
			for b64 in arr:
				var pcm: PackedByteArray = Marshalls.base64_to_raw(String(b64))
				chunks += 1
				captured.emit(pcm)


func _poll_desktop(delta: float) -> void:
	if _capture_effect == null:
		return
	_accum += delta
	if _accum < CHUNK_SEC:
		return
	_accum = 0.0
	var frames := _capture_effect.get_frames_available()
	if frames <= 0:
		return
	var stereo: PackedVector2Array = _capture_effect.get_frames(frames)
	var out_n := frames / 3
	var pcm := PackedByteArray()
	pcm.resize(out_n * 2)
	var sum_sq := 0.0
	for i in out_n:
		var s := 0.0
		for k in 3:
			var f := stereo[i * 3 + k]
			s += (f.x + f.y) * 0.5
		var mono: float = s / 3.0
		sum_sq += mono * mono
		pcm.encode_s16(i * 2, int(clampf(mono, -1.0, 1.0) * 32767.0))
	last_level = sqrt(sum_sq / maxf(1.0, out_n))
	chunks += 1
	captured.emit(pcm)
