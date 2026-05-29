extends Control
## Virtual joystick + interact button for mobile.

@onready var joystick_area: Control = $JoystickArea
@onready var joystick_knob: Control = $JoystickArea/Knob
@onready var interact_button: Button = $InteractButton

const SWIPE_THRESHOLD := 30.0

var _origin: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _last_step: Vector2i = Vector2i.ZERO

func _ready() -> void:
	interact_button.pressed.connect(func(): NetClient.interact())
	joystick_area.gui_input.connect(_on_joystick_input)
	visible = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_origin = event.position
			_dragging = true
			_last_step = Vector2i.ZERO
			joystick_knob.position = _origin - joystick_knob.size * 0.5
		else:
			_dragging = false
			joystick_knob.position = joystick_area.size * 0.5 - joystick_knob.size * 0.5
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var delta: Vector2 = event.position - _origin
		joystick_knob.position = _origin + delta.limit_length(SWIPE_THRESHOLD * 2.0) - joystick_knob.size * 0.5
		if delta.length() < SWIPE_THRESHOLD:
			return
		var step: Vector2i
		if abs(delta.x) > abs(delta.y):
			step = Vector2i(1 if delta.x > 0 else -1, 0)
		else:
			step = Vector2i(0, 1 if delta.y < 0 else -1)  # screen Y flipped vs grid Y
		if step != _last_step:
			NetClient.move(step)
			_last_step = step
			_origin = event.position
