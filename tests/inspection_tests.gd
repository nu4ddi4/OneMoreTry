extends SceneTree

var game: OneMoreGame
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if condition: print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
func frames(count: int) -> void:
	for n in count:
		await physics_frame
		await process_frame
func hotkey(ctrl: bool, shift: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	key.ctrl_pressed = ctrl
	key.shift_pressed = shift
	return key
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_inspection_records.json"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://inspection-test-normal.json"
	game.start_run()
	await frames(4)
	var tools := game.inspector
	check(not tools.active and tools.dialog == null, "Normal startup has no visible inspection controls")
	check(not tools.teleport(Vector2(1000,416)) and not tools.go_to_room(24), "Movement tools cannot run before explicit activation")
	tools.set_flying(true)
	check(not tools.flying and game.player.is_physics_processing(), "Flight cannot silently enable in a normal run")
	tools._input(hotkey(false,false))
	tools._input(hotkey(true,false))
	tools._input(hotkey(false,true))
	check(not tools.active, "F8 requires both Ctrl and Shift")
	tools._input(hotkey(true,true))
	check(tools.active and tools.is_open() and game.mode == OneMoreGame.Mode.PAUSED, "The full shortcut opens and pauses inspection")
	check(game.records.path == "user://test_inspection_records.json" and tools.normal_records.path == "user://inspection-test-normal.json", "Inspection uses a separate record store")
	var normal_hash := FileAccess.get_sha256(tools.normal_records.path)
	var p := game.player.position
	var elapsed := game.elapsed
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	check(game.player.position == p and game.elapsed == elapsed, "Opening the panel freezes the current run")
	tools.close_panel()
	check(game.mode == OneMoreGame.Mode.PLAYING, "Closing the panel resumes an active run")
	tools.show_panel()
	tools.dialog.canceled.emit()
	check(not tools.is_open() and game.mode == OneMoreGame.Mode.PLAYING, "Dialog cancellation restores the previous run mode")
	tools.show_panel()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	tools.dialog.window_input.emit(escape)
	check(not tools.is_open() and game.mode == OneMoreGame.Mode.PLAYING, "Escape received inside the dialog resumes the run")
	for number in range(1,41):
		check(tools.go_to_room(number), "Room %02d can be selected" % number)
		await frames(2)
		var wanted := TryCourse.origin(number) + (100 if number == 1 else 64)
		check(game.player.alive and absf(game.player.position.x-wanted) < 1 and absf(game.player.position.y-416) < 1 and game.spawn_point.x == wanted, "Room %02d has a live restartable entry" % number)
	check(game.traps[38].auxiliary == 0 and game.traps[38].clock > 0.57, "Final encounter includes the preceding fake-door clock")
	game.player.die("retry")
	await frames(52)
	check(game.player.alive and game.traps[38].auxiliary == 0, "Finale timing is also restored after a retry")
	check(not tools.go_to_room(0) and not tools.go_to_room(41), "Unknown room numbers are rejected")
	for target in [Vector2(NAN,416),Vector2(INF,0),Vector2(-1,0),Vector2(TryCourse.LENGTH + 1,0),Vector2(10,5000)]:
		check(not tools.teleport(target), "Invalid coordinates cannot enter movement state")
	tools.go_to_room(24)
	tools.set_flying(true)
	check(tools.flying and not game.player.is_physics_processing() and game.player.get_meta("inspection_invincible"), "Flight disables physical movement and enables temporary immunity")
	elapsed = game.elapsed
	p = game.player.position
	Input.action_press("move_right")
	Input.action_press("climb_up")
	await frames(24)
	Input.action_release("move_right")
	Input.action_release("climb_up")
	check(game.player.position.x > p.x + 70 and game.player.position.y < p.y - 70, "Free flight moves on both axes with real controls")
	check(game.elapsed == elapsed, "Free flight does not advance the scored run")
	check(absf(game.camera.position.y - (game.player.position.y - 146)) < 1, "The camera follows vertical free movement")
	check(tools.teleport(Vector2(15000,-900)) and game.player.position == Vector2(15000,-900), "Coordinate travel reaches arbitrary height")
	await frames(3)
	check(game.player.alive and game.player.position.y < -899, "Flight remains stable above the normal camera range")
	tools.teleport(Vector2(TryWorld.GOAL,416))
	await frames(3)
	check(game.mode == OneMoreGame.Mode.PLAYING, "Flying over the real exit cannot award a clear")
	tools.show_panel()
	p = game.player.position
	Input.action_press("climb_down")
	await frames(8)
	Input.action_release("climb_down")
	check(game.player.position == p, "A visible panel also freezes free flight")
	tools.set_flying(false)
	check(game.mode == OneMoreGame.Mode.PAUSED and game.player.is_physics_processing(), "Turning off flight in the panel keeps the world paused")
	tools.go_to_room(24)
	tools.invulnerable.button_pressed = true
	var deaths: int = game.run_deaths
	game.player.die("hazard")
	check(game.player.alive and game.run_deaths == deaths, "Optional immunity blocks hazards")
	game.player.die("retry")
	await frames(52)
	check(game.player.alive and game.run_deaths == deaths + 1, "Manual retry still works with immunity enabled")
	tools.invulnerable.button_pressed = false
	game.player.die("hazard")
	check(not game.player.alive, "Disabling immunity restores real deaths")
	await frames(52)
	check(absf(game.player.position.x - game.spawn_point.x) < 1, "Inspection death returns to the selected room")
	tools.set_flying(true)
	tools.freeze_world.button_pressed = false
	tools.teleport(Vector2(TryCourse.origin(24) + 160,416))
	await frames(8)
	check(game.traps[23].clock > 0, "Unfreezing devices allows encounter simulation during flight")
	tools.freeze_world.button_pressed = true
	var clock: float = game.traps[23].clock
	await frames(10)
	check(game.traps[23].clock == clock, "Device freeze stops encounter timers")
	tools.set_flying(false)
	tools.teleport(Vector2(TryWorld.GOAL,416))
	await frames(3)
	check(game.mode == OneMoreGame.Mode.CLEAR, "Normal physical inspection can verify the real clear")
	game.save_records()
	check(FileAccess.get_sha256(tools.normal_records.path) == normal_hash, "Inspection movement, retries and clears never overwrite legitimate records")
	check(game.records.path != tools.normal_records.path, "Closing the panel never switches cheated progress back to normal records")
	game.queue_free()
	await process_frame
	for path in ["user://inspection-test-normal.json","user://test_inspection_records.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Inspection: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
