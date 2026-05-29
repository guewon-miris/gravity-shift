extends Node
## Tiny autoload to pass initial-room payload between menu scene and game scene.

var pending_state: Dictionary = {}
var pending_you: Dictionary = {}
var pending_password: String = ""
var pending_room_name: String = ""

func stash(state: Dictionary, you: Dictionary, password: String = "", room_name: String = "") -> void:
	pending_state = state
	pending_you = you
	pending_password = password
	pending_room_name = room_name

func consume() -> void:
	pending_state = {}
	pending_you = {}
	pending_password = ""
	pending_room_name = ""
