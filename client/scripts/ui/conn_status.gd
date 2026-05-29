extends CanvasLayer
## Global top-left server connection indicator. Green dot = connected, red = not.

var _label: Label

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(12, 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)

	NetClient.connected.connect(func(): _refresh(true))
	NetClient.disconnected.connect(func(): _refresh(false))
	_refresh(NetClient._was_connected)

func _refresh(is_connected: bool) -> void:
	if is_connected:
		_label.text = "● 연결됨"
		_label.add_theme_color_override("font_color", Color(0.20, 0.80, 0.30))
	else:
		_label.text = "● 연결 안 됨"
		_label.add_theme_color_override("font_color", Color(0.90, 0.25, 0.25))
