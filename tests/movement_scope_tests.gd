extends "res://tests/gameplay_revision_tests.gd"

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://movement-scope-records.json"
	# Check the real narrow corridors: no change to either lateral blade's clock.
	for number in [3,5]:
		await reset(number)
		game.player.respawn(Vector2(TryCourse.origin(number)+230,416))
		await ticks(4)
		var trap: TryEncounter = game.traps[number-1]
		var roof: Rect2 = trap.hazards[0]
		var gap := game.player.position.y - TryElements.PLAYER_VISUAL_HEIGHT - roof.end.y
		check(game.player.alive and gap >= 6 and gap <= 12, "Lateral corridor %d leaves only a small visible standing gap" % number)
		check(trap.definition.sensor == (208.0 if number == 3 else 112.0), "Lateral corridor %d retains its original activation position" % number)
		Input.action_press("jump")
		await ticks(2)
		Input.action_release("jump")
		await ticks(12)
		check(game.run_deaths > 0, "Even a tapped jump still hits corridor %d's low roof" % number)
	# The actual map tags only the deliberate climbing pillar, not a whole room.
	await reset(14)
	var walls := get_nodes_in_group(&"climbable_walls")
	check(walls.size() == 1 and game.world.climbable_ledges == [Rect2(TryCourse.origin(14)+344,224,32,192)], "Only the required pillar is climbable; adjacent terrain and gates are ordinary")
	Input.action_press("move_right")
	Input.action_press("climb_up")
	game.player.respawn(Vector2(TryCourse.origin(14)+330,416))
	await ticks(60)
	check(game.player.alive and game.player.position.y < 360 and game.player.grip_wall_normal().x < -0.7, "The marked pillar still supports real upward climbing")
	Input.action_press("jump")
	await ticks(2)
	check(game.player.velocity.x < -200 and game.player.velocity.y < -300, "The marked pillar retains its deliberate wall jump")
	Input.action_release("jump")
	# Same tall geometry at an ordinary safe location, using real physics/input.
	await reset(1)
	for trap in game.traps: trap.set_physics_process(false)
	var wall := StaticBody2D.new()
	wall.collision_layer = TryElements.SOLID_LAYER
	wall.collision_mask = TryElements.PLAYER_LAYER
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24,256)
	shape.shape = box
	shape.position = Vector2(662,288)
	wall.add_child(shape)
	game.add_child(wall)
	game.player.respawn(Vector2(636,416))
	Input.action_press("move_right")
	Input.action_press("climb_up")
	await ticks(45)
	check(game.player.is_on_wall() and game.player.position.y > 415 and game.player.grip_wall_normal() == Vector2.ZERO, "Holding up against an ordinary wall cannot climb or inherit the previous pillar's permission")
	Input.action_press("jump")
	await ticks(24)
	Input.action_release("jump")
	await ticks(25)
	check(game.player.is_on_wall() and game.player.velocity.y > 65, "An ordinary wall does not grant a slow wall slide")
	var height := game.player.position.y
	Input.action_press("jump")
	await ticks(2)
	check(game.player.position.y >= height and game.player.velocity.y > 0 and absf(game.player.velocity.x) < 1, "Repeated jump input on an ordinary wall cannot grant a free wall jump")
	Input.action_release("jump")
	game.player.air_jumps = 1
	await ticks(2)
	Input.action_press("jump")
	await ticks(2)
	check(game.player.air_jumps == 0 and game.player.velocity.y < -400 and absf(game.player.velocity.x) < 1, "A real midair charge still works beside an ordinary wall and is consumed")
	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_release("climb_up")
	game.pause_game()
	await ticks(4)
	game.resume_game()
	check(not wall.is_in_group(&"climbable_walls") and game.player.grip_wall_normal() == Vector2.ZERO, "Pause and resume do not unlock an ordinary wall")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://movement-scope-records.json"))
	print("Movement scope: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
