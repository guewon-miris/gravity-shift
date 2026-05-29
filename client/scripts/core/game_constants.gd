extends Node

const MAX_ROOMS: int = 6
const MIN_GRID: int = 8
const MAX_GRID: int = 14
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 3
const CELL_PX: float = 64.0

const COLOR_PRIMARY: Array = [
	Color(0.85, 0.20, 0.20),
	Color(0.20, 0.40, 0.85),
	Color(0.20, 0.75, 0.30),
]

const COLOR_SECONDARY: Array = [
	Color(0.55, 0.10, 0.10),
	Color(0.10, 0.20, 0.55),
	Color(0.10, 0.45, 0.15),
]

# Hazard fill colors keyed by kind string.
const HAZARD_COLORS: Dictionary = {
	"lava":  Color(0.90, 0.30, 0.05),
	"spike": Color(0.55, 0.55, 0.60),
	"hole":  Color(0.05, 0.05, 0.08),
	"laser": Color(0.95, 0.10, 0.65),
}

# Grid cell -> 2D pixel position (cell center). Grid +Y is visually up.
static func cell_to_world(x: int, y: int) -> Vector2:
	return Vector2(x * CELL_PX, -y * CELL_PX)
