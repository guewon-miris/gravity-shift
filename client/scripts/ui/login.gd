extends Control
## Name-entry screen. Picks a unique name; saves name+token locally for fast relaunch.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_URL := "ws://127.0.0.1:8765"

@onready var name_input: LineEdit = $Panel/VBox/NameInput
@onready var server_input: LineEdit = $Panel/VBox/ServerInput
@onready var start_btn: Button = $Panel/VBox/StartBtn
@onready var status_label: Label = $Panel/VBox/StatusLabel

var _server_url: String = DEFAULT_URL
var _pending: Callable
var _saved_name: String = ""
var _saved_token: String = ""

func _ready() -> void:
	_load_settings()
	server_input.text = _server_url
	start_btn.pressed.connect(_on_start)
	name_input.text_submitted.connect(func(_t): _on_start())

	NetClient.connected.connect(_on_connected)
	NetClient.disconnected.connect(func(): _set_status("서버에 연결할 수 없습니다. 주소를 확인하세요."))
	NetClient.name_ok.connect(_on_name_ok)
	NetClient.name_failed.connect(_on_name_failed)

	if _saved_name != "" and _saved_token != "":
		name_input.text = _saved_name
		_set_status("불러오는 중...")
		_request(func(): NetClient.claim_name(_saved_name, _saved_token))
	else:
		name_input.grab_focus()

func _on_start() -> void:
	var n := name_input.text.strip_edges()
	if n == "":
		_set_status("이름을 입력하세요."); return
	_set_status("확인 중...")
	_request(func(): NetClient.claim_name(n, ""))

func _request(action: Callable) -> void:
	var url := server_input.text.strip_edges()
	_server_url = url if url != "" else DEFAULT_URL
	_save_url()
	if NetClient._was_connected:
		action.call()
	else:
		_pending = action
		NetClient.connect_to(_server_url)

func _on_connected() -> void:
	if _pending.is_valid():
		var a := _pending
		_pending = Callable()
		a.call()

func _on_name_ok(player_name: String, token: String) -> void:
	_save_name(player_name, token)
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _on_name_failed(reason: String) -> void:
	_saved_token = ""  # stale/taken: fall back to manual entry
	_set_status(reason)
	name_input.grab_focus()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_server_url = cfg.get_value("net", "server_url", DEFAULT_URL)
		_saved_name = cfg.get_value("account", "username", "")
		_saved_token = cfg.get_value("account", "token", "")

func _save_url() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("net", "server_url", _server_url)
	cfg.save(SETTINGS_PATH)

func _save_name(player_name: String, token: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("net", "server_url", _server_url)
	cfg.set_value("account", "username", player_name)
	cfg.set_value("account", "token", token)
	cfg.save(SETTINGS_PATH)

func _set_status(s: String) -> void:
	status_label.text = s
