extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func screenshot(name: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + name + ".png")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://capture_records.json"
	root.size = Vector2i(1280, 720)
	await screenshot("title")
	game.start_run()
	game.player.respawn(Vector2(920, 416))
	for i in range(120):
		await physics_frame
	await screenshot("gameplay")
	game.pause_game()
	await screenshot("pause")
	game.resume_game()
	game.elapsed = 54.28
	game.run_deaths = 7
	game.finish_run()
	await screenshot("clear")
	game.show_menu()
	game.show_records()
	await screenshot("records")
	game.queue_free()
	await process_frame
	call_deferred("quit")
