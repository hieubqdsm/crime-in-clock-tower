extends CanvasLayer

## Options UI (F-003): press O to toggle. Holds the server URL field and
## connect button. While typing in the URL field the local player ignores
## movement keys (player.gd checks for a focused LineEdit).

signal connect_requested(url: String, player_name: String)
signal mic_toggle_requested

const DEFAULT_URL := "ws://127.0.0.1:8765"   # not localhost: webviews may
                                             # resolve ::1 while the room
                                             # server binds IPv4 only

@onready var _url_edit: LineEdit = $Panel/VBox/UrlEdit
@onready var _name_edit: LineEdit = $Panel/VBox/NameEdit
@onready var _hint: Label = $Hint
@onready var _mic_btn: Button = $Panel/VBox/MicBtn
@onready var _status: Label = $Panel/VBox/Status


func _ready() -> void:
	hide()
	_url_edit.text = DEFAULT_URL


func set_known_name(name: String) -> void:
	_name_edit.text = name


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_O:
			_open(not visible)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and visible:
			_open(false)
			get_viewport().set_input_as_handled()


func _open(v: bool) -> void:
	visible = v
	_hint.visible = not v
	if not v:
		get_viewport().gui_release_focus()


func set_mic_status(ok: bool) -> void:
	_mic_btn.text = "🎤 Micro: ĐANG BẬT" if ok else "🎤 Bật micro"
	_mic_btn.disabled = false


func set_status(text: String, ok: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.6, 0.5))


func _on_mic_pressed() -> void:
	_mic_btn.disabled = true
	_mic_btn.text = "đang xin quyền micro…"
	mic_toggle_requested.emit()


func _on_connect_pressed() -> void:
	connect_requested.emit(_url_edit.text.strip_edges(), _name_edit.text)
	set_status("đang kết nối…", false)
