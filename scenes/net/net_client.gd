extends Node

## NetClient (F-003): one websocket connection to the room server.
##
## Identity rule (what the party game is built on): the player id persists
## in the BROWSER's localStorage — different browsers are different players;
## the server takes over the character when a newer tab of the same browser
## joins (we then see close code 4001).

signal state_changed(connected: bool, detail: String)

const DEFAULT_URL := "ws://127.0.0.1:8765"   # localhost may resolve ::1 in
                                             # browsers; server binds IPv4
const SEND_HZ := 12.0

signal player_state(id: String, name: String, x: float, z: float, ry: float, moving: bool)
signal player_left(id: String)

var player_id := ""
var player_name := ""
var connected := false

var _ws := WebSocketPeer.new()
var _send_accum := 0.0
var _own_state := {}


func _ready() -> void:
	player_id = _load_identity()
	player_name = _load_name()
	if player_name.is_empty():
		player_name = "P-" + player_id.substr(0, 4)


func apply_name(new_name: String) -> void:
	"""Set + persist the display name (per browser, like the identity)."""
	new_name = new_name.strip_edges().substr(0, 16)
	player_name = new_name if not new_name.is_empty() else "P-" + player_id.substr(0, 4)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('cit_player_name'," + JSON.stringify(player_name) + ")")
	else:
		var f := FileAccess.open("user://player_name.txt", FileAccess.WRITE)
		if f != null:
			f.store_string(player_name)


func _load_name() -> String:
	if OS.has_feature("web"):
		var n = JavaScriptBridge.eval("localStorage.getItem('cit_player_name') || ''")
		if n is String:
			return String(n)
	var path := "user://player_name.txt"
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path).strip_edges()
	return ""


func connect_to(url: String) -> void:
	if url.is_empty():
		url = DEFAULT_URL
	var err := _ws.connect_to_url(url)
	if err != OK:
		state_changed.emit(false, "URL không hợp lệ (%d)" % err)
		return
	# poll() in _process completes the handshake; state_changed fires on OPEN.


func disconnect_me() -> void:
	if connected or _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close(1000, "bye")


func _process(delta: float) -> void:
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not connected:
				connected = true
				_send({"t": "join", "id": player_id, "name": player_name})
				state_changed.emit(true, "đã kết nối — %s" % player_name)
			while _ws.get_available_packet_count() > 0:
				var raw := _ws.get_packet().get_string_from_utf8()
				var msg = JSON.parse_string(raw)
				if msg is Dictionary:
					_handle(msg)
			_send_accum += delta
			if _send_accum >= 1.0 / SEND_HZ and not _own_state.is_empty():
				_send_accum = 0.0
				var d := _own_state.duplicate()
				d["t"] = "state"
				_send(d)
		WebSocketPeer.STATE_CLOSED:
			if connected:
				connected = false
				var code := _ws.get_close_code()
				var detail := "mất kết nối (mã %s)" % str(code)
				if code == 4001:
					detail = "tab mới của trình duyệt này đã tiếp quản nhân vật"
				state_changed.emit(false, detail)


func set_own_state(x: float, z: float, ry: float, moving: bool) -> void:
	_own_state = {"x": x, "z": z, "ry": ry, "moving": moving}


func _send(dict: Dictionary) -> void:
	_ws.send_text(JSON.stringify(dict))


func _handle(msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"world":
			for p in msg.get("players", []):
				if String(p.get("id", "")) != player_id:
					player_state.emit(String(p["id"]), String(p.get("name", "?")),
						float(p["x"]), float(p["z"]),
						float(p["ry"]), bool(p["moving"]))
		"bye":
			player_left.emit(String(msg.get("id", "")))


func _load_identity() -> String:
	# Web: localStorage — shared by every tab of ONE browser, distinct per
	# browser. Exactly the identity granularity the tester asked for.
	if OS.has_feature("web"):
		var id = JavaScriptBridge.eval(
			"(function(){var v=localStorage.getItem('cit_player_id');" +
			"if(!v){v=(crypto.randomUUID?crypto.randomUUID().replace(/-/g,'').slice(0,16)" +
			":Math.random().toString(16).slice(2,18));localStorage.setItem('cit_player_id',v);}" +
			"return v;})()")
		if id is String and not String(id).is_empty():
			return String(id)
	# Desktop build: a file in user:// plays the same role.
	var path := "user://player_id.txt"
	if FileAccess.file_exists(path):
		var stored := FileAccess.get_file_as_string(path).strip_edges()
		if not stored.is_empty():
			return stored
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fresh := ""
	for i in 16:
		fresh += "%x" % rng.randi_range(0, 15)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(fresh)
	return fresh
