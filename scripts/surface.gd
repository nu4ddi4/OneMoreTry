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
	set_active(initial_active)

func _draw() -> void:
	if not active and fallen == 0:
		return
	var r := Rect2(Vector2(0, fallen), dimensions)
	draw_rect(r, Color("967557"))
	draw_rect(Rect2(r.position, Vector2(dimensions.x, 5)), Color("c7bf91"))
	if belt_speed != 0:
		for x in range(0, int(dimensions.x) - 4, 14):
			draw_line(Vector2(x + 3, 9), Vector2(x + 9, 13), Color("48625b"), 3)
