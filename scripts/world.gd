class_name TryWorld
extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const OBSERVATORY = preload("res://assets/art/brass_observatory.png")
const Elements = preload("res://scripts/elements.gd")
const Course = preload("res://scripts/course.gd")
const LENGTH := Course.LENGTH
const FLOOR := Course.FLOOR
const CHECKPOINTS := Course.CHECKPOINTS
const SECRET := Course.SECRET
const GOAL := Course.GOAL
var grounds: Array[Rect2] = []
var ledges: Array[Rect2] = []
var climbable_ledges: Array[Rect2] = []
var game: Node2D
var font: Font
var visual_time := 0.0

func add_solid(rect: Rect2, climbable: bool = false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Elements.SOLID_LAYER
	body.collision_mask = Elements.PLAYER_LAYER
	body.add_to_group(Elements.family(Elements.Kind.TERRAIN))
	if climbable: body.add_to_group(&"climbable_walls")
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.get_center()
	body.add_child(collider)
	add_child(body)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = load("res://assets/fonts/OneMoreSans.otf")
	for data in Course.all():
		var cursor := 0.0
		for gap in data.gaps:
			grounds.append(Rect2(data.x + cursor, FLOOR, gap.x - cursor, 204))
			cursor = gap.y
		grounds.append(Rect2(data.x + cursor, FLOOR, data.width - cursor, 204))
		for index in data.solids.size():
			var local: Rect2 = data.solids[index]
			ledges.append(Rect2(local.position + Vector2(data.x, 0), local.size))
			if index in data.climbable_solids: climbable_ledges.append(ledges.back())
	for rect in grounds + ledges:
		add_solid(rect, rect in climbable_ledges)
	add_solid(Rect2(-40, -512, 40, 1600))
	add_solid(Rect2(LENGTH, -512, 40, 1600))

func _process(delta: float) -> void:
	if game.world_animation_enabled():
		visual_time += delta
	queue_redraw()

func _draw() -> void:
	var view_size := get_viewport_rect().size
	var center: Vector2 = game.camera.position if game and game.camera else Vector2(480, 270)
	var left := center.x - view_size.x / 2.0
	var top := center.y - view_size.y / 2.0
	# Include the camera shake margin so a resized window never exposes clear color.
	var route_tint := clampf(center.x / LENGTH, 0, 1)
	draw_rect(Rect2(Vector2(left, top) - Vector2(8, 8), view_size + Vector2(16, 16)), Art.SKY.lerp(Art.HAZE, route_tint))
	var sky_tone := Art.FAR.lerp(Art.NIGHT_FAR, route_tint)
	var sun := Art.snap(Vector2(left + view_size.x * 0.22, 132))
	for row in range(-24, 24, 2):
		var half := snappedf(sqrt(576 - row * row), Art.DOT)
		Art.block(self, sun + Vector2(-half, row), Vector2(half * 2, 2), Art.CLOUD)
	for i in range(-1, ceili(view_size.x / 250.0) + 2):
		var x := left + i * 250.0 + fposmod(-left * 0.12 + visual_time * 2, 250.0) - 140
		cloud(Art.snap(Vector2(x, 106 + posmod(i, 3) * 36)))
	for layer in 3:
		var spacing := 264 + layer * 72
		var tone: Color = [Art.FAR, Art.MID, Art.NEAR][layer]
		var late_tone: Color = [Art.NIGHT_FAR, Art.NIGHT_MID, Art.NIGHT_NEAR][layer]
		for i in range(-1, ceili(view_size.x / spacing) + 2):
			var x := left + i * spacing + fposmod(-left * (0.16 + layer * 0.12), spacing) - spacing
			var y := 246 + layer * 46 + posmod(i, 2) * 18
			ridge(Art.snap(Vector2(x, y)), spacing, tone.lerp(late_tone, route_tint))
	var landmark_size := Vector2(OBSERVATORY.get_size()) * 3
	var landmark_spacing := view_size.x + 320
	var offset := fposmod(left * 0.18, landmark_spacing)
	var first_landmark := left + view_size.x - landmark_size.x * 0.90 - offset
	for i in 2:
		var landmark_at := Art.snap(Vector2(first_landmark + i * landmark_spacing, 398 - landmark_size.y))
		if landmark_at.x < left + view_size.x and landmark_at.x + landmark_size.x > left:
			draw_texture_rect(OBSERVATORY, Rect2(landmark_at, landmark_size), false)
	var bottom := top + view_size.y + 8
	if bottom > FLOOR:
		Art.block(self, Vector2(left - 8, 440), Vector2(view_size.x + 16, maxf(0, bottom - 440)), sky_tone)
	if game.title_visible():
		title_masonry(center.x)
	for rect in grounds:
		if rect.end.x < left - 32 or rect.position.x > left + view_size.x + 32:
			continue
		var extended: Rect2 = rect
		extended.size.y = maxf(rect.size.y, top + view_size.y + 8 - rect.position.y)
		terrain(extended)
	for rect in ledges:
		if rect.end.x >= left - 32 and rect.position.x <= left + view_size.x + 32:
			terrain(rect, true)
			if rect in climbable_ledges: Elements.climb_wall(self,rect)
	for i in range(maxi(0, int(left / 100) - 1), mini(int(LENGTH / 100), int((left + view_size.x) / 100) + 2)):
		var x := i * 100 + 36
		if on_ground(x):
			grass(Vector2(x, FLOOR), i)
	for n in range(Course.number_at(left) - 1, Course.number_at(left + view_size.x)):
		var at := Vector2(Course.origin(n + 1) + Course.width(n + 1) - 104, FLOOR)
		if on_ground(at.x): bush(at)
	for index in range(CHECKPOINTS.size()):
		flag(CHECKPOINTS[index], game.checkpoint_index >= index, str(index + 1))
	goal(Vector2(GOAL, FLOOR))
	if not game.secret_collected:
		var rise := snappedf(sin(visual_time * 3) * 4, Art.DOT)
		var at := SECRET + Vector2(0, rise)
		Art.block(self, at + Vector2(-2, -10), Vector2(4, 20), Art.BRASS)
		Art.block(self, at + Vector2(-10, -2), Vector2(20, 4), Art.BRASS)
		Art.block(self, at - Vector2(4, 4), Vector2(8, 8), Art.CREAM)

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

func cloud(at: Vector2) -> void:
	Art.block(self, at + Vector2(16, 0), Vector2(30, 4), Art.CLOUD)
	Art.block(self, at + Vector2(10, 4), Vector2(44, 4), Art.CLOUD)
	Art.block(self, at + Vector2(0, 8), Vector2(66, 4), Art.CLOUD)
	for x in range(0, 74, 4):
		Art.block(self, at + Vector2(x, 12 + 2 * posmod(x / 4, 2)), Vector2(2, 2), Art.CLOUD)

func ridge(at: Vector2, width: int, tone: Color) -> void:
	var steps := [Vector2(0, 54), Vector2(24, 44), Vector2(46, 30), Vector2(74, 16), Vector2(104, 0),
		Vector2(146, 10), Vector2(184, 24), Vector2(214, 38), Vector2(238, 50), Vector2(width, 50)]
	for i in range(steps.size() - 1):
		var start: Vector2 = at + steps[i]
		Art.block(self, start, Vector2(steps[i + 1].x - steps[i].x, 440 - start.y), tone)

func terrain(rect: Rect2, floating: bool = false) -> void:
	Elements.terrain(self, rect, floating)

func title_masonry(center_x: float) -> void:
	var left := center_x - 284
	var platform := Rect2(left, 310, 568, 24)
	Elements.terrain(self, platform, true)
	for x in [left + 14, left + 188, left + 356, left + 530]:
		var column := Rect2(x, 334, 22, FLOOR - 334)
		draw_rect(column, Art.CLAY)
		draw_rect(Rect2(x, 334, 6, FLOOR - 334), Art.LOAM)
		for y in range(344, int(FLOOR), 14):
			Art.block(self, Vector2(x, y), Vector2(22, 2), Art.SOIL)

func bush(at: Vector2) -> void:
	Art.block(self, at + Vector2(-22, -6), Vector2(44, 6), Art.LOAM)
	Art.block(self, at + Vector2(-12, -12), Vector2(20, 6), Art.CLAY)
	Art.block(self, at + Vector2(-10, -12), Vector2(16, 2), Art.GRASS)

func grass(at: Vector2, seed_value: int) -> void:
	Art.steps(self, at + Vector2(-4, -6), at - Vector2(0, 2), Art.CLAY)
	Art.steps(self, at + Vector2(4, -8), at - Vector2(0, 2), Art.CLAY)
	if seed_value % 3 == 0:
		Art.block(self, at + Vector2(2, -14), Vector2(4, 6), Art.BRASS)
		Art.block(self, at + Vector2(4, -12), Vector2(2, 2), Art.CREAM)

func flag(at: Vector2, active: bool, number: String) -> void:
	Art.block(self, at + Vector2(-6, -4), Vector2(16, 4), Art.INK)
	Art.block(self, at + Vector2(0, -72), Vector2(4, 70), Art.INK)
	Art.block(self, at + Vector2(0, -72), Vector2(2, 68), Art.STEEL_LIGHT)
	var flag_color := Art.BRASS if active else Art.STEEL_LIGHT
	for strip in 8:
		var flutter := snappedf(sin(visual_time * 8 - strip * 0.5) * strip * 0.45, Art.DOT)
		Art.block(self, at + Vector2(4 + strip * 4, -68 + flutter), Vector2(4, 20), flag_color)
	draw_string(font, at + Vector2(12, -53), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.INK)
	if active:
		Art.block(self, at + Vector2(-2, -78), Vector2(8, 4), Art.BRASS)

func goal(at: Vector2) -> void:
	Elements.door(self, Rect2(at + Vector2(-32, -80), Vector2(64, 80)))
	Art.block(self, at + Vector2(-38, -100), Vector2(76, 20), Art.INK)
	draw_string(font, at + Vector2(-27, -85), "FINISH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.CREAM)
