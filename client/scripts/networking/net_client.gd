extends Node
## Autoloaded singleton: WebSocket connection to the Python server.

signal connected
signal disconnected
signal name_ok(player_name: String, token: String)
signal name_failed(reason: String)
signal chat_msg(pid: int, name: String, text: String)
signal stages_list(stages: Array)
signal rooms_update(rooms: Array, count: int, max_rooms: int)
signal autocomplete_result(matches: Array)
signal room_created(name: String, password: String, state: Dictionary, you: Dictionary)
signal room_create_failed(reason: String)
signal room_joined(name: String, state: Dictionary, you: Dictionary)
signal room_join_failed(reason: String)
signal room_closed(reason: String)
signal player_joined(player: Dictionary)
signal player_left(pid: int)
signal state(payload: Dictionary)
signal stage_started(state: Dictionary)
signal stage_cleared(stage_id: int, stage_name: String)
signal server_error(reason: String)

var url: String = "ws://127.0.0.1:8765"
var _socket: WebSocketPeer = WebSocketPeer.new()
var _was_connected: bool = false
var _attempting: bool = false

func connect_to(server_url: String = "") -> void:
	if server_url != "":
		url = server_url
	var err := _socket.connect_to_url(url)
	if err != OK:
		push_error("WebSocket connect failed: %s" % err)
		emit_signal("disconnected")
		return
	_attempting = true

func disconnect_from() -> void:
	_socket.close()

func _process(_delta: float) -> void:
	_socket.poll()
	var state_now := _socket.get_ready_state()
	if state_now == WebSocketPeer.STATE_OPEN:
		_attempting = false
		if not _was_connected:
			_was_connected = true
			emit_signal("connected")
		while _socket.get_available_packet_count() > 0:
			var pkt := _socket.get_packet().get_string_from_utf8()
			_handle_message(pkt)
	elif state_now == WebSocketPeer.STATE_CLOSED:
		if _was_connected:
			_was_connected = false
			emit_signal("disconnected")
		elif _attempting:
			_attempting = false
			emit_signal("disconnected")  # connection attempt failed

func _send(msg: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(msg))

func claim_name(player_name: String, token: String = "") -> void:
	_send({"type": "claim_name", "name": player_name, "token": token})
func list_stages() -> void:                               _send({"type": "list_stages"})
func list_rooms() -> void:                                _send({"type": "list_rooms"})
func autocomplete(prefix: String) -> void:                _send({"type": "autocomplete", "prefix": prefix})
func create_room(name: String, stage_id: int, player_count: int = 2, campaign: bool = true) -> void:
	_send({"type": "create_room", "name": name, "stage_id": stage_id, "player_count": player_count, "campaign": campaign})
func join_room(name: String, password: String) -> void:   _send({"type": "join_room", "name": name, "password": password})
func leave_room() -> void:                                _send({"type": "leave_room"})
func move(step: Vector2i) -> void:                        _send({"type": "move", "step": [step.x, step.y]})
func interact() -> void:                                  _send({"type": "interact"})
func chat(text: String) -> void:                          _send({"type": "chat", "text": text})

func _handle_message(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var t: String = parsed.get("type", "")
	match t:
		"name_ok":               emit_signal("name_ok", parsed.get("name", ""), parsed.get("token", ""))
		"name_failed":           emit_signal("name_failed", parsed.get("reason", ""))
		"chat_msg":              emit_signal("chat_msg", parsed.get("pid", -1), parsed.get("name", ""), parsed.get("text", ""))
		"stages_list":           emit_signal("stages_list", parsed.get("stages", []))
		"rooms_update":          emit_signal("rooms_update", parsed.get("rooms", []), parsed.get("count", 0), parsed.get("max", 6))
		"autocomplete_result":   emit_signal("autocomplete_result", parsed.get("matches", []))
		"room_created":          emit_signal("room_created", parsed.get("name", ""), parsed.get("password", ""), parsed.get("state", {}), parsed.get("you", {}))
		"room_create_failed":    emit_signal("room_create_failed", parsed.get("reason", ""))
		"room_joined":           emit_signal("room_joined", parsed.get("name", ""), parsed.get("state", {}), parsed.get("you", {}))
		"room_join_failed":      emit_signal("room_join_failed", parsed.get("reason", ""))
		"room_closed":           emit_signal("room_closed", parsed.get("reason", ""))
		"player_joined":         emit_signal("player_joined", parsed.get("player", {}))
		"player_left":           emit_signal("player_left", parsed.get("pid", -1))
		"state":                 emit_signal("state", parsed)
		"stage_started":         emit_signal("stage_started", parsed)
		"stage_cleared":         emit_signal("stage_cleared", parsed.get("stage_id", 0), parsed.get("stage_name", ""))
		"error":                 emit_signal("server_error", parsed.get("reason", ""))
