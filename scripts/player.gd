class_name TryPlayer
extends CharacterBody2D

signal died(reason: String)
signal jumped

const SPEED := 250.0
const JUMP_SPEED := -480.0
const GRAVITY := 1300.0
const COYOTE_TIME := 0.10
const BUFFER_TIME := 0.12

var alive := true
var enabled := false
var facing := 1.0
var coyote := 0.0
var jump_buffer := 0.0
var jump_cut_available := false
var animation_time := 0.0
var land_squash := 0.0
var was_grounded := false
var air_jumps := 0
var carrier: TrySurface
var chain: TryDevice
var chain_distance := 180.0
var wall_lock := 0.0
var last_vertical_speed := 0.0
var false_impact := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	platform_floor_layers = 0
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20, 28)
	shape.shape = box
	shape.position = Vector2(0, -14)
	add_child(shape)
	floor_snap_length = 5.0

func launch(speed: float = JUMP_SPEED) -> void:
	velocity.y = speed
	coyote = 0
	jump_buffer = 0
	jump_cut_available = speed == JUMP_SPEED
	floor_snap_length = 0
	carrier = null
	jumped.emit()

func detach_chain() -> void:
	if chain:
		chain.cooldown = 0.25
		chain.rider = null
	chain = null

func _physics_process(delta: float) -> void:
	animation_time += delta
	land_squash = move_toward(land_squash, 0.0, delta * 5)
	if not enabled or not alive:
		queue_redraw()
		return
	false_impact = maxf(0, false_impact - delta)
	wall_lock = maxf(0, wall_lock - delta)
	var direction := Input.get_axis("move_left", "move_right")
	var fresh_jump := Input.is_action_just_pressed("jump")
	if chain:
		if fresh_jump:
			detach_chain()
			velocity.x = direction * SPEED
			launch()
			fresh_jump = false
		else:
			chain_distance = clampf(chain_distance + Input.get_axis("climb_up", "climb_down") * delta * 150, 32, chain.length)
			position = chain.tip(chain_distance) + Vector2(0, 14)
			velocity = Vector2.ZERO
			carrier = null
			queue_redraw()
			return
	if is_instance_valid(carrier) and carrier.active and is_on_floor():
		position += carrier.motion_step
		position.x += carrier.belt_speed * delta
	coyote = COYOTE_TIME if is_on_floor() and velocity.y >= 0 else maxf(0, coyote - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if fresh_jump:
		jump_buffer = BUFFER_TIME
	var wall := is_on_wall()
	if jump_buffer > 0 and coyote > 0:
		launch()
	elif fresh_jump and wall:
		var normal := get_wall_normal().x
		launch()
		velocity.x = normal * 290
		wall_lock = 0.16
	elif fresh_jump and air_jumps > 0:
		air_jumps -= 1
		launch()
	if jump_cut_available and not Input.is_action_pressed("jump") and velocity.y < 0:
		velocity.y *= 0.46
		jump_cut_available = false
	if velocity.y >= 0:
		jump_cut_available = false
	if wall_lock == 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, (2100.0 if is_on_floor() else 1500.0) * delta)
	if direction != 0:
		facing = direction
	velocity.y += GRAVITY * delta
	if wall and wall_lock == 0 and direction * get_wall_normal().x < 0:
		if Input.is_action_pressed("climb_up"):
			velocity.y = -140
		elif velocity.y > 65:
			velocity.y = 65
	if velocity.y > 0:
		floor_snap_length = 5
	last_vertical_speed = velocity.y
	move_and_slide()
	carrier = null
	if is_on_floor():
		for index in get_slide_collision_count():
			var contact := get_slide_collision(index)
			if contact.get_normal().y < -0.7 and contact.get_collider() is TrySurface:
				carrier = contact.get_collider()
	if is_on_floor() and not was_grounded:
		land_squash = 0.2
	was_grounded = is_on_floor()
	if position.y > 620:
		die("fall")
	queue_redraw()

func die(reason: String) -> void:
	if not alive or not enabled:
		return
	alive = false
	detach_chain()
	carrier = null
	velocity = Vector2.ZERO
	died.emit(reason)
	queue_redraw()

func respawn(at: Vector2) -> void:
	detach_chain()
	carrier = null
	air_jumps = 0
	wall_lock = 0
	false_impact = 0
	position = at
	velocity = Vector2.ZERO
	coyote = 0
	jump_buffer = 0
	jump_cut_available = false
	alive = true
	was_grounded = false
	land_squash = 0.25
	queue_redraw()

func hitbox() -> Rect2:
	return Rect2(global_position + Vector2(-9, -27), Vector2(18, 26))

func _draw() -> void:
	if not alive or (false_impact > 0 and int(animation_time * 40) % 2 == 0):
		return
	if air_jumps > 0:
		draw_arc(Vector2(0, -19), 23, 0, TAU, 16, Color("80e5e099"), 2)
	var bob := 1 if is_on_floor() and absf(velocity.x) > 30 and sin(animation_time * 22) > 0 else 0
	var squat := int(land_squash * 10)
	draw_rect(Rect2(-13, -3, 26, 4), Color("254a493b"))
	draw_rect(Rect2(-12, -31 + squat, 24, 26 - squat), Color("233b43"))
	draw_rect(Rect2(-10, -33 + squat + bob, 20, 27 - squat), Color("6ed6b0"))
	draw_rect(Rect2(-7, -37 + squat + bob, 5, 6), Color("6ed6b0"))
	draw_rect(Rect2(3, -37 + squat + bob, 5, 6), Color("6ed6b0"))
	draw_rect(Rect2(-9, -25 + squat + bob, 18, 14), Color("fff2d3"))
	var look := int(facing * 2)
	draw_rect(Rect2(-6 + look, -22 + squat + bob, 3, 5), Color("233b43"))
	draw_rect(Rect2(2 + look, -22 + squat + bob, 3, 5), Color("233b43"))
	draw_rect(Rect2(-2 + look, -14 + squat + bob, 4, 2), Color("d68c73"))
	draw_rect(Rect2(-13, -13 + squat, 5, 6), Color("6ed6b0"))
	draw_rect(Rect2(8, -13 + squat, 5, 6), Color("6ed6b0"))
	var stride := 3 if absf(velocity.x) > 30 and sin(animation_time * 22) > 0 else 0
	draw_rect(Rect2(-10, -7, 7, 7 - stride), Color("233b43"))
	draw_rect(Rect2(3, -7, 7, 4 + stride), Color("233b43"))
