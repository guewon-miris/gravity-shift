extends Control
## Create a room (with player count), or expand the room list and join one (no password).

const CAMPAIGN_START_STAGE := 1

@onready var room_name_input: LineEdit = $VBox/CreateBox/RoomName
@onready var count_option: OptionButton = $VBox/CreateBox/CountOption
@onready var create_btn: Button = $VBox/CreateBox/CreateBtn
@onready var generated_pw: Label = $VBox/GeneratedPw
@onready var expand_btn: Button = $VBox/ExpandBtn
@onready var room_count_label: Label = $VBox/RoomCount
@onready var list_box: VBoxContainer = $VBox/ListBox
@onready var rooms_list: ItemList = $VBox/ListBox/RoomsList
@onready var join_btn: Button = $VBox/ListBox/JoinBtn
@onready var back_btn: Button = $VBox/BottomBox/BackBtn
@onready var status_label: Label = $VBox/BottomBox/StatusLabel

var _rooms: Array = []
var _selected_room: String = ""

func _ready() -> void:
	count_option.add_item("2인", 2)
	count_option.add_item("3인", 3)

	create_btn.pressed.connect(_on_create)
	expand_btn.toggled.connect(_on_expand_toggled)
	join_btn.pressed.connect(_on_join)
	rooms_list.item_selected.connect(_on_room_selected)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title_screen.tscn"))

	NetClient.rooms_update.connect(_on_rooms_update)
	NetClient.room_created.connect(_on_room_created)
	NetClient.room_create_failed.connect(func(r): _set_status("생성 실패: %s" % r))
	NetClient.room_joined.connect(_on_room_joined)
	NetClient.room_join_failed.connect(func(r): _set_status("참여 실패: %s" % r))
	NetClient.disconnected.connect(_on_disconnected)

	list_box.visible = false
	NetClient.list_rooms()

func _on_create() -> void:
	var name := room_name_input.text.strip_edges()
	if name == "":
		_set_status("방 이름을 입력하세요."); return
	var count := int(count_option.get_selected_id())
	_set_status("방 생성 중...")
	NetClient.create_room(name, CAMPAIGN_START_STAGE, count, true)

func _on_expand_toggled(pressed: bool) -> void:
	list_box.visible = pressed
	expand_btn.text = "방 목록 접기  ▲" if pressed else "방 목록 펼치기  ▼"
	if pressed:
		NetClient.list_rooms()

func _on_rooms_update(rooms: Array, count: int, max_rooms: int) -> void:
	_rooms = rooms
	room_count_label.text = "Rooms: %d / %d" % [count, max_rooms]
	rooms_list.clear()
	for r in rooms:
		rooms_list.add_item("%s   [%s]   (%d/%d)%s" % [
			r.get("name", ""), r.get("label", ""),
			int(r.get("players", 0)), int(r.get("required_players", 0)),
			"   시작됨" if r.get("started", false) else "",
		])
	create_btn.disabled = count >= max_rooms

func _on_room_selected(idx: int) -> void:
	_selected_room = _rooms[idx].get("name", "")

func _on_join() -> void:
	if _selected_room == "":
		_set_status("목록에서 방을 선택하세요."); return
	NetClient.join_room(_selected_room, "")

func _on_room_created(name: String, password: String, state: Dictionary, you: Dictionary) -> void:
	generated_pw.text = "비밀번호: %s" % password
	Bootstrap.stash(state, you, password, name)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_room_joined(name: String, state: Dictionary, you: Dictionary) -> void:
	Bootstrap.stash(state, you, "", name)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/login.tscn")

func _set_status(s: String) -> void:
	status_label.text = s
