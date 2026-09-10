extends CanvasLayer

## F-002 DIAGNOSTIC (remove before shipping F-002): on-screen audio state +
## a background log line every 2 s (visible in the Godot console on desktop
## and the browser console on web). Every automated "PASS" so far asserted
## wiring, not audible output — this log is the ground truth the tester and
## the agent read together: per-token volume we SET, playing flag, and the
## Master bus peak meters.

var _label: Label
var _log_timer := 0.0


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1, 0.45, 0.3))
	add_child(_label)


func _process(delta: float) -> void:
	var tokens := get_tree().get_nodes_in_group("sound_tokens")
	var listener := get_viewport().get_audio_listener_3d()
	var pos: Vector3 = listener.global_position if listener != null else Vector3.INF
	var l := AudioServer.get_bus_peak_volume_left_db(0, 0)
	var r := AudioServer.get_bus_peak_volume_right_db(0, 0)

	var nearest_d := 999.0
	var nearest_name := "-"
	var nearest_vdb := -999.0
	var nearest_playing := false
	var summary := ""
	for t in tokens:
		var token := t as Node3D
		var d: float = pos.distance_to(token.global_position) if listener != null else 999.0
		var script := token as Object
		var vdb: float = script.call("volume_db") if script.has_method("volume_db") else -999.0
		var playing: bool = script.call("is_playing") if script.has_method("is_playing") else false
		summary += "%s d=%.1f v=%+.0f %s | " % [token.name, d, vdb, "P" if playing else "-"]
		if d < nearest_d:
			nearest_d = d
			nearest_name = String(token.name)
			nearest_vdb = vdb
			nearest_playing = playing

	_label.text = "peak %0.0f/%0.0f dB | %s @ %.1f m vol %+.0f dB %s" % [
		l, r, nearest_name, nearest_d, nearest_vdb, "P" if nearest_playing else "-"]

	_log_timer += delta
	if _log_timer >= 2.0:
		_log_timer = 0.0
		print("[audio] peak %0.0f/%0.0f | %s" % [l, r, summary])
