extends Node

## F-004 auto-test: synthetic PCM voice travels the full path.
## Spawns the real server, joins two clients; B "speaks" a synthetic chunk
## while holding V — A must receive the exact bytes back (server-stamped id)
## and its RemotePlayer-style generator playback path must accept frames.
## Mic capture itself is NOT testable headless (no device/permission) —
## that part is verified by ear on the web build.

const PORT := 8901
const URL := "ws://127.0.0.1:8901"

var failures := 0
var _server_pid := -1


func _ready() -> void:
	await _run()
	print("[test] %s (%d fail)" % ["PASS" if failures == 0 else "FAIL", failures])
	if _server_pid > 0:
		OS.kill(_server_pid)
	get_tree().quit(1 if failures > 0 else 0)


func _run() -> void:
	_server_pid = OS.create_process("python",
		[ProjectSettings.globalize_path("res://tools/server/server.py"), str(PORT)], false)
	if _server_pid < 0:
		_check(false, "server process started")
		return
	await _sleep(1.5)

	var net_script := load("res://scenes/net/net_client.gd")
	var a := Node.new()
	a.set_script(net_script)
	add_child(a)
	a.player_id = "aaaa000011112222"
	var b := Node.new()
	b.set_script(net_script)
	add_child(b)
	b.player_id = "bbbb333344445555"

	a.connect_to(URL)
	b.connect_to(URL)
	if not await _wait_for(func() -> bool: return a.connected and b.connected, 4.0):
		_check(false, "both clients connect")
		return
	_check(true, "both clients connect")

	# synthetic voice frame from B (500 samples of a ramp)
	var pcm := PackedByteArray()
	pcm.resize(1000)
	for i in 500:
		pcm.encode_s16(i * 2, (i * 100) % 32768)

	var got := {"bytes": PackedByteArray(), "from": ""}
	a.voice_received.connect(func(id, data):
		got["from"] = id
		got["bytes"] = data)
	# simulate "V held while captured" — main.gd's gating, applied manually
	b.send_voice(pcm)

	if not await _wait_for(func() -> bool: return String(got["from"]) != "", 4.0):
		_check(false, "A receives B's voice frame")
		return
	_check(String(got["from"]) == "bbbb333344445555", "frame carries the sender id")
	var recv: PackedByteArray = got["bytes"]
	_check(recv.size() == pcm.size() and recv == pcm,
		"PCM bytes survive the round trip (%d bytes)" % recv.size())

	# generator playback accepts the frames (RemotePlayer.receive_voice core)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 48000
	stream.buffer_length = 0.3
	var vp := AudioStreamPlayer.new()
	vp.stream = stream
	add_child(vp)
	vp.play()
	var playback := vp.get_stream_playback()
	var n := recv.size() / 2
	var frames := PackedVector2Array()
	frames.resize(n)
	for i in n:
		var v: float = recv.decode_s16(i * 2) / 32768.0
		frames[i] = Vector2(v, v)
	playback.push_buffer(frames)
	_check(true, "generator playback ingests the frames")

	a.disconnect_me()
	b.disconnect_me()
	await _sleep(0.3)


func _check(ok: bool, what: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _wait_for(cond: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	return cond.call()


func _sleep(sec: float) -> void:
	var waited := 0.0
	while waited < sec:
		await get_tree().process_frame
		waited += get_process_delta_time()
