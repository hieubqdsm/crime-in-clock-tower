extends CanvasLayer

## Options UI: gear button (top-right, always visible) or the O key opens
## the settings panel — name, server URL, mic, connect/DISCONNECT (the
## connect button flips once connected).

signal connect_requested(url: String, player_name: String)
signal disconnect_requested
signal mic_toggle_requested

const DEFAULT_URL := "ws://127.0.0.1:8765"   # not localhost: webviews may
                                             # resolve ::1 while the room
                                             # server binds IPv4 only

@onready var _gear: Button = $GearBtn
@onready var _panel: PanelContainer = $Panel
@onready var _url_edit: LineEdit = $Panel/VBox/UrlEdit
@onready var _name_edit: LineEdit = $Panel/VBox/NameEdit
@onready var _mic_btn: Button = $Panel/VBox/MicBtn
@onready var _connect_btn: Button = $Panel/VBox/ConnectBtn
@onready var _status: Label = $Panel/VBox/Status

var _connected := false


func _ready() -> void:
	# NEVER hide the CanvasLayer itself — that would hide the gear button
	# too (it is a direct child). Only the panel toggles.
	_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_O:
			_open(not is_open())
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and visible:
			_open(false)
			get_viewport().set_input_as_handled()


func _open(v: bool) -> void:
	_panel.visible = v
	if not v:
		get_viewport().gui_release_focus()


func is_open() -> bool:
	return _panel.visible


func set_known_name(name: String) -> void:
	_name_edit.text = name


func set_connected(ok: bool) -> void:
	_connected = ok
	_connect_btn.text = "Ngắt kết nối" if ok else "Kết nối"


func set_mic_status(ok: bool) -> void:
	_mic_btn.text = "🎤 Micro: ĐANG BẬT" if ok else "🎤 Bật micro  (nói: giữ V)"
	_mic_btn.disabled = false


func set_status(text: String, ok: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.6, 0.5))


func _on_gear_pressed() -> void:
	_open(not is_open())


func _on_mic_pressed() -> void:
	_mic_btn.disabled = true
	_mic_btn.text = "đang xin quyền micro…"
	mic_toggle_requested.emit()


func _on_connect_pressed() -> void:
	if _connected:
		disconnect_requested.emit()
	else:
		connect_requested.emit(_url_edit.text.strip_edges(), _name_edit.text)
		set_status("đang kết nối…", false)
