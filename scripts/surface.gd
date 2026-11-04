class_name TrySurface
extends AnimatableBody2D

var dimensions := Vector2(64, 20)
var initial_position := Vector2.ZERO
var initial_active := true
var active := true
var belt_speed := 0.0
var motion_step := Vector2.ZERO
var previous_position := Vector2.ZERO
var shape: CollisionShape2D
var fallen := 0.0
var impacted := false
var camouflaged := false
var latches := Vector2(-1, -1)
var game: Node2D

func _ready() -> void:
	sync_to_physics = false
	process_physics_priority = -5
	initial_position = position
	previous_position = position
	shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = dimensions
	shape.shape = box
	shape.position = dimensions / 2
	add_child(shape)
	set_active(initial_active)

func _physics_process(_delta: float) -> void:
	if game and not game.interaction_enabled():
		motion_step = Vector2.ZERO
		return
	motion_step = position - previous_position
	previous_position = position

func set_active(value: bool) -> void:
	active = value
	if shape:
		shape.set_deferred("disabled", not value)
	queue_redraw()

func reset() -> void:
	position = initial_position
	previous_position = position
	motion_step = Vector2.ZERO
	fallen = 0
	impacted = false
	if latches.x >= 0: latches = Vector2.ZERO
	set_active(initial_active)

func _draw() -> void:
	if not active and fallen == 0:
		return
	if camouflaged and active:
		# Match ordinary terrain; trigger extents never affect its appearance.
		var depth := maxf(204, game.camera.position.y + get_viewport_rect().size.y / 2 + 8 - global_position.y)
		draw_rect(Rect2(0, 0, dimensions.x, depth), Color("73594c"))
		draw_rect(Rect2(0, 8, dimensions.x, 15), Color("a77954"))
		draw_rect(Rect2(0, 0, dimensions.x, 7), Color("3e7f66"))
		draw_rect(Rect2(0, 0, dimensions.x, 3), Color("b7d081"))
		for x in range(4, int(dimensions.x), 20):
			draw_rect(Rect2(x, 7, 8, 5 + int(global_position.x + x) % 3), Color("3e7f66"))
		for y in range(32, ceili(depth), 23):
			for x in range(9, int(dimensions.x) - 5, 32):
				draw_rect(Rect2(x + (int(global_position.y) + y) % 3 * 3, y, 7, 3), Color("88654f"))
		return
	var r := Rect2(Vector2(0, fallen), dimensions)
	draw_rect(r, Color("967557"))
	draw_rect(Rect2(r.position, Vector2(dimensions.x, 5)), Color("c7bf91"))
	if latches.x >= 0:
		for n in 2:
			var at := Vector2(13 - latches[n] * 10, 80 + n * 30)
			draw_rect(Rect2(at, Vector2(16, 6)), Color("48635d"))
			draw_rect(Rect2(at + Vector2(2, 1), Vector2(12, 2)), Color("d9bf93"))
	if impacted:
		draw_polyline(PackedVector2Array([Vector2(12, r.position.y + 2), Vector2(22, r.position.y + 8), Vector2(17, r.end.y), Vector2(36, r.position.y + 7), Vector2(48, r.end.y)]), Color("4c453d"), 2)
	if belt_speed != 0:
		for x in range(0, int(dimensions.x) - 4, 14):
			draw_line(Vector2(x + 3, 9), Vector2(x + 9, 13), Color("48625b"), 3)
