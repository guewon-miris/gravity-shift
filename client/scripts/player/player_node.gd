class_name PlayerNode
extends Node2D

const PLAYER_TEX: Texture2D = preload("res://assets/images/night.png")
const MOVE_DURATION := 0.12

var pid: int = -1
var color_idx: int = 0
var gravity_idx: int = 0
var cell: Vector2i = Vector2i.ZERO
var is_local: bool = false
var pname: String = ""

var _sprite: Sprite2D

func setup(p_pid: int, p_color: int, p_cell: Vector2i, p_is_local: bool, p_name: String = "") -> void:
	pid = p_pid
	color_idx = p_color
	cell = p_cell
	is_local = p_is_local
	pname = p_name
	position = GameConstants.cell_to_world(cell.x, cell.y)
	z_index = 10
	_build_visual()

func apply_state(new_cell: Vector2i, new_gravity: int) -> void:
	gravity_idx = new_gravity
	if new_cell == cell:
		return
	cell = new_cell
	var target := GameConstants.cell_to_world(cell.x, cell.y)
	var tween := create_tween()
	tween.tween_property(self, "position", target, MOVE_DURATION)

func _build_visual() -> void:
	for child in get_children():
		child.queue_free()
	_sprite = Sprite2D.new()
	_sprite.texture = PLAYER_TEX
	_sprite.modulate = GameConstants.COLOR_PRIMARY[color_idx]
	var tex_size := PLAYER_TEX.get_size()
	if tex_size.y > 0.0:
		var s := (GameConstants.CELL_PX * 0.9) / tex_size.y
		_sprite.scale = Vector2(s, s)
	add_child(_sprite)

	if pname != "":
		var label := Label.new()
		label.text = pname
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(GameConstants.CELL_PX * 1.6, 18)
		label.position = Vector2(-GameConstants.CELL_PX * 0.8, -GameConstants.CELL_PX * 0.85)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", GameConstants.COLOR_PRIMARY[color_idx])
		add_child(label)

func _process(_dt: float) -> void:
	if not is_local:
		return
	# Don't move while typing in a text field (chat).
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if Input.is_action_just_pressed("move_up"):    NetClient.move(Vector2i(0, 1))
	if Input.is_action_just_pressed("move_down"):  NetClient.move(Vector2i(0, -1))
	if Input.is_action_just_pressed("move_left"):  NetClient.move(Vector2i(-1, 0))
	if Input.is_action_just_pressed("move_right"): NetClient.move(Vector2i(1, 0))
	if Input.is_action_just_pressed("interact"):   NetClient.interact()
