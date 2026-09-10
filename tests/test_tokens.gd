extends Node

## F-002 auto-test: proximity sound tokens wiring, headless.
## Run:  godot --headless --path . res://tests/test_tokens.tscn
## Exit code 0 = all checks passed.

var failures := 0

const CORNERS := [
	Vector3(10, 0, -10), Vector3(-10, 0, -10),
	Vector3(10, 0, 10), Vector3(-10, 0, 10),
]


func _ready() -> void:
	await _run()
	print("[test] %s (%d fail)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _run() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 30:
		await get_tree().physics_frame

	var tokens := get_tree().get_nodes_in_group("sound_tokens")
	_check(tokens.size() == 4, "4 tokens in the sound_tokens group (%d)" % tokens.size())

	var positions := {}
	var streams := {}
	for t in tokens:
		var token := t as Node3D
		positions[token.global_position] = true
		var audio := token.get_node_or_null("Sound") as AudioStreamPlayer
		_check(audio != null and audio.stream != null, "%s has a 2D player + stream" % token.name)
		var looping := false
		if audio.stream is AudioStreamWAV:
			looping = audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		elif audio.stream is AudioStreamMP3:
			looping = audio.stream.loop
		_check(looping, "%s stream loops" % token.name)
		_check(audio.bus == "Master", "%s sits directly on the Master bus" % token.name)
		_check(audio.playing, "%s is playing from scene load" % token.name)
		streams[audio.stream.resource_path] = true
	_check(streams.size() >= 1, "tokens carry audio streams (%d)" % streams.size())

	var all_corners := true
	for c in CORNERS:
		if not positions.has(c):
			all_corners = false
	_check(all_corners, "tokens cover the four room corners")

# Range semantics with the player-mounted listener: tokens ALWAYS play and
# only their volume tracks the distance (near ~= BASE_DB, far == FLOOR_DB).
	var player := main.get_node("Player") as CharacterBody3D
	var near_token := tokens[0] as Node3D
	var near_audio := near_token.get_node_or_null("Sound") as AudioStreamPlayer
	player.global_position = near_token.global_position + Vector3(0.5, 0, 0.5)
	player.velocity = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame
	var near_vdb := near_audio.volume_db

	player.global_position = Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	for i in 10:
		await get_tree().physics_frame
	var far_vdb := near_audio.volume_db

	_check(near_vdb > 0.0, "volume at the token is full (%+.1f dB)" % near_vdb)
	_check(far_vdb <= -18.0, "volume mid-room drops well below full (%+.1f dB)" % far_vdb)
	_check(near_vdb - far_vdb > 20.0,
		"distance gradient is audible (%.1f dB swing)" % (near_vdb - far_vdb))

	# The 3D audio listener must ride the PLAYER, not the camera: the iso
	# camera hovers ~11 m away, so a camera-mounted listener keeps every token
	# beyond the 9 m cutoff and mutes the whole mechanic (real F-002 bug).
	var listeners: Array[AudioListener3D] = []
	for l in main.find_children("*", "AudioListener3D", true, false):
		if (l as AudioListener3D).is_current():
			listeners.append(l as AudioListener3D)
	_check(listeners.size() == 1
		and listeners[0].get_parent() is CharacterBody3D,
		"one current AudioListener3D mounted on the player (%d found)" % listeners.size())


func _check(ok: bool, what: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1
