extends RefCounted

const DOT := 2.0
const INK := Color("#172d35")
const SHADE := Color("#304751")
const STEEL := Color("#496775")
const STEEL_LIGHT := Color("#9db8b5")
const CREAM := Color("#fff0cd")
const MINT := Color("#80ddb0")
const MINT_SHADOW := Color("#41977e")
const BRASS := Color("#efc477")
const ORANGE := Color("#f58b61")
const SOIL := Color("#58443e")
const CLAY := Color("#89604b")
const LOAM := Color("#6e5146")
const GRASS := Color("#43785c")
const GRASS_LIGHT := Color("#8db171")
const SKY := Color("#a4c7c1")
const HAZE := Color("#bab8ae")
const CLOUD := Color("#e3dbb8")
const FAR := Color("#8db5af")
const MID := Color("#729e96")
const NEAR := Color("#638f80")
const NIGHT_FAR := Color("#8e9d9c")
const NIGHT_MID := Color("#748e89")
const NIGHT_NEAR := Color("#607e76")

static func snap(point: Vector2) -> Vector2:
	return point.snapped(Vector2.ONE * DOT)

static func block(canvas: Node2D, position: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(position, size), color)

static func steps(canvas: Node2D, from: Vector2, to: Vector2, color: Color) -> void:
	var cell := Vector2i((from / DOT).round())
	var end := Vector2i((to / DOT).round())
	var distance := (end - cell).abs()
	var direction := (end - cell).sign()
	var error := distance.x - distance.y
	while true:
		block(canvas, Vector2(cell) * DOT, Vector2.ONE * DOT, color)
		if cell == end:
			return
		var doubled := 2 * error
		if doubled > -distance.y:
			error -= distance.y
			cell.x += direction.x
		if doubled < distance.x:
			error += distance.x
			cell.y += direction.y

static func box(background: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = background
	frame.border_color = border
	frame.set_border_width_all(width)
	frame.anti_aliasing = false
	frame.content_margin_left = 12
	frame.content_margin_right = 12
	return frame
