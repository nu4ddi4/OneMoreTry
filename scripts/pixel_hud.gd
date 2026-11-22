extends Control

const INSETS := Vector2(10, 8)
const Art = preload("res://scripts/pixel_art.gd")
const DIGITS = preload("res://assets/art/brass_digits.png")
const SKULL = preload("res://assets/art/brass_skull.png")
const DIGIT_ORDER := "0123456789:."
var deaths := "000"
var time := "00:00.00"
var progress := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_values(death_count: int, time_text: String, completion: float) -> void:
	var count := "%03d" % death_count
	if count == deaths and time_text == time and is_equal_approx(completion, progress):
		return
	deaths = count
	time = time_text
	progress = completion
	queue_redraw()

func _draw() -> void:
	var seam := INSETS.x + 20 + deaths.length() * 12
	var right := seam + 16 + time.length() * 12 - 12 + INSETS.x
	draw_rect(Rect2(0, 0, right, 34), Art.INK)
	draw_rect(Rect2(0, 0, right, 34), Art.BRASS, false, 2)
	draw_texture_rect(SKULL, Rect2(INSETS, Vector2(18, 18)), false)
	draw_number(deaths, Vector2(34, 9))
	draw_rect(Rect2(seam + 4, 8, 2, 18), Art.BRASS)
	draw_number(time, Vector2(seam + 16, 9))
	draw_rect(Rect2(0, 32, right * progress, 2), Art.ORANGE)

func draw_number(value: String, at: Vector2) -> void:
	var x := at.x
	for character in value:
		var glyph := DIGIT_ORDER.find(character)
		if glyph >= 0:
			draw_texture_rect_region(DIGITS, Rect2(x, at.y, 9, 15), Rect2(glyph * 4, 0, 3, 5))
			x += 6 if glyph >= 10 else 12
