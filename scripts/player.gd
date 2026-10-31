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

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20, 28)
	shape.shape = box
	shape.position = Vector2(0, -14)
	add_child(shape)
	floor_snap_length = 5.0

func _physics_process(delta: float) -> void:
	animation_time += delta
	land_squash = move_toward(land_squash, 0.0, delta * 5)
	if not enabled or not alive:
		queue_redraw()
		return
	coyote = COYOTE_TIME if is_on_floor() else maxf(0, coyote - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = BUFFER_TIME
	if jump_buffer > 0 and coyote > 0:
		velocity.y = JUMP_SPEED
		coyote = 0
		jump_buffer = 0
		jump_cut_available = true
		floor_snap_length = 0
		jumped.emit()
	# Read held state on resume as well: a release edge can occur while paused.
	if jump_cut_available and not Input.is_action_pressed("jump") and velocity.y < 0:
		velocity.y *= 0.46
		jump_cut_available = false
	if velocity.y >= 0:
		jump_cut_available = false
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, direction * SPEED, (2100.0 if is_on_floor() else 1500.0) * delta)
	if direction != 0:
		facing = direction
	velocity.y += GRAVITY * delta
	if velocity.y > 0:
		floor_snap_length = 5
	move_and_slide()
	if is_on_floor() and not was_grounded:
		land_squash = 0.2
	was_grounded = is_on_floor()
	if position.y > 580:
		die("발밑도 가끔은 의심해 보세요.")
	queue_redraw()

func die(reason: String) -> void:
	if not alive or not enabled:
		return
	alive = false
	velocity = Vector2.ZERO
	died.emit(reason)
	queue_redraw()

func respawn(at: Vector2) -> void:
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
	if not alive:
		return
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
