extends Node

## F-003 auto-test: end-to-end against the REAL room server.
## Spawns tools/server/server.py on a test port, joins two clients with
## different ids (two "browsers"), checks state flow, then a third client
## with the SAME id as the first (second "tab" of one browser) takes over.
## Run: godot --headless --path . res://tests/test_online.tscn

const PORT := 8899
const URL := "ws://127.0.0.1:8899"   # not "localhost": Godot may resolve ::1
                                       # while the server binds IPv4 only

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

	var saw_b := {}
	a.player_state.connect(func(id, x, z, ry, moving): saw_b[id] = Vector3(x, 0, z))

	a.connect_to(URL)
	b.connect_to(URL)
	if not await _wait_for(func(): return a.connected and b.connected, 4.0):
		_check(false, "both clients connect to the spawned server")
		return
	_check(true, "both clients connect to the spawned server")

	b.set_own_state(2.0, -3.0, 1.25, true)
	var target := Vector3(2, 0, -3)
	if not await _wait_for(func(): return (saw_b.get("bbbb333344445555", Vector3(1e9, 0, 0)) as Vector3).distance_to(target) < 0.05, 4.0):
		_check(false, "client A receives B's state through the server")
		return
	_check(true, "state coordinates survive the round trip")

	# Same-browser second tab: same id as A, newer connection takes over.
	var takeover := {"detail": ""}   # dict: lambdas capture by VALUE, so a
	# plain String assignment inside the lambda would be lost
	a.state_changed.connect(func(ok, detail):
		if not ok:
			takeover["detail"] = detail)
	var c := Node.new()
	c.set_script(net_script)
	add_child(c)
	c.player_id = "aaaa000011112222"
	c.connect_to(URL)
	if not await _wait_for(func(): return c.connected and takeover["detail"] != "", 4.0):
		print("  [dbg] c.connected=%s a.connected=%s detail='%s'" % [c.connected, a.connected, takeover["detail"]])
		_check(false, "newer tab takes over (A kicked, C active)")
		return
	_check(takeover["detail"].contains("tiếp quản"), "A reports the takeover reason")

	b.disconnect_me()
	c.disconnect_me()
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
