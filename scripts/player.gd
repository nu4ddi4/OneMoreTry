class_name TryPlayer
extends CharacterBody2D

const Art = preload("res://scripts/pixel_art.gd")
const PlayerArt = preload("res://scripts/player_art.gd")
const Elements = preload("res://scripts/elements.gd")

signal died(reason: String)
signal jumped
signal landed(speed: float)

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
var stride_distance := 0.0
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
	collision_layer = Elements.PLAYER_LAYER
	collision_mask = Elements.SOLID_LAYER
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

func grip_wall_normal() -> Vector2:
	if not is_on_wall(): return Vector2.ZERO
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var body = contact.get_collider()
		if absf(contact.get_normal().x) > 0.7 and body is Node and body.is_in_group(&"climbable_walls"):
			return contact.get_normal()
	return Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not enabled or not alive:
		queue_redraw()
		return
	animation_time += delta
	land_squash = move_toward(land_squash, 0.0, delta * 5)
	false_impact = maxf(0, false_impact - delta)
	wall_lock = maxf(0, wall_lock - delta)
	var direction := Input.get_axis("move_left", "move_right")
	var fresh_jump := Input.is_action_just_pressed("jump")
	if chain:
		if fresh_jump:
			var inherited := chain.release_velocity(chain_distance)
			detach_chain()
			launch()
			velocity.x = clampf(direction * SPEED + inherited.x, -390, 390)
			wall_lock = 0.12
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
	var wall_normal := grip_wall_normal()
	var wall := wall_normal != Vector2.ZERO
	if jump_buffer > 0 and coyote > 0:
		launch()
	elif fresh_jump and wall:
		launch()
		velocity.x = wall_normal.x * 290
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
	if wall and wall_lock == 0 and direction * wall_normal.x < 0:
		if Input.is_action_pressed("climb_up"):
			velocity.y = minf(velocity.y, -140)
		elif velocity.y > 65:
			velocity.y = 65
	if velocity.y > 0:
		floor_snap_length = 5
	last_vertical_speed = velocity.y
	var before_move := position
	move_and_slide()
	if is_on_floor() and absf(velocity.x) > 12:
		stride_distance = fposmod(stride_distance + absf(position.x - before_move.x), 48)
	else:
		stride_distance = 0
	carrier = null
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var collider = contact.get_collider()
		if collider is TrySurface:
			if collider.lethal:
				die("hazard")
				if not alive: return
			elif is_on_floor() and contact.get_normal().y < -0.7:
				carrier = collider
	if is_on_floor() and not was_grounded:
		land_squash = clampf(last_vertical_speed / 1800.0, 0.1, 0.35)
		landed.emit(last_vertical_speed)
	was_grounded = is_on_floor()
	if position.y > 620:
		die("fall")
	queue_redraw()

func die(reason: String) -> void:
	if not alive or not enabled or (reason != "retry" and bool(get_meta("inspection_invincible", false))):
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
	animation_time = 0
	stride_distance = 0
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
	var look := facing
	var bob := 0.0
	var feet := [0, 0, 0, 0]
	var hands := [Vector2(-12, -14), Vector2(10, -14)]
	if chain:
		var grip := Art.snap(chain.tip(chain_distance) + Vector2(0, -14) - global_position)
		hands = [Vector2(grip.x * look - 4, grip.y), Vector2(grip.x * look, grip.y - 4)]
		var step := 2 if int(chain_distance / 10) % 2 == 0 else 4
		feet = [-2, 2, -step, -6 + step]
	elif enabled and not is_on_floor():
		var wall_normal := grip_wall_normal()
		if wall_normal.x != 0 and velocity.y >= -160:
			look = -wall_normal.x
			hands = [Vector2(8, -24), Vector2(8, -16)]
			feet = [0, 2, -6, -2]
		elif velocity.y < -90:
			hands = [Vector2(-12, -18), Vector2(10, -22)]
			feet = [2, -2, -2, -6]
		elif velocity.y <= 90:
			hands = [Vector2(-14, -16), Vector2(12, -18)]
			feet = [2, -2, -6, -4]
		else:
			hands = [Vector2(-14, -20), Vector2(12, -22)]
			feet = [0, -2, 0, -2]
	elif land_squash > 0.10 and enabled:
		bob = clampf(snappedf(land_squash * 12, Art.DOT), 0, 4)
		hands = [Vector2(-14, -16), Vector2(12, -16)]
	elif is_on_floor() and absf(velocity.x) > 12:
		var frame := int(stride_distance / 8)
		feet = PlayerArt.RUN_FEET[frame]
		bob = PlayerArt.RUN_BOB[frame]
		hands = [Vector2(-10 + feet[0], -14), Vector2(8 + feet[1], -14)]
	PlayerArt.draw_pose(self, look, bob, feet, hands, air_jumps > 0)
