extends Node3D

## Main orchestrator (F-003): wires Net <-> RemotePlayers <-> local Player.
## Call down / signal up: Net emits per-player states, Main manages the
## remote mannequin instances and reports the local player's state.

const REMOTE_SCENE := preload("res://scenes/net/RemotePlayer.tscn")

@onready var _net: Node = $Net
@onready var _player: CharacterBody3D = $Player
@onready var _remotes: Node3D = $Remotes
@onready var _options: CanvasLayer = $OptionsUI
@onready var _voice = $VoiceCapture   # untyped: signal access is dynamic

var _remote_players := {}
var _dbg: Label


func _make_dbg_strip() -> void:
	# F-004 diagnostics (remove when voice is trusted): mic input level,
	# voice frames sent/received, nearest token volume.
	_dbg = Label.new()
	_dbg.position = Vector2(12, 690)
	_dbg.add_theme_font_size_override("font_size", 16)
	_dbg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	add_child(_dbg)


func _ready() -> void:
	_options.set_known_name(_net.player_name)
	_make_dbg_strip()
	_set_own_name(_net.player_name)
	_net.state_changed.connect(_on_net_state)
	_net.player_state.connect(_on_player_state)
	_net.player_left.connect(_on_player_left)
	_net.voice_received.connect(_on_voice_received)
	_voice.captured.connect(_on_voice_captured)
	_options.connect_requested.connect(_on_connect_requested)
	_options.mic_toggle_requested.connect(_on_mic_toggle)
	_options.disconnect_requested.connect(_on_disconnect)


func _process(_delta: float) -> void:
	if _net.connected:
		var model := _player.get_node("Mannequin") as Node3D
		var moving := Vector2(_player.velocity.x, _player.velocity.z).length() > 0.3
		_net.set_own_state(_player.global_position.x, _player.global_position.z,
			model.rotation.y, moving)
	if Engine.get_process_frames() % 10 == 0:
		var near_vol := -999.0
		for t in get_tree().get_nodes_in_group("sound_tokens"):
			if t.has_method("volume_db"):
				near_vol = maxf(near_vol, t.volume_db())
		if _dbg != null:
			_dbg.text = "🎤 %d%%  ↑%d ↓%d  ♪ %+.0f dB" % [
				int(_voice.last_level * 100.0) if _voice != null else 0,
				_net.voice_sent, _net.voice_recv, near_vol]
	if OS.has_feature("web") and Engine.get_process_frames() % 10 == 0:
		# str(false) is "False" (capital) — not valid JS; lowercase it.
		var btn := _options.get_node_or_null("Panel/VBox/ConnectBtn") as Control
		var btn_rect := btn.get_global_rect() if btn != null else Rect2()
		var gear := _options.get_node_or_null("GearBtn") as Control
		var gear_rect := gear.get_global_rect() if gear != null else Rect2()
		JavaScriptBridge.eval("window.netState={conn:%s,opts:%s,remotes:%d,btn:[%d,%d,%d,%d],gear:[%d,%d,%d,%d]}"
			% [str(_net.connected).to_lower(), _options.is_open(),
				_remote_players.size(), btn_rect.position.x, btn_rect.position.y,
				btn_rect.size.x, btn_rect.size.y,
				gear_rect.position.x, gear_rect.position.y, gear_rect.size.x, gear_rect.size.y])


func _on_disconnect() -> void:
	_net.disconnect_me()


func _on_connect_requested(url: String, player_name: String) -> void:
	_net.apply_name(player_name)
	_set_own_name(_net.player_name)
	_net.connect_to(url)


func _on_net_state(ok: bool, detail: String) -> void:
	_options.set_status(detail, ok)
	_options.set_connected(ok)
	if not ok:
		for id in _remote_players:
			_remote_players[id].queue_free()
		_remote_players.clear()


func _set_own_name(name: String) -> void:
	(_player.get_node("NameLabel") as Label3D).text = name


func _on_player_state(id: String, pname: String, x: float, z: float, ry: float, moving: bool) -> void:
	if not _remote_players.has(id):
		var rp := REMOTE_SCENE.instantiate()
		rp.setup(pname)
		rp.setup_voice()
		_remotes.add_child(rp)
		_remote_players[id] = rp
	_remote_players[id].apply_state(x, z, ry, moving)
	(_remote_players[id].get_node("NameLabel") as Label3D).text = pname


func _on_voice_captured(pcm: PackedByteArray) -> void:
	if _net.connected and Input.is_physical_key_pressed(KEY_V):
		_net.send_voice(pcm)


func _on_voice_received(id: String, pcm: PackedByteArray) -> void:
	if _remote_players.has(id):
		var listener := get_viewport().get_audio_listener_3d()
		var pos := listener.global_position if listener != null else Vector3.INF
		_remote_players[id].receive_voice(pcm, pos)


func _on_mic_toggle() -> void:
	var ok: bool = _voice.enable()
	_options.set_mic_status(ok)


func _on_player_left(id: String) -> void:
	if _remote_players.has(id):
		_remote_players[id].queue_free()
		_remote_players.erase(id)
