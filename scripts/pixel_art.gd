extends RefCounted

const DOT := 2.0
const INK := Color("#332419")
const SHADE := Color("#53402c")
const STEEL := Color("#78563b")
const STEEL_LIGHT := Color("#c49a65")
const CREAM := Color("#fff0ba")
const BRASS := Color("#dfaa5f")
const ORANGE := Color("#a44a2a")
const CUTTING_EDGE := Color("#f9bf72")
const SOIL := Color("#483325")
const CLAY := Color("#8b643d")
const LOAM := Color("#63482f")
const GRASS := Color("#bb8b50")
const GRASS_LIGHT := Color("#f9d491")
const SKY := Color("#dbab66")
const HAZE := Color("#cf9f65")
const CLOUD := Color("#f0c981")
const FAR := Color("#be955e")
const MID := Color("#ab824f")
const NEAR := Color("#986f47")
const NIGHT_FAR := Color("#b48855")
const NIGHT_MID := Color("#a1764c")
const NIGHT_NEAR := Color("#886440")

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
