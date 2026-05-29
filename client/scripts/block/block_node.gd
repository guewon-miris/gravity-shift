class_name BlockNode
extends Node2D

const BOX_TEX: Texture2D = preload("res://assets/images/box.png")
const MOVE_DURATION := 0.10

var bid: int = -1
var color_idx: int = 0
var cell: Vector2i = Vector2i.ZERO

func setup(p_bid: int, p_color: int, p_cell: Vector2i) -> void:
	bid = p_bid
	color_idx = p_color
	cell = p_cell
	position = GameConstants.cell_to_world(cell.x, cell.y)
	z_index = 5
	_build_visual()

func apply_state(new_cell: Vector2i) -> void:
	if new_cell == cell:
		return
	cell = new_cell
	var target := GameConstants.cell_to_world(cell.x, cell.y)
	var tween := create_tween()
	tween.tween_property(self, "position", target, MOVE_DURATION)

func _build_visual() -> void:
	for child in get_children():
		child.queue_free()
	var spr := Sprite2D.new()
	spr.texture = BOX_TEX
	spr.modulate = GameConstants.COLOR_PRIMARY[color_idx]
	var side := GameConstants.CELL_PX * 0.92
	spr.scale = Vector2(side, side) / BOX_TEX.get_size()
	add_child(spr)
