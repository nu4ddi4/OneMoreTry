class_name TrySurface
extends AnimatableBody2D

const Elements = preload("res://scripts/elements.gd")

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
var element_kind := Elements.Kind.PLATFORM
var lethal := false

func _ready() -> void:
	collision_layer = Elements.SOLID_LAYER
	collision_mask = Elements.PLAYER_LAYER
	set_element(element_kind)
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

func set_element(kind: int) -> void:
	var old_family := Elements.family(element_kind)
	var next_family := Elements.family(kind)
	if is_in_group(old_family) and old_family != next_family: remove_from_group(old_family)
	element_kind = kind
	lethal = Elements.lethal(kind)
	if not is_in_group(next_family): add_to_group(next_family)
	queue_redraw()

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
		var depth := maxf(204, game.camera.position.y + get_viewport_rect().size.y / 2 + 8 - global_position.y)
		Elements.terrain(self,Rect2(0,0,dimensions.x,depth),false,global_position)
		return
	var r := Rect2(Vector2(0, fallen), dimensions)
	Elements.surface(self,r,element_kind,belt_speed)
	if latches.x >= 0:
		for n in 2:
			var at := Vector2(13 - latches[n] * 10, 80 + n * 30)
			draw_rect(Rect2(at, Vector2(16, 6)), Color("48635d"))
			draw_rect(Rect2(at + Vector2(2, 1), Vector2(12, 2)), Color("d9bf93"))
	if impacted:
		draw_polyline(PackedVector2Array([Vector2(12, r.position.y + 2), Vector2(22, r.position.y + 8), Vector2(17, r.end.y), Vector2(36, r.position.y + 7), Vector2(48, r.end.y)]), Color("4c453d"), 2)
