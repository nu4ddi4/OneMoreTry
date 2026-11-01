extends SceneTree

var game: OneMoreGame

func _initialize() -> void:
	if "--test" not in OS.get_cmdline_user_args():
		push_error("Use: godot --headless --fixed-fps 120 --script tools/probe_jumps.gd -- --test")
		quit(1)
		return
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://jump_design_probe.json"
	print("Hold frames | Apex px | Span px | Flight frames")
	for hold_frames in [1, 6, 12, 20, 45]:
		# Each experiment starts on the same flat ground; no authored traps are reached.
		game.start_run()
		game.player.respawn(Vector2(200, 416))
		Input.action_press("move_right")
		await frames(20)
		var start_x: float = game.player.position.x
		var min_y := 416.0
		var flight_frames := 0
		Input.action_press("jump")
		for i in 150:
			if i == hold_frames:
				Input.action_release("jump")
			await frames(1)
			flight_frames += 1
			min_y = minf(min_y, game.player.position.y)
			if i > 1 and game.player.is_on_floor():
				break
		print("%d | %.1f | %.1f | %d" % [hold_frames, 416 - min_y, game.player.position.x - start_x, flight_frames])
		Input.action_release("jump")
		Input.action_release("move_right")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://jump_design_probe.json"))
	quit()
