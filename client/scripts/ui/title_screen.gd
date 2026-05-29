extends Control

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_URL := "ws://127.0.0.1:8765"

@onready var new_game_btn: Button = $LeftPanel/NewGameBtn
@onready var challenge_btn: Button = $LeftPanel/ChallengeBtn
@onready var settings_btn: Button = $LeftPanel/SettingsBtn
@onready var credits_btn: Button = $LeftPanel/CreditsBtn
@onready var quit_btn: Button = $LeftPanel/QuitBtn
@onready var status_label: Label = $StatusLabel

@onready var settings_dialog: Panel = $SettingsDialog
@onready var name_input: LineEdit = $SettingsDialog/VBox/NameInput
@onready var server_url_input: LineEdit = $SettingsDialog/VBox/ServerUrlInput
@onready var settings_save: Button = $SettingsDialog/VBox/Buttons/SaveBtn
@onready var settings_cancel: Button = $SettingsDialog/VBox/Buttons/CancelBtn

@onready var credits_dialog: Panel = $CreditsDialog
@onready var credits_close: Button = $CreditsDialog/VBox/CloseBtn

var _server_url: String = DEFAULT_URL
var _name: String = ""
var _token: String = ""

func _ready() -> void:
	_load_settings()

	new_game_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	challenge_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/stage_select.tscn"))
	settings_btn.pressed.connect(_open_settings)
	credits_btn.pressed.connect(func(): credits_dialog.visible = true)
	quit_btn.pressed.connect(func(): get_tree().quit())
	new_game_btn.grab_focus()

	settings_save.pressed.connect(_on_settings_save)
	settings_cancel.pressed.connect(func(): settings_dialog.visible = false)
	credits_close.pressed.connect(func(): credits_dialog.visible = false)

	NetClient.name_ok.connect(_on_name_ok)
	NetClient.name_failed.connect(func(r): _set_status("이름 변경 실패: %s" % r))

	_set_status("%s 님 환영합니다." % _name if _name != "" else "")

func _open_settings() -> void:
	name_input.text = _name
	server_url_input.text = _server_url
	settings_dialog.visible = true

func _on_settings_save() -> void:
	_server_url = server_url_input.text.strip_edges()
	if _server_url == "":
		_server_url = DEFAULT_URL
	var new_name := name_input.text.strip_edges()
	if new_name != "" and new_name != _name:
		# Claim the new name with no token (must be free); confirmed via name_ok.
		NetClient.claim_name(new_name, "")
	_persist()
	settings_dialog.visible = false
	_set_status("저장됨.")

func _on_name_ok(player_name: String, token: String) -> void:
	_name = player_name
	_token = token
	_persist()
	_set_status("이름이 '%s'(으)로 변경되었습니다." % player_name)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_server_url = cfg.get_value("net", "server_url", DEFAULT_URL)
		_name = cfg.get_value("account", "username", "")
		_token = cfg.get_value("account", "token", "")

func _persist() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("net", "server_url", _server_url)
	cfg.set_value("account", "username", _name)
	cfg.set_value("account", "token", _token)
	cfg.save(SETTINGS_PATH)

func _set_status(s: String) -> void:
	status_label.text = s
