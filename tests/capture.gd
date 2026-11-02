extends SceneTree
var game: OneMoreGame
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func screenshot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + name + ".png")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://capture_records.json"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	await screenshot("title")
	game.start_run()
	game.player.respawn(Vector2(9 * 640 + 170,416))
	game.camera.position.x = game.player.position.x + 130
	Input.action_press("jump")
	await frames(7)
	Input.action_release("jump")
	await frames(50)
	Input.action_press("move_right")
	await frames(20)
	Input.action_press("jump")
	await frames(12)
	await screenshot("gameplay")
	Input.action_release("jump")
	Input.action_release("move_right")
	game.pause_game()
	await screenshot("pause")
	game.start_run()
	game.player.respawn(Vector2(13 * 640 + 330,416))
	game.camera.position.x = game.player.position.x + 130
	Input.action_press("move_right")
	Input.action_press("climb_up")
	await frames(70)
	await screenshot("wall")
	Input.action_release("move_right")
	Input.action_release("climb_up")
	game.start_run()
	var chain: TryDevice = game.traps[19].devices[0]
	game.player.respawn(chain.tip(180) + Vector2(0,14))
	game.camera.position.x = game.player.position.x + 100
	Input.action_press("climb_up")
	await frames(30)
	await screenshot("chain")
	Input.action_release("climb_up")
	game.start_run()
	game.player.respawn(Vector2(23 * 640 + 146,416))
	game.camera.position.x = game.player.position.x + 130
	Input.action_press("move_right")
	await frames(30)
	await screenshot("launch-pad")
	Input.action_release("move_right")
	game.elapsed = 138.40
	game.run_deaths = 7
	game.update_hud()
	game.finish_run()
	await screenshot("clear")
	game.show_menu()
	game.show_records()
	await screenshot("records")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_records.json"))
	quit()
