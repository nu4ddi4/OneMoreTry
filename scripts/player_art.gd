extends RefCounted

const Art = preload("res://scripts/pixel_art.gd")
const RUN_FEET := [
	[4, -4, 0, -2], [2, -2, 0, -4], [-2, 2, 0, -2],
	[-4, 4, -2, 0], [-2, 2, -4, 0], [2, -2, -2, 0],
]
const RUN_BOB := [0, 2, 0, 0, 2, 0]

static func draw_pose(canvas: Node2D, facing: float, bob: float, feet: Array, hands: Array, charged: bool) -> void:
	if charged:
		draw_charge(canvas, bob)
	draw_part(canvas, Vector2(-6 + feet[1], -8 + feet[3]), Vector2(6, 8), Art.SHADE, facing)
	draw_part(canvas, Vector2(2 + feet[0], -8 + feet[2]), Vector2(6, 8), Art.INK, facing)
	draw_part(canvas, Vector2(2 + feet[0], -4 + feet[2]), Vector2(6, 2), Art.STEEL, facing)
	draw_part(canvas, Vector2(-10, -32 + bob), Vector2(20, 26), Art.INK, facing)
	draw_part(canvas, Vector2(-12, -28 + bob), Vector2(24, 18), Art.INK, facing)
	draw_part(canvas, Vector2(-8, -30 + bob), Vector2(16, 22), Art.MINT_SHADOW, facing)
	draw_part(canvas, Vector2(-10, -28 + bob), Vector2(20, 16), Art.MINT, facing)
	draw_part(canvas, Vector2(-8, -36 + bob), Vector2(4, 6), Art.MINT_SHADOW, facing)
	draw_part(canvas, Vector2(4, -36 + bob), Vector2(4, 6), Art.MINT, facing)
	draw_part(canvas, Vector2(-6, -24 + bob), Vector2(14, 10), Art.CREAM, facing)
	draw_part(canvas, Vector2(-2, -22 + bob), Vector2(2, 4), Art.INK, facing)
	draw_part(canvas, Vector2(4, -22 + bob), Vector2(2, 4), Art.INK, facing)
	draw_part(canvas, Vector2(2, -16 + bob), Vector2(2, 2), Art.ORANGE, facing)
	draw_part(canvas, hands[0] + Vector2(0, bob), Vector2(4, 4), Art.MINT_SHADOW, facing)
	draw_part(canvas, hands[1] + Vector2(0, bob), Vector2(4, 4), Art.MINT, facing)

static func draw_part(canvas: Node2D, at: Vector2, size: Vector2, color: Color, facing: float) -> void:
	var position := at if facing >= 0 else Vector2(-at.x - size.x, at.y)
	Art.block(canvas, position, size, color)

static func draw_charge(canvas: Node2D, bob: float) -> void:
	for side in [-1, 1]:
		var at := Vector2(18 * side, -20 + bob)
		Art.block(canvas, at - Vector2(2, 0), Vector2(6, 2), Art.MINT)
		Art.block(canvas, at - Vector2(0, 2), Vector2(2, 6), Art.CREAM)
