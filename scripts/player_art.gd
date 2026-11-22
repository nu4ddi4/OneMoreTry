extends RefCounted

const Art = preload("res://scripts/pixel_art.gd")
const TRAVELER = preload("res://assets/art/brass_traveler.png")
const RUN_FEET := [
	[4, -4, 0, -2], [2, -2, 0, -4], [-2, 2, 0, -2],
	[-4, 4, -2, 0], [-2, 2, -4, 0], [2, -2, -2, 0],
]
const RUN_BOB := [0, 2, 0, 0, 2, 0]

static func draw_pose(canvas: Node2D, facing: float, bob: float, feet: Array, hands: Array, charged: bool) -> void:
	if charged:
		draw_charge(canvas, bob)
	draw_part(canvas, Vector2(-6 + feet[1], -8 + feet[3]), Vector2(6, 8), Art.SHADE, facing)
	draw_part(canvas, Vector2(2 + feet[0], -8 + feet[2]), Vector2(8, 8), Art.INK, facing)
	draw_part(canvas, Vector2(4 + feet[0], -6 + feet[2]), Vector2(4, 2), Art.STEEL, facing)
	var cape_lift: float = -2 if feet[2] != feet[3] else 0
	draw_part(canvas, Vector2(-17, -18 + bob + cape_lift), Vector2(12, 4), Art.SHADE, facing)
	draw_part(canvas, Vector2(-19, -16 + bob + cape_lift), Vector2(10, 2), Art.INK, facing)
	var body := Rect2(Vector2(-14, -36 + bob), Vector2(TRAVELER.get_size()) * Art.DOT)
	if facing < 0:
		body.size.x = -body.size.x
	canvas.draw_texture_rect(TRAVELER, body, false)
	draw_part(canvas, hands[0] + Vector2(0, bob), Vector2(4, 4), Art.STEEL, facing)
	draw_part(canvas, hands[1] + Vector2(0, bob), Vector2(4, 4), Art.BRASS, facing)

static func draw_part(canvas: Node2D, at: Vector2, size: Vector2, color: Color, facing: float) -> void:
	var position := at if facing >= 0 else Vector2(-at.x - size.x, at.y)
	Art.block(canvas, position, size, color)

static func draw_charge(canvas: Node2D, bob: float) -> void:
	for side in [-1, 1]:
		var at := Vector2(18 * side, -20 + bob)
		Art.block(canvas, at - Vector2(2, 0), Vector2(6, 2), Art.BRASS)
		Art.block(canvas, at - Vector2(0, 2), Vector2(2, 6), Art.CREAM)
