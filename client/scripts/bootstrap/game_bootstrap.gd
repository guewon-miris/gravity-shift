extends Node2D
## Renders the 2D board (floor, doors, hazards, buttons, blocks, players) from server state.

@export var player_scene: PackedScene
@export var block_scene: PackedScene

@onready var floor_root: Node2D = $FloorRoot
@onready var hazards_root: Node2D = $HazardsRoot
@onready var doors_root: Node2D = $DoorsRoot
@onready var buttons_root: Node2D = $ButtonsRoot
@onready var blocks_root: Node2D = $BlocksRoot
@onready var players_root: Node2D = $PlayersRoot
@onready var camera: PlayerCamera = $PlayerCamera
@onready var hud_label: Label = $HUD/StageLabel
@onready var room_label: Label = $HUD/RoomLabel
@onready var cleared_panel: Panel = $HUD/ClearedPanel
@onready var cleared_label: Label = $HUD/ClearedPanel/Label
@onready var chat_log: RichTextLabel = $HUD/ChatPanel/VBox/ChatLog
@onready var chat_input: LineEdit = $HUD/ChatPanel/VBox/ChatInput
@onready var leave_btn: Button = $HUD/LeaveBtn

var local_pid: int = -1
var grid_w: int = 8
var grid_h: int = 8

var players: Dictionary = {}   # pid -> PlayerNode
var blocks: Dictionary = {}    # bid -> BlockNode
var buttons: Dictionary = {}   # "x,y" -> Polygon2D

func _ready() -> void:
	cleared_panel.visible = false
	NetClient.room_joined.connect(_on_room_joined)
	NetClient.room_created.connect(_on_room_created)
	NetClient.state.connect(_on_state)
	NetClient.stage_started.connect(_on_stage_started)
	NetClient.stage_cleared.connect(_on_stage_cleared)
	NetClient.player_left.connect(_on_player_left)
	NetClient.room_closed.connect(_on_room_closed)
	NetClient.chat_msg.connect(_on_chat_msg)
	chat_input.text_submitted.connect(_on_chat_submitted)
	leave_btn.pressed.connect(_on_leave)

	if Bootstrap.pending_state.size() > 0:
		_apply_room_meta(Bootstrap.pending_room_name, Bootstrap.pending_password)
		local_pid = Bootstrap.pending_you.get("pid", -1)
		_apply_state_full(Bootstrap.pending_state)
		Bootstrap.consume()

func _on_room_created(_name: String, _password: String, state: Dictionary, you: Dictionary) -> void:
	local_pid = you.get("pid", -1)
	_apply_state_full(state)

func _on_room_joined(_name: String, state: Dictionary, you: Dictionary) -> void:
	local_pid = you.get("pid", -1)
	_apply_state_full(state)

func _on_stage_started(state: Dictionary) -> void:
	cleared_panel.visible = false
	_apply_state_full(state)

func _apply_room_meta(room_name: String, password: String) -> void:
	if room_name == "":
		room_label.text = ""
	elif password == "":
		room_label.text = "Room: %s" % room_name
	else:
		room_label.text = "Room: %s    Password: %s    (share with friends)" % [room_name, password]

func _apply_state_full(state: Dictionary) -> void:
	grid_w = state.get("grid_w", 8)
	grid_h = state.get("grid_h", 8)
	_update_hud(state)
	_build_floor()
	_build_doors(state.get("doors", []))
	_build_hazards(state.get("hazards", []))
	_clear_buttons()
	camera.frame_board(grid_w, grid_h)
	_on_dynamic(state)

func _update_hud(state: Dictionary) -> void:
	var label: String = state.get("label", str(state.get("stage_id", 0)))
	var have := int(state.get("players", []).size())
	var need := int(state.get("required_players", 0))
	if state.get("started", false):
		hud_label.text = "Stage %s — %s" % [label, state.get("stage_name", "")]
	else:
		hud_label.text = "Stage %s — %s    waiting %d/%d" % [label, state.get("stage_name", ""), have, need]

func _on_stage_cleared(stage_id: int, stage_name: String) -> void:
	cleared_label.text = "Cleared!\n%s" % stage_name
	cleared_panel.visible = true

func _on_state(payload: Dictionary) -> void:
	_on_dynamic(payload)

func _on_dynamic(payload: Dictionary) -> void:
	_sync_players(payload.get("players", []))
	_sync_blocks(payload.get("blocks", []))
	_sync_buttons(payload.get("buttons", []))

# ---- static geometry ----

func _square(side: float) -> PackedVector2Array:
	var h := side * 0.5
	return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])

func _build_floor() -> void:
	for c in floor_root.get_children(): c.queue_free()
	var spr := Sprite2D.new()
	spr.texture = CheckerTexture.make_board(grid_w, grid_h,
		Color(0.85, 0.85, 0.85), Color(0.55, 0.55, 0.55), 8)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cs := GameConstants.CELL_PX
	spr.scale = Vector2(cs / 8.0, cs / 8.0)
	spr.position = Vector2((grid_w - 1) * cs * 0.5, -(grid_h - 1) * cs * 0.5)
	floor_root.add_child(spr)

func _build_doors(server_doors: Array) -> void:
	for c in doors_root.get_children(): c.queue_free()
	for raw in server_doors:
		var color: int = raw.get("color", 0)
		var cell: Array = raw.get("cell", [0, 0])
		var frame := Polygon2D.new()
		frame.polygon = _square(GameConstants.CELL_PX * 0.78)
		frame.color = Color(0.1, 0.1, 0.1)
		frame.position = GameConstants.cell_to_world(int(cell[0]), int(cell[1]))
		frame.z_index = 2
		var inner := Polygon2D.new()
		inner.polygon = _square(GameConstants.CELL_PX * 0.6)
		inner.color = GameConstants.COLOR_PRIMARY[color]
		frame.add_child(inner)
		doors_root.add_child(frame)

func _build_hazards(server_hazards: Array) -> void:
	for c in hazards_root.get_children(): c.queue_free()
	for raw in server_hazards:
		var kind: String = raw.get("kind", "spike")
		var cell: Array = raw.get("cell", [0, 0])
		var poly := Polygon2D.new()
		poly.polygon = _square(GameConstants.CELL_PX * 0.9)
		poly.color = GameConstants.HAZARD_COLORS.get(kind, Color(0.8, 0.1, 0.1))
		poly.position = GameConstants.cell_to_world(int(cell[0]), int(cell[1]))
		poly.z_index = 1
		hazards_root.add_child(poly)

# ---- dynamic entities ----

func _sync_players(server_players: Array) -> void:
	var seen: Dictionary = {}
	for raw in server_players:
		var pid: int = raw.get("pid", -1)
		var cell_arr: Array = raw.get("cell", [0, 0])
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		var color: int = raw.get("color", 0)
		var gravity: int = raw.get("gravity", 0)
		var pname: String = raw.get("name", "")
		seen[pid] = true
		var node: PlayerNode = players.get(pid)
		if node == null:
			node = player_scene.instantiate()
			players_root.add_child(node)
			node.setup(pid, color, cell, pid == local_pid, pname)
			players[pid] = node
		node.apply_state(cell, gravity)
	for pid in players.keys():
		if not seen.has(pid):
			players[pid].queue_free()
			players.erase(pid)

func _sync_blocks(server_blocks: Array) -> void:
	var seen: Dictionary = {}
	for raw in server_blocks:
		var bid: int = raw.get("bid", -1)
		var cell_arr: Array = raw.get("cell", [0, 0])
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		var color: int = raw.get("color", 0)
		seen[bid] = true
		var node: BlockNode = blocks.get(bid)
		if node == null:
			node = block_scene.instantiate()
			blocks_root.add_child(node)
			node.setup(bid, color, cell)
			blocks[bid] = node
		node.apply_state(cell)
	for bid in blocks.keys():
		if not seen.has(bid):
			blocks[bid].queue_free()
			blocks.erase(bid)

func _clear_buttons() -> void:
	for c in buttons_root.get_children(): c.queue_free()
	buttons.clear()

func _sync_buttons(server_buttons: Array) -> void:
	for raw in server_buttons:
		var color: int = raw.get("color", 0)
		var cell_arr: Array = raw.get("cell", [0, 0])
		var pressed: bool = raw.get("pressed", false)
		var key := "%d,%d" % [int(cell_arr[0]), int(cell_arr[1])]
		var poly: Polygon2D = buttons.get(key)
		if poly == null:
			poly = Polygon2D.new()
			poly.polygon = _square(GameConstants.CELL_PX * 0.5)
			poly.position = GameConstants.cell_to_world(int(cell_arr[0]), int(cell_arr[1]))
			poly.z_index = 3
			buttons_root.add_child(poly)
			buttons[key] = poly
		var base: Color = GameConstants.COLOR_PRIMARY[color]
		poly.color = base if pressed else base.darkened(0.55)

func _on_chat_msg(_pid: int, name: String, text: String) -> void:
	text = text.replace("[", "[lb]")  # neutralize BBCode from user input
	chat_log.append_text("[b]%s[/b]: %s\n" % [name, text])

func _on_chat_submitted(text: String) -> void:
	text = text.strip_edges()
	if text != "":
		NetClient.chat(text)
	chat_input.clear()
	chat_input.release_focus()

func _on_player_left(pid: int) -> void:
	if players.has(pid):
		players[pid].queue_free()
		players.erase(pid)

func _on_leave() -> void:
	NetClient.leave_room()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_room_closed(_reason: String) -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
