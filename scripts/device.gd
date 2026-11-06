class_name TryDevice
extends Node2D

const Elements = preload("res://scripts/elements.gd")

var kind := "double"
var game: Node2D
var encounter: Node2D
var collected := false
var cooldown := 0.0
var clock := 0.0
var length := 224.0
var rider: TryPlayer
var swing := 0.0
var swing_velocity := 0.0
var element_kind := Elements.Kind.CHARGE

func _ready() -> void:
	element_kind = {"double":Elements.Kind.CHARGE,"key":Elements.Kind.KEY,"bait":Elements.Kind.KEY,"pad":Elements.Kind.SPRING,"chain":Elements.Kind.CHAIN}[kind]
	add_to_group(Elements.family(element_kind))
	process_physics_priority = 5

func reset() -> void:
	collected = false
	cooldown = 0
	clock = 0
	rider = null
	swing = 0
	swing_velocity = 0
	queue_redraw()

func tip(distance: float = -1) -> Vector2:
	var angle := sin(clock * 1.8) * 0.28 + swing
	return global_position + Vector2(sin(angle), cos(angle)) * (length if distance < 0 else distance)

func release_velocity(distance: float) -> Vector2:
	var angle := sin(clock * 1.8) * 0.28 + swing
	var rate := cos(clock * 1.8) * 0.504 + swing_velocity
	return Vector2(cos(angle), -sin(angle)) * distance * rate

func _physics_process(delta: float) -> void:
	if not game.interaction_enabled():
		return
	var p: TryPlayer = game.player
	if absf(p.position.x - global_position.x) > 1000:
		return
	clock += delta
	cooldown = maxf(0, cooldown - delta)
	match kind:
		"double", "key", "bait":
			if not collected and p.hitbox().grow(4).has_point(global_position):
				collected = true
				if kind == "double":
					p.air_jumps = 1
					game.sound.effect("secret")
				else:
					encounter.item_taken = true
					game.sound.effect("click")
		"pad":
			if cooldown == 0 and p.velocity.y >= 0 and absf(p.position.x - global_position.x) < 22 and absf(p.position.y - global_position.y) < 7:
				p.launch(-760.0)
				cooldown = 0.2
		"chain":
			if rider == p and p.chain == self:
				swing_velocity += Input.get_axis("move_left", "move_right") * delta * 2.4
				swing_velocity *= exp(-delta * 1.8)
				swing_velocity = clampf(swing_velocity, -1.2, 1.2)
				swing = clampf(swing + swing_velocity * delta, -0.45, 0.45)
			if p.chain == null and cooldown == 0 and Input.is_action_pressed("climb_up"):
				var body := p.position + Vector2(0, -14)
				var segment := tip() - global_position
				var ratio := clampf((body - global_position).dot(segment) / segment.length_squared(), 0.12, 1.0)
				if body.distance_to(global_position + segment * ratio) < 24:
					p.chain = self
					rider = p
					p.chain_distance = ratio * length
	queue_redraw()

func _draw() -> void:
	if collected:
		return
	match kind:
		"double": Elements.charge(self)
		"bait", "key": Elements.charge(self,true)
		"pad":
			Elements.surface(self,Rect2(-22,-10,44,10),Elements.Kind.PLATFORM)
			draw_polyline(PackedVector2Array([Vector2(-10,-3),Vector2(-4,-7),Vector2(2,-3),Vector2(8,-7)]),Elements.BRASS,2)
		"chain":
			var end := tip() - global_position
			for i in range(0, int(length), 12):
				var at := end * (float(i) / length)
				draw_arc(at, 5, 0, TAU, 8, Elements.STEEL_LIGHT, 2)
			draw_rect(Rect2(-8,-8,16,10), Elements.STEEL_DARK)
