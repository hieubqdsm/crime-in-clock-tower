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
		var audio := token.get_node("Sound") as AudioStreamPlayer3D
		_check(audio.stream != null, "%s has a stream" % token.name)
		_check(audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"%s stream loops (loop_mode=%d)" % [token.name, audio.stream.loop_mode])
		_check(audio.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
			and audio.max_distance > 5.0,
			"%s distance attenuation configured" % token.name)
		streams[audio.stream.resource_path] = true
	_check(streams.size() == 4, "4 distinct sounds among tokens (%d)" % streams.size())

	var all_corners := true
	for c in CORNERS:
		if not positions.has(c):
			all_corners = false
	_check(all_corners, "tokens cover the four room corners")

	# Range semantics (out-of-range deactivation, in-range activation) cannot
	# be asserted here: the headless build runs the Dummy audio driver, where
	# AudioStreamPlayer3D.playing does not reflect the real activation logic.
	# That part is verified on the WEB build (real audio driver) via the
	# player telemetry: walk to a corner and watch `near`/`aud` in gameState.


func _check(ok: bool, what: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1
