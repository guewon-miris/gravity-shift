class_name PlayerCamera
extends Camera2D

@export var margin_px: float = 96.0

func _ready() -> void:
	enabled = true
	make_current()

## Center on the board and zoom so the whole grid fits the viewport.
func frame_board(grid_w: int, grid_h: int) -> void:
	var cs := GameConstants.CELL_PX
	# Cell centers span x:[0, (w-1)*cs], y:[-(h-1)*cs, 0]; pad by half a cell each side.
	var board_w := grid_w * cs + margin_px
	var board_h := grid_h * cs + margin_px
	position = Vector2((grid_w - 1) * cs * 0.5, -(grid_h - 1) * cs * 0.5)

	var vp := get_viewport_rect().size
	var zoom_factor: float = min(vp.x / board_w, vp.y / board_h)
	zoom = Vector2(zoom_factor, zoom_factor)
