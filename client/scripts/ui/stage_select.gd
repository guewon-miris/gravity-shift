extends Control
## Two-panel screen: stage list (left), room browser for selected stage (right).

@onready var stages_list: ItemList = $Layout/StagesPanel/StagesList
@onready var stage_title: Label = $Layout/RoomsPanel/StageTitle
@onready var stage_info: Label = $Layout/RoomsPanel/StageInfo
@onready var room_name_input: LineEdit = $Layout/RoomsPanel/CreateBox/RoomName
@onready var create_btn: Button = $Layout/RoomsPanel/CreateBox/CreateBtn
@onready var generated_pw: Label = $Layout/RoomsPanel/GeneratedPw
@onready var room_count_label: Label = $Layout/RoomsPanel/RoomCount
@onready var rooms_list: ItemList = $Layout/RoomsPanel/RoomsList
@onready var join_pw_input: LineEdit = $Layout/RoomsPanel/JoinBox/JoinPw
@onready var join_btn: Button = $Layout/RoomsPanel/JoinBox/JoinBtn
@onready var status_label: Label = $Layout/RoomsPanel/StatusLabel

var _stages: Array = []
var _all_rooms: Array = []
var _selected_stage: Dictionary = {}
var _selected_room_name: String = ""
var _max_rooms: int = 6

func _ready() -> void:
	stages_list.item_selected.connect(_on_stage_selected)
	rooms_list.item_selected.connect(_on_room_selected)
	create_btn.pressed.connect(_on_create_pressed)
	join_btn.pressed.connect(_on_join_pressed)

	NetClient.stages_list.connect(_on_stages_list)
	NetClient.rooms_update.connect(_on_rooms_update)
	NetClient.room_created.connect(_on_room_created)
	NetClient.room_create_failed.connect(func(r): _set_status("Create failed: %s" % r))
	NetClient.room_joined.connect(_on_room_joined)
	NetClient.room_join_failed.connect(func(r): _set_status("Join failed: %s" % r))
	NetClient.disconnected.connect(_on_disconnected)

	NetClient.list_stages()
	NetClient.list_rooms()
	_refresh_panel_enabled()

func _on_stages_list(stages: Array) -> void:
	_stages = stages
	stages_list.clear()
	for s in stages:
		stages_list.add_item("%s  —  %s" % [s.get("label", str(s.get("id", 0))), s.get("name", "")])

func _on_stage_selected(idx: int) -> void:
	_selected_stage = _stages[idx]
	stage_title.text = "%s — %s" % [_selected_stage.get("label", str(_selected_stage.get("id", 0))), _selected_stage.get("name", "")]
	stage_info.text = "Grid %dx%d   Players: %d" % [
		int(_selected_stage.get("grid_w", 0)),
		int(_selected_stage.get("grid_h", 0)),
		int(_selected_stage.get("required_players", 0)),
	]
	_refresh_rooms_list()
	_refresh_panel_enabled()

func _on_rooms_update(rooms: Array, count: int, max_rooms: int) -> void:
	_all_rooms = rooms
	_max_rooms = max_rooms
	room_count_label.text = "Rooms (total): %d / %d" % [count, max_rooms]
	_refresh_rooms_list()
	_refresh_panel_enabled()

func _refresh_rooms_list() -> void:
	rooms_list.clear()
	if _selected_stage.is_empty(): return
	var sid := int(_selected_stage.get("id", 0))
	for r in _all_rooms:
		if int(r.get("stage_id", -1)) != sid: continue
		rooms_list.add_item("%s   (%d/%d)%s" % [
			r.get("name", ""),
			int(r.get("players", 0)),
			int(r.get("required_players", 0)),
			"   [started]" if r.get("started", false) else "",
		])

func _on_room_selected(idx: int) -> void:
	# index into the filtered list; map back to the original room entry
	var sid := int(_selected_stage.get("id", 0))
	var filtered := []
	for r in _all_rooms:
		if int(r.get("stage_id", -1)) == sid:
			filtered.append(r)
	_selected_room_name = filtered[idx].get("name", "")

func _on_create_pressed() -> void:
	if _selected_stage.is_empty():
		_set_status("Pick a stage first."); return
	NetClient.create_room(room_name_input.text.strip_edges(), int(_selected_stage.get("id", 0)), 2, false)

func _on_join_pressed() -> void:
	if _selected_room_name == "":
		_set_status("Pick a room from the list."); return
	NetClient.join_room(_selected_room_name, join_pw_input.text)

func _on_room_created(name: String, password: String, state: Dictionary, you: Dictionary) -> void:
	generated_pw.text = "Password: %s" % password
	Bootstrap.stash(state, you, password, name)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_room_joined(name: String, state: Dictionary, you: Dictionary) -> void:
	Bootstrap.stash(state, you, "", name)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _refresh_panel_enabled() -> void:
	var has_stage := not _selected_stage.is_empty()
	create_btn.disabled = (not has_stage) or _all_rooms.size() >= _max_rooms
	join_btn.disabled = (not has_stage) or _selected_room_name == ""

func _set_status(s: String) -> void:
	status_label.text = s

func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
