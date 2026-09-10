extends CanvasLayer

## F-002 DIAGNOSTIC HUD (remove before shipping F-002): shows the live
## Master-bus peak meters and the nearest token's playback state, so silence
## can be localized to "engine not mixing" vs "OS/app muted" on ANY platform,
## including editor runs where there is no browser console.

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1, 0.45, 0.3))
	add_child(_label)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var pos := cam.global_position if cam != null else Vector3.ZERO
	var nearest_d := 999.0
	var nearest_name := "-"
	var nearest_playing := false
	for t in get_tree().get_nodes_in_group("sound_tokens"):
		var token := t as Node3D
		var d := pos.distance_to(token.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest_name = String(token.name)
			var audio := token.get_node_or_null("Sound") as AudioStreamPlayer3D
			nearest_playing = audio != null and audio.playing
	var l := AudioServer.get_bus_peak_volume_left_db(0, 0)
	var r := AudioServer.get_bus_peak_volume_right_db(0, 0)
	_label.text = "Master peak %0.0f / %0.0f dB   |   %s dist %0.1f m   playing %s" % [
		l, r, nearest_name, nearest_d, str(nearest_playing)]
