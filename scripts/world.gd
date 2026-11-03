class_name TryWorld
extends Node2D

const Course = preload("res://scripts/course.gd")
const LENGTH := Course.LENGTH
const FLOOR := Course.FLOOR
const CHECKPOINTS := Course.CHECKPOINTS
const SECRET := Course.SECRET
const GOAL := Course.GOAL
var grounds: Array[Rect2] = []
var ledges: Array[Rect2] = []
var game: Node2D
var font: Font
var visual_time := 0.0

func add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.get_center()
	body.add_child(collider)
	add_child(body)

func _ready() -> void:
	font = load("res://assets/fonts/OneMoreSans.otf")
	for data in Course.all():
		var cursor := 0.0
		for gap in data.gaps:
			grounds.append(Rect2(data.x + cursor, FLOOR, gap.x - cursor, 204))
			cursor = gap.y
		grounds.append(Rect2(data.x + cursor, FLOOR, data.width - cursor, 204))
		for local in data.solids:
			ledges.append(Rect2(local.position + Vector2(data.x, 0), local.size))
	for rect in grounds + ledges:
		add_solid(rect)
	add_solid(Rect2(-40, -512, 40, 1600))
	add_solid(Rect2(LENGTH, -512, 40, 1600))

func _process(delta: float) -> void:
	visual_time += delta
	queue_redraw()

func _draw() -> void:
	var view_size := get_viewport_rect().size
	var center: Vector2 = game.camera.position if game and game.camera else Vector2(480, 270)
	var left := center.x - view_size.x / 2.0
	var top := center.y - view_size.y / 2.0
	# Include the camera shake margin so a resized window never exposes clear color.
	var route_tint := clampf(center.x / LENGTH, 0, 1)
	draw_rect(Rect2(Vector2(left, top) - Vector2(8, 8), view_size + Vector2(16, 16)), Color("b9dedb").lerp(Color("9da5b6"), route_tint))
	draw_rect(Rect2(left - 8, 200, view_size.x + 16, 180), Color("b0d7d1"))
	# All scenery uses a deliberately limited palette and integer pixel steps.
	for i in range(-1, ceili(view_size.x / 221.0) + 2):
		var x := left + i * 221.0 + fposmod(-left * 0.13 + visual_time * 2, 221.0) - 180
		var y := 100 + (i % 3) * 33
		cloud(Vector2(int(x), y), Color("edf0d4"))
	for layer in range(3):
		var spacing := 250.0 + layer * 80
		for i in range(-1, ceili(view_size.x / spacing) + 2):
			var x := left + i * spacing + fposmod(-left * (0.16 + layer * 0.12), spacing) - spacing
			var y := 248 + layer * 37 + (i % 2) * 17
			var tint: Color = [Color("9bc6bc"), Color("80b8a2"), Color("64a58e")][layer]
			var points := PackedVector2Array([Vector2(x, 440), Vector2(x, y + 50), Vector2(x + 24, y + 50), Vector2(x + 24, y + 27), Vector2(x + 58, y + 27), Vector2(x + 58, y + 10), Vector2(x + 86, y + 10), Vector2(x + 86, y), Vector2(x + 140, y), Vector2(x + 140, y + 16), Vector2(x + 180, y + 16), Vector2(x + 180, y + 40), Vector2(x + spacing, y + 40), Vector2(x + spacing, 440)])
			draw_colored_polygon(points, tint)
	for rect in grounds:
		if rect.end.x < left - 32 or rect.position.x > left + view_size.x + 32:
			continue
		var extended: Rect2 = rect
		extended.size.y = maxf(rect.size.y, top + view_size.y + 8 - rect.position.y)
		terrain(extended)
	for rect in ledges:
		if rect.end.x >= left - 32 and rect.position.x <= left + view_size.x + 32:
			terrain(rect, true)
	for i in range(maxi(0, int(left / 101) - 1), mini(int(LENGTH / 101), int((left + view_size.x) / 101) + 2)):
		var x := i * 101 + 37
		if on_ground(x):
			grass(Vector2(x, FLOOR), i)
	for n in range(Course.number_at(left) - 1, Course.number_at(left + view_size.x)):
		var at := Vector2(Course.origin(n + 1) + Course.width(n + 1) - 104, FLOOR)
		if on_ground(at.x): bush(at)
	for index in range(CHECKPOINTS.size()):
		flag(CHECKPOINTS[index], game.checkpoint_index >= index, str(index + 1))
	goal(Vector2(GOAL, FLOOR))
	if not game.secret_collected:
		var sy := sin(visual_time * 3) * 3
		var pts := PackedVector2Array([Vector2(0, -12), Vector2(4, -4), Vector2(12, 0), Vector2(4, 4), Vector2(0, 12), Vector2(-4, 4), Vector2(-12, 0), Vector2(-4, -4)])
		for i in pts.size():
			pts[i] += SECRET + Vector2(0, sy)
		draw_colored_polygon(pts, Color("fff2b4"))
		draw_rect(Rect2(SECRET + Vector2(-2, -2 + sy), Vector2(4, 4)), Color("e5a764"))

func on_ground(x: float) -> bool:
	for rect in grounds:
		if x > rect.position.x + 12 and x < rect.end.x - 12:
			return true
	# Concealed surfaces carry the same foliage as ordinary ground.
	if game and not game.traps.is_empty():
		for surface in game.traps[Course.number_at(x) - 1].surfaces.values():
			if surface.camouflaged and surface.active and x > surface.global_position.x + 12 and x < surface.global_position.x + surface.dimensions.x - 12:
				return true
	return false

func cloud(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(18, 0), Vector2(38, 12)), color)
	draw_rect(Rect2(at + Vector2(8, 10), Vector2(66, 12)), color)
	draw_rect(Rect2(at, Vector2(86, 8)).grow_individual(0, -19, 0, 19), color)

func terrain(rect: Rect2, floating: bool = false) -> void:
	draw_rect(rect, Color("73594c"))
	draw_rect(Rect2(rect.position + Vector2(0, 8), Vector2(rect.size.x, 15)), Color("a77954"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), Color("3e7f66"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color("b7d081"))
	for x in range(int(rect.position.x) + 4, int(rect.end.x), 20):
		draw_rect(Rect2(x, rect.position.y + 7, 8, 5 + x % 3), Color("3e7f66"))
	if not floating:
		for y in range(int(rect.position.y) + 32, int(rect.end.y), 23):
			for x in range(int(rect.position.x) + 9, int(rect.end.x) - 5, 32):
				draw_rect(Rect2(x + (y % 3) * 3, y, 7, 3), Color("88654f"))
	else:
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3)), Color("4c5a47"))

func bush(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-22, -17), Vector2(44, 17)), Color("478b6c"))
	draw_rect(Rect2(at + Vector2(-14, -25), Vector2(27, 25)), Color("599e70"))
	draw_rect(Rect2(at + Vector2(-18, -17), Vector2(8, 4)), Color("9abe78"))
	draw_rect(Rect2(at + Vector2(4, -22), Vector2(6, 3)), Color("9abe78"))

func grass(at: Vector2, seed_value: int) -> void:
	draw_line(at + Vector2(-4, -7), at, Color("387a60"), 2)
	draw_line(at + Vector2(4, -10), at, Color("387a60"), 2)
	if seed_value % 3 == 0:
		draw_rect(Rect2(at + Vector2(1, -14), Vector2(6, 6)), Color("f3d498") if seed_value % 2 else Color("f1a58c"))
		draw_rect(Rect2(at + Vector2(3, -12), Vector2(2, 2)), Color("f9edc9"))

func flag(at: Vector2, active: bool, number: String) -> void:
	draw_rect(Rect2(at + Vector2(-7, -3), Vector2(18, 3)), Color("44635b"))
	draw_rect(Rect2(at + Vector2(0, -71), Vector2(4, 69)), Color("edf0cc"))
	var wave := 2 if sin(visual_time * 5) > 0 else 0
	draw_rect(Rect2(at + Vector2(4, -68), Vector2(31 + wave, 22)), Color("f8da8a") if active else Color("639b91"))
	draw_string(font, at + Vector2(15, -52), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("3c655a"))
	if active:
		draw_rect(Rect2(at + Vector2(-3, -77), Vector2(10, 6)), Color("f8da8a"))

func goal(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-31, -80), Vector2(62, 80)), Color("324d49"))
	draw_rect(Rect2(at + Vector2(-25, -74), Vector2(50, 74)), Color("81c39a"))
	draw_rect(Rect2(at + Vector2(-18, -65), Vector2(36, 65)), Color("264b49"))
	draw_rect(Rect2(at + Vector2(-15, -62), Vector2(30, 62)), Color("f6dda0"))
	draw_rect(Rect2(at + Vector2(-15, -62), Vector2(7, 62)), Color("d3b980"))
	draw_rect(Rect2(at + Vector2(7, -32), Vector2(4, 4)), Color("8f8056"))
	draw_rect(Rect2(at + Vector2(-38, -99), Vector2(76, 20)), Color("2f5750"))
	draw_string(font, at + Vector2(-27, -85), "FINISH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f6dda0"))
