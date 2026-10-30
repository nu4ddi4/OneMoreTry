class_name TryWorld
extends Node2D

const LENGTH := 3600.0
const FLOOR := 416.0
const GROUNDS := [Rect2(0, 416, 640, 124), Rect2(784, 416, 880, 124), Rect2(1824, 416, 1040, 124), Rect2(3040, 416, 560, 124)]
const LEDGES := [Rect2(1920, 354, 88, 16), Rect2(2050, 296, 80, 16), Rect2(2180, 354, 88, 16)]
const CHECKPOINTS := [Vector2(1460, 416), Vector2(2380, 416)]
const SECRET := Vector2(2089, 271)
const GOAL := 3384.0

var game: Node2D
var font: Font
var visual_time := 0.0

func _ready() -> void:
	font = load("res://assets/fonts/OneMoreSans.otf")
	for rect in GROUNDS + LEDGES:
		var body := StaticBody2D.new()
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		collider.position = rect.get_center()
		body.add_child(collider)
		add_child(body)
	var left_wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var wall_box := RectangleShape2D.new()
	wall_box.size = Vector2(40, 1000)
	wall_shape.shape = wall_box
	wall_shape.position = Vector2(-20, 200)
	left_wall.add_child(wall_shape)
	add_child(left_wall)

func _process(delta: float) -> void:
	visual_time += delta
	queue_redraw()

func _draw() -> void:
	var left: float = game.camera.position.x - 480 if game and game.camera else 0.0
	draw_rect(Rect2(left, 0, 960, 540), Color("b9dedb"))
	draw_rect(Rect2(left, 200, 960, 180), Color("b0d7d1"))
	# All scenery uses a deliberately limited palette and integer pixel steps.
	for i in range(-1, 8):
		var x := left + fposmod(i * 221.0 - left * 0.13 + visual_time * 2, 1326) - 180
		var y := 100 + (i % 3) * 33
		cloud(Vector2(int(x), y), Color("edf0d4"))
	for layer in range(3):
		var spacing := 250.0 + layer * 80
		for i in range(-1, 7):
			var x := left + fposmod(i * spacing - left * (0.16 + layer * 0.12), spacing * 6) - spacing
			var y := 248 + layer * 37 + (i % 2) * 17
			var tint: Color = [Color("9bc6bc"), Color("80b8a2"), Color("64a58e")][layer]
			var points := PackedVector2Array([Vector2(x, 440), Vector2(x, y + 50), Vector2(x + 24, y + 50), Vector2(x + 24, y + 27), Vector2(x + 58, y + 27), Vector2(x + 58, y + 10), Vector2(x + 86, y + 10), Vector2(x + 86, y), Vector2(x + 140, y), Vector2(x + 140, y + 16), Vector2(x + 180, y + 16), Vector2(x + 180, y + 40), Vector2(x + spacing, y + 40), Vector2(x + spacing, 440)])
			draw_colored_polygon(points, tint)
	for rect in GROUNDS:
		terrain(rect)
	for rect in LEDGES:
		terrain(rect, true)
	for i in range(36):
		var x := i * 101 + 37
		if on_ground(x):
			grass(Vector2(x, FLOOR), i)
	for x in [340, 860, 1380, 2270, 2510, 3280, 3520]:
		bush(Vector2(x, FLOOR))
	signpost(Vector2(254, 416), "SPACE  점프", false)
	signpost(Vector2(528, 416), "바닥을 잘 보세요", true)
	signpost(Vector2(1120, 416), "위도 보세요!", true)
	signpost(Vector2(1560, 416), "저장 완료 →", false)
	signpost(Vector2(2540, 416), "정말 출구일까?", true)
	signpost(Vector2(3270, 416), "이번엔 진짜!", false)
	for index in range(CHECKPOINTS.size()):
		flag(CHECKPOINTS[index], game.checkpoint_index >= index, str(index + 1))
	# An intentionally suspicious false finish. The actual exit has a clear arch.
	draw_rect(Rect2(2620, 346, 4, 70), Color("44655d"))
	draw_rect(Rect2(2624, 347, 32, 21), Color("d89376"))
	draw_string(font, Vector2(2634, 363), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff1cf"))
	goal(Vector2(GOAL, FLOOR))
	if not game.secret_collected:
		var sy := sin(visual_time * 3) * 3
		var pts := PackedVector2Array([Vector2(0, -12), Vector2(4, -4), Vector2(12, 0), Vector2(4, 4), Vector2(0, 12), Vector2(-4, 4), Vector2(-12, 0), Vector2(-4, -4)])
		for i in pts.size():
			pts[i] += SECRET + Vector2(0, sy)
		draw_colored_polygon(pts, Color("fff2b4"))
		draw_rect(Rect2(SECRET + Vector2(-2, -2 + sy), Vector2(4, 4)), Color("e5a764"))
		draw_string(font, Vector2(2025, 246), "조금 다른 길", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("477f71"))

func on_ground(x: float) -> bool:
	for rect in GROUNDS:
		if x > rect.position.x + 12 and x < rect.end.x - 12:
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

func signpost(at: Vector2, text: String, suspicious: bool) -> void:
	draw_rect(Rect2(at + Vector2(-2, -35), Vector2(5, 35)), Color("7d6049"))
	draw_rect(Rect2(at + Vector2(-48, -55), Vector2(98, 25)), Color("715d4b"))
	draw_rect(Rect2(at + Vector2(-46, -53), Vector2(94, 20)), Color("e4bf84"))
	draw_string(font, at + Vector2(-41, -39), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("714e43") if suspicious else Color("3a6257"))

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
