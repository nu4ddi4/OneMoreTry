extends SceneTree

var game: OneMoreGame
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func place(at: Vector2) -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("jump")
	game.player.respawn(at)
	await frames(4)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	check(game.mode == OneMoreGame.Mode.MENU, "Title screen is the initial state")
	check(game.traps.size() == 14, "Stage contains all authored traps")
	game.start_run()
	await frames(5)
	check(game.player.is_on_floor(), "Player settles on the solid start ground")
	check(game.player.alive, "New run starts alive")
	var x := game.player.position.x
	Input.action_press("move_right")
	await frames(24)
	check(game.player.position.x > x + 20, "Right input moves the actual physics body")
	Input.action_release("move_right")
	await place(Vector2(200, 416))
	Input.action_press("jump")
	await frames(3)
	check(game.player.velocity.y < -300, "Jump launches upwards")
	Input.action_release("jump")
	var min_y := game.player.position.y
	for i in 100:
		await frames(1)
		min_y = minf(min_y, game.player.position.y)
	var short_height := 416 - min_y
	await place(Vector2(200, 416))
	Input.action_press("jump")
	min_y = 416
	for i in 100:
		await frames(1)
		min_y = minf(min_y, game.player.position.y)
	Input.action_release("jump")
	check(416 - min_y > short_height + 25, "Held jump travels materially higher than a tapped jump")
	check(game.player.is_on_floor(), "Player lands without sinking or jitter")
	Input.action_press("jump")
	await frames(5)
	Input.action_release("jump")
	await frames(1)
	var airborne_speed := game.player.velocity.y
	Input.action_press("jump")
	await frames(1)
	check(game.player.velocity.y > airborne_speed - 30, "No double jump is available")
	Input.action_release("jump")
	await place(Vector2(2264, 354))
	Input.action_press("move_right")
	await frames(15)
	check(not game.player.is_on_floor() and game.player.coyote > 0, "Leaving a ledge preserves a short coyote window")
	Input.action_press("jump")
	await frames(2)
	check(game.player.velocity.y < -350, "Coyote jump works just after leaving a ledge")
	Input.action_release("jump")
	Input.action_release("move_right")
	game.player.respawn(Vector2(200, 408))
	game.player.velocity.y = 200
	await frames(1)
	Input.action_press("jump")
	await frames(10)
	check(game.player.velocity.y < -250 and game.player.position.y < 405, "Buffered jump executes when landing shortly after input")
	Input.action_release("jump")
	await place(Vector2(30, 416))
	Input.action_press("move_left")
	await frames(35)
	check(game.player.position.x >= 9, "Solid left boundary prevents leaving the stage")
	Input.action_release("move_left")
	await place(Vector2(660, 416))
	await frames(4)
	check(game.traps[0].state == 1, "Standing on the cracked bridge arms its collapse")
	await frames(33)
	check(game.traps[0].state == 2 and game.traps[0].body_shape.disabled, "Collapse removes collision after its warning")
	await place(Vector2(900, 416))
	check(game.traps[3].state == 1, "Approaching the spring spikes gives a warning")
	await frames(55)
	check(game.traps[3].state == 2, "Spring spikes extend after deterministic delay")
	await place(Vector2(1038, 416))
	await frames(2)
	check(not game.player.alive, "Extended spikes are lethal")
	var deaths := game.run_deaths
	game.player.die("duplicate")
	check(game.run_deaths == deaths, "Repeated hazard contacts count only one death")
	await frames(55)
	check(game.player.alive and game.player.position.distance_to(game.spawn_point) < 4, "Automatic respawn occurs within 0.5 seconds")
	check(game.traps[3].state == 0, "Death resets trap state")
	check(game.traps[0].state == 0 and not game.traps[0].body_shape.disabled, "Collapsed platform collision is restored on respawn")
	await place(Vector2(1180, 416))
	check(game.traps[4].state == 1 and game.traps[4].fall_offset == 0, "Falling block warns before dropping")
	await frames(135)
	check(game.traps[4].state == 2 and is_equal_approx(game.traps[4].fall_offset, 218), "Falling block lands at the authored floor height")
	await place(Vector2(1250, 416))
	check(not game.player.alive, "Dropped block is lethal on contact")
	await frames(55)
	deaths = game.run_deaths
	await place(Vector2(1460, 416))
	check(game.checkpoint_index == 0, "First checkpoint activates on actual ground contact")
	var saved_spawn := game.spawn_point
	game.player.die("checkpoint test")
	await frames(55)
	check(game.player.alive and game.player.position.distance_to(saved_spawn) < 4, "Death returns to the activated checkpoint")
	check(game.checkpoint_index == 0, "Checkpoint survives a death")
	var retry := InputEventAction.new()
	retry.action = "retry"
	retry.pressed = true
	game._unhandled_input(retry)
	await frames(2)
	check(game.player.alive and game.run_deaths == deaths + 2, "R retries immediately and counts one failure")
	game.pause_game()
	var paused_time := game.elapsed
	var paused_position := game.player.position
	var trap_clock := game.traps[3].clock
	Input.action_press("move_right")
	await frames(35)
	check(game.elapsed == paused_time and game.player.position == paused_position, "Pause stops both time and movement")
	check(game.traps[3].clock == trap_clock, "Pause also freezes trap clocks")
	Input.action_release("move_right")
	game.resume_game()
	await frames(3)
	check(game.elapsed > paused_time, "Resume restarts the timer")
	await place(Vector2(2380, 416))
	check(game.checkpoint_index == 1, "Second checkpoint activates")
	await place(Vector2(1460, 416))
	check(game.checkpoint_index == 1, "Backtracking does not replace a newer checkpoint")
	await place(Vector2(2089, 296))
	check(game.secret_collected and game.records.data.secret, "Hidden star unlocks its persistent discovery")
	await place(Vector2(TryWorld.GOAL, 416))
	await frames(3)
	check(game.mode == OneMoreGame.Mode.CLEAR, "Entering the real exit completes the stage")
	check(game.records.data.clears == 1 and game.records.data.best_time > 0, "Clear stores a personal best and clear count")
	var clear_count: int = game.records.data.clears
	game.finish_run()
	check(game.records.data.clears == clear_count, "Clear callback cannot award duplicate results")
	var loaded := TryRecords.new(true)
	loaded.load_records()
	check(loaded.data.deaths == game.records.data.deaths and loaded.data.secret, "Saved records survive loading into a fresh store")
	check(is_equal_approx(loaded.data.best_time, game.records.data.best_time), "Personal best round-trips through JSON")
	var corrupt := FileAccess.open(loaded.path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	var recovered := TryRecords.new(true)
	recovered.load_records()
	check(recovered.data.deaths == 0 and not recovered.last_error.is_empty(), "Malformed save is handled without a crash")
	game.start_run()
	await frames(5)
	check(game.checkpoint_index == -1 and game.run_deaths == 0 and not game.secret_collected, "New run resets its checkpoint, deaths and stage secret")
	check(game.records.data.clears == 1, "New run preserves lifetime records")
	# A full no-teleport traversal with normal movement/jump inputs is run separately.
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_records.json"))
	print("\nRESULT: %d checks, %d failures" % [checks, failures])
	call_deferred("quit", 1 if failures else 0)
