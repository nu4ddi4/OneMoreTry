class_name TryDevice
extends Node2D

var kind := "double"
var game: Node2D
var encounter: Node2D
var collected := false
var cooldown := 0.0
var clock := 0.0
var length := 224.0
var rider: TryPlayer

func _ready() -> void:
	process_physics_priority = 5

func reset() -> void:
	collected = false
	cooldown = 0
	clock = 0
	rider = null
	queue_redraw()

func tip(distance: float = -1) -> Vector2:
	var angle := sin(clock * 1.8) * 0.28
	return global_position + Vector2(sin(angle), cos(angle)) * (length if distance < 0 else distance)

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
		"double":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-12),Vector2(8,0),Vector2(0,12),Vector2(-8,0)]), Color("80e5e0"))
			draw_line(Vector2(-3, -5), Vector2(2, -1), Color("f7edcd"), 2)
		"bait", "key":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-10),Vector2(4,-3),Vector2(11,0),Vector2(4,4),Vector2(0,11),Vector2(-4,4),Vector2(-11,0),Vector2(-4,-3)]), Color("f3d38a"))
		"pad":
			draw_rect(Rect2(-22,-6,44,6), Color("8a6752"))
			draw_line(Vector2(-17,-7),Vector2(17,-7),Color("b9e0ad"),4)
		"chain":
			var end := tip() - global_position
			for i in range(0, int(length), 12):
				var at := end * (float(i) / length)
				draw_arc(at, 5, 0, TAU, 8, Color("5d7772"), 2)
			draw_rect(Rect2(-8,-8,16,10), Color("48635d"))
