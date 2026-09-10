extends Node3D

## Main orchestrator (F-003): wires Net <-> RemotePlayers <-> local Player.
## Call down / signal up: Net emits per-player states, Main manages the
## remote mannequin instances and reports the local player's state.

const REMOTE_SCENE := preload("res://scenes/net/RemotePlayer.tscn")

@onready var _net: Node = $Net
@onready var _player: CharacterBody3D = $Player
@onready var _remotes: Node3D = $Remotes
@onready var _options: CanvasLayer = $OptionsUI

var _remote_players := {}


func _ready() -> void:
	_options.set_known_name(_net.player_name)
	_set_own_name(_net.player_name)
	_net.state_changed.connect(_on_net_state)
	_net.player_state.connect(_on_player_state)
	_net.player_left.connect(_on_player_left)
	_options.connect_requested.connect(_on_connect_requested)


func _process(_delta: float) -> void:
	if _net.connected:
		var model := _player.get_node("Mannequin") as Node3D
		var moving := Vector2(_player.velocity.x, _player.velocity.z).length() > 0.3
		_net.set_own_state(_player.global_position.x, _player.global_position.z,
			model.rotation.y, moving)
	if OS.has_feature("web") and Engine.get_process_frames() % 10 == 0:
		# str(false) is "False" (capital) — not valid JS; lowercase it.
		var btn := _options.get_node_or_null("Panel/VBox/ConnectBtn") as Control
		var btn_rect := btn.get_global_rect() if btn != null else Rect2()
		JavaScriptBridge.eval("window.netState={conn:%s,opts:%s,remotes:%d,btn:[%d,%d,%d,%d]}"
			% [str(_net.connected).to_lower(), str(_options.visible).to_lower(),
				_remote_players.size(), btn_rect.position.x, btn_rect.position.y,
				btn_rect.size.x, btn_rect.size.y])


func _on_connect_requested(url: String, player_name: String) -> void:
	_net.apply_name(player_name)
	_set_own_name(_net.player_name)
	_net.connect_to(url)


func _on_net_state(ok: bool, detail: String) -> void:
	_options.set_status(detail, ok)
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
		_remotes.add_child(rp)
		_remote_players[id] = rp
	_remote_players[id].apply_state(x, z, ry, moving)
	(_remote_players[id].get_node("NameLabel") as Label3D).text = pname


func _on_player_left(id: String) -> void:
	if _remote_players.has(id):
		_remote_players[id].queue_free()
		_remote_players.erase(id)
