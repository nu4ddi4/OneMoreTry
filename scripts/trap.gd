class_name TryTrap
extends Node2D

enum Kind { CRUMBLE, SPRING, FALLING, SPIKES }

var kind: Kind = Kind.CRUMBLE
var size := Vector2(48, 20)
var game: Node2D
var state := 0
var clock := 0.0
var fall_offset := 0.0
var fall_speed := 0.0
var body_shape: CollisionShape2D
var warning_time := 0.42

func _ready() -> void:
	if kind == Kind.CRUMBLE:
		var body := StaticBody2D.new()
		body_shape = CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = size
		body_shape.shape = shape
		body_shape.position = size / 2
		body.add_child(body_shape)
		add_child(body)

func reset() -> void:
	state = 0
	clock = 0
	fall_offset = 0
	fall_speed = 0
	if body_shape:
		body_shape.set_deferred("disabled", false)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not game or not game.interaction_enabled():
		return
	var p: TryPlayer = game.player
	var box := p.hitbox()
	match kind:
		Kind.CRUMBLE:
			if state == 0 and p.is_on_floor() and absf(p.position.y - position.y) < 5 and p.position.x > position.x - 9 and p.position.x < position.x + size.x + 9:
				state = 1
				game.sound.effect("crumble")
			if state == 1:
				clock += delta
				if clock >= 0.24:
					state = 2
					body_shape.set_deferred("disabled", true)
			if state == 2:
				fall_speed += delta * 800
				fall_offset += fall_speed * delta
		Kind.SPRING:
			if state == 0 and p.position.x > position.x - 122 and p.position.x < position.x + size.x + 30:
				state = 1
				game.sound.effect("warning")
			if state == 1:
				clock += delta
				if clock >= warning_time:
					state = 2
					game.sound.effect("trap")
			if state == 2 and box.intersects(Rect2(position + Vector2(5, -25), Vector2(size.x - 10, 25))):
				p.die("금 간 바닥에서 가시가 올라옵니다!")
		Kind.FALLING:
			if state == 0 and p.position.x > position.x - 95 and p.position.x < position.x + size.x + 50:
				state = 1
				game.sound.effect("warning")
			if state == 1:
				clock += delta
				if clock >= 0.5:
					state = 2
			if state == 2:
				fall_speed += delta * 1500
				fall_offset = minf(fall_offset + fall_speed * delta, 416 - position.y - size.y)
				if box.intersects(Rect2(position + Vector2(3, fall_offset + 3), size - Vector2(6, 6))):
					p.die("물음표 아래에서는 잠깐 멈춰 보세요.")
		Kind.SPIKES:
			if box.intersects(Rect2(position + Vector2(4, -20), Vector2(size.x - 8, 19))):
				p.die("가시는 눈으로 보고, 점프로 넘고!")
	queue_redraw()

func _draw() -> void:
	match kind:
		Kind.CRUMBLE:
			if fall_offset > 200:
				return
			var offset := Vector2(1 if state == 1 and int(clock * 50) % 2 else 0, int(fall_offset))
			draw_rect(Rect2(offset, size), Color("c38c65"))
			draw_rect(Rect2(offset, Vector2(size.x, 5)), Color("d6ba86"))
			draw_rect(Rect2(offset + Vector2(2, 7), Vector2(size.x - 4, 2)), Color("785b50"))
			draw_line(offset + Vector2(18, 1), offset + Vector2(24, 9), Color("72564c"), 2)
			draw_line(offset + Vector2(24, 9), offset + Vector2(20, 17), Color("72564c"), 2)
			draw_rect(Rect2(offset + Vector2(size.x - 2, 0), Vector2(2, size.y)), Color("785b50"))
		Kind.SPRING:
			draw_rect(Rect2(0, -3, size.x, 5), Color("674c53"))
			for i in range(int(size.x / 16)):
				draw_rect(Rect2(i * 16 + 5, -4, 6, 3), Color("ec866f") if state != 0 else Color("b5846d"))
			if state == 1:
				draw_rect(Rect2(0, -7, size.x * (clock / warning_time), 3), Color("f6ba76"))
			if state == 2:
				_draw_spikes(size.x, 27)
		Kind.FALLING:
			if state < 2:
				draw_line(Vector2(size.x / 2, -80), Vector2(size.x / 2, 0), Color("57716e"), 3)
			var wiggle := 2.0 if state == 1 and int(clock * 35) % 2 else 0.0
			var at := Vector2(wiggle, int(fall_offset))
			draw_rect(Rect2(at, size), Color("3c555b"))
			draw_rect(Rect2(at + Vector2(3, 3), size - Vector2(6, 6)), Color("e5b166"))
			draw_rect(Rect2(at + Vector2(7, 7), size - Vector2(14, 14)), Color("f4d08a"))
			for v in [Vector2(5, 5), Vector2(size.x - 8, 5), Vector2(5, size.y - 8), size - Vector2(8, 8)]:
				draw_rect(Rect2(at + v, Vector2(3, 3)), Color("785e48"))
			draw_rect(Rect2(at + Vector2(size.x / 2 - 7, 10), Vector2(14, 5)), Color("785e48"))
			draw_rect(Rect2(at + Vector2(size.x / 2 + 2, 15), Vector2(5, 10)), Color("785e48"))
			draw_rect(Rect2(at + Vector2(size.x / 2 - 2, 24), Vector2(5, 5)), Color("785e48"))
			draw_rect(Rect2(at + Vector2(size.x / 2 - 2, 34), Vector2(5, 5)), Color("785e48"))
		Kind.SPIKES:
			_draw_spikes(size.x, 24)

func _draw_spikes(width: float, height: float) -> void:
	for i in range(int(width / 16)):
		var x := i * 16.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 8, -height), Vector2(x + 16, 0)]), Color("734e59"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 3, -2), Vector2(x + 8, -height + 4), Vector2(x + 12, -2)]), Color("f69c87"))
