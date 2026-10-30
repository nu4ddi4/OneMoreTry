extends SceneTree

var game: OneMoreGame
var failed := false

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func move_to(x: float) -> void:
	if failed:
		return
	Input.action_press("move_right")
	for i in 2400:
		await frames(1)
		if game.mode == OneMoreGame.Mode.CLEAR:
			return
		if game.run_deaths > 0:
			failed = true
			push_error("Playthrough died at x=%.1f heading to %.1f" % [game.player.position.x, x])
			return
		if game.player.position.x >= x:
			return
	failed = true
	push_error("Playthrough got stuck at x=%.1f heading to %.1f" % [game.player.position.x, x])

func jump_to(x: float, stop: bool = false) -> void:
	Input.action_press("jump")
	await move_to(x)
	if stop:
		Input.action_release("move_right")
		# Keep holding jump through landing, then release. No re-trigger on hold.
		await frames(95)
	Input.action_release("jump")
	await frames(2)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://playthrough_records.json"
	game.start_run()
	await frames(8)
	await move_to(620)
	await jump_to(830)
	await move_to(965)
	await jump_to(1155)
	await move_to(1650)
	await jump_to(1852)
	await jump_to(1970, true)
	print("First ledge: ", game.player.position)
	await jump_to(2080, true)
	print("Secret ledge: ", game.player.position)
	await move_to(2635)
	await jump_to(2820)
	await move_to(2900)
	await jump_to(3100)
	await move_to(3125)
	await jump_to(3320)
	await move_to(3380)
	await frames(4)
	if game.mode != OneMoreGame.Mode.CLEAR or game.run_deaths != 0 or game.checkpoint_index != 1 or not game.secret_collected:
		failed = true
		push_error("Expected clear, zero deaths, both checkpoints and secret. Got mode=%d deaths=%d checkpoint=%d secret=%s" % [game.mode, game.run_deaths, game.checkpoint_index, game.secret_collected])
	print("FULL PLAYTHROUGH: %s | %s | deaths=%d | secret=%s" % ["FAIL" if failed else "PASS", OneMoreGame.format_time(game.elapsed), game.run_deaths, game.secret_collected])
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playthrough_records.json"))
	call_deferred("quit", 1 if failed else 0)
