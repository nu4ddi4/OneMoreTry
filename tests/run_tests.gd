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
	check(game.traps.size() == 40, "All forty course encounters are loaded")
	# Global mute must not replace the independent music/effects preferences.
	game.records.data.music = false
	game.records.data.sfx = true
	game.sound.music_on = false
	game.sound.sfx_on = true
	var mute := InputEventAction.new()
	mute.action = "mute"
	mute.pressed = true
	game._unhandled_input(mute)
	check(not game.records.data.music and game.records.data.sfx and game.records.data.get("muted", false), "Global mute preserves separate audio preferences")
	game.records.save()
	var muted_records := TryRecords.new(true)
	muted_records.load_records()
	check(muted_records.data.get("muted", false) and not muted_records.data.music and muted_records.data.sfx, "Global mute and individual audio preferences survive reload")
	game._unhandled_input(mute)
	check(not game.records.data.music and game.records.data.sfx and not game.records.data.get("muted", false), "Unmute restores the previous audio configuration")
	check(not game.sound.music_on and not game.sound.sfx_on, "Mute controls cannot enable audio in test mode")
	game.test_mode = false
	game.apply_audio_settings()
	check(not game.sound.music_on and game.sound.sfx_on, "Unmuted audio playback respects a disabled music preference")
	game.sound.effect("secret")
	check(game.sound.voices[0].playing, "Sound-effect fixture starts playback before muting")
	game._unhandled_input(mute)
	var any_voice_playing := false
	for voice in game.sound.voices:
		any_voice_playing = any_voice_playing or voice.playing
	check(not any_voice_playing, "Global mute immediately stops effects already playing")
	game.test_mode = true
	game._unhandled_input(mute)
	game.records.data.music = true
	game.records.data.sfx = true
	for encounter in game.traps:
		encounter.set_physics_process(false)
		for device in encounter.devices:
			device.set_physics_process(false)
	game.start_run()
	await frames(5)
	check(game.traps.size() == 40, "Continuous course contains forty distinct authored encounters")
	check(TryWorld.LENGTH == 25600 and TryWorld.CHECKPOINTS.size() == 2, "One long map has only two checkpoints")
	check(game.player.is_on_floor() and game.player.alive, "Player settles on real starting terrain")
	var x := game.player.position.x
	Input.action_press("move_right")
	await frames(24)
	check(game.player.position.x > x + 20, "Right input moves the physics body")
	Input.action_release("move_right")
	await place(Vector2(500, 416))
	Input.action_press("jump")
	await frames(3)
	check(game.player.velocity.y < -300, "Ground jump launches upwards")
	Input.action_release("jump")
	var min_y := game.player.position.y
	for i in 100:
		await frames(1)
		min_y = minf(min_y, game.player.position.y)
	var short_height := 416 - min_y
	await place(Vector2(500, 416))
	Input.action_press("jump")
	min_y = 416
	for i in 100:
		await frames(1)
		min_y = minf(min_y, game.player.position.y)
	Input.action_release("jump")
	check(416 - min_y > short_height + 25, "Held jump is higher than a tap")
	check(game.player.is_on_floor(), "Jump lands on physical terrain")
	await place(Vector2(500, 416))
	Input.action_press("jump")
	await frames(5)
	Input.action_release("jump")
	await frames(1)
	var airborne_speed := game.player.velocity.y
	Input.action_press("jump")
	await frames(1)
	check(game.player.velocity.y > airborne_speed - 30, "Air jump is unavailable without an item")
	Input.action_release("jump")
	game.player.air_jumps = 1
	await frames(1)
	Input.action_press("jump")
	await frames(1)
	check(game.player.velocity.y < -400 and game.player.air_jumps == 0, "Double-jump charge adds one genuine midair jump and is consumed")
	Input.action_release("jump")
	await frames(2)
	airborne_speed = game.player.velocity.y
	Input.action_press("jump")
	await frames(1)
	check(game.player.velocity.y > airborne_speed - 30, "Spent charge cannot provide a third jump")
	Input.action_release("jump")
	await place(Vector2(12 * 640 + 172, 368))
	Input.action_press("move_right")
	await frames(15)
	check(not game.player.is_on_floor() and game.player.coyote > 0, "Leaving a ledge preserves coyote time")
	Input.action_press("jump")
	await frames(2)
	check(game.player.velocity.y < -350, "Coyote jump launches after leaving a real ledge")
	Input.action_release("jump")
	Input.action_release("move_right")
	game.player.respawn(Vector2(500, 408))
	game.player.velocity.y = 200
	await frames(1)
	Input.action_press("jump")
	await frames(10)
	check(game.player.velocity.y < -250, "Buffered input jumps on landing")
	Input.action_release("jump")
	await place(Vector2(30, 416))
	Input.action_press("move_left")
	await frames(35)
	check(game.player.position.x >= 9, "Physical left boundary remains solid")
	Input.action_release("move_left")
	await place(Vector2(13 * 640 + 330, 416))
	Input.action_press("move_right")
	Input.action_press("climb_up")
	await frames(70)
	check(game.player.position.y < 360, "Holding toward a wall and up climbs its actual collision surface")
	game.player.launch(-760)
	await frames(1)
	check(game.player.velocity.y < -650, "Holding climb cannot weaken an upward launch")
	Input.action_press("jump")
	await frames(2)
	check(game.player.velocity.x < -200 and game.player.velocity.y < -300, "Wall jump keeps its launch while the climb key remains held")
	Input.action_release("climb_up")
	Input.action_release("jump")
	Input.action_release("move_right")
	await place(Vector2(500, 416))
	game.player.launch(-760)
	await frames(10)
	check(game.player.position.y < 360 and game.player.velocity.y < -500, "Jump-pad launch has its own higher uncut trajectory")
	game.pause_game()
	var paused_time := game.elapsed
	var paused_position := game.player.position
	Input.action_press("move_right")
	await frames(30)
	check(game.elapsed == paused_time and game.player.position == paused_position, "Pause freezes time and movement")
	Input.action_release("move_right")
	game.resume_game()
	await frames(2)
	check(game.elapsed > paused_time, "Resume restarts the run clock")
	await place(Vector2(500, 416))
	Input.action_press("jump")
	await frames(4)
	game.pause_game()
	var jump_velocity := game.player.velocity.y
	Input.action_release("jump")
	await frames(8)
	check(game.player.velocity.y == jump_velocity, "Jump release while paused does not advance physics")
	game.resume_game()
	await frames(1)
	check(game.player.velocity.y > jump_velocity * 0.6, "Released jump is cut on resume")
	var cut_velocity := game.player.velocity.y
	await frames(1)
	check(game.player.velocity.y < cut_velocity * 0.7, "Jump cut happens only once")
	await place(TryWorld.CHECKPOINTS[0])
	check(game.checkpoint_index == 0, "First sparse checkpoint activates through ground contact")
	var saved_spawn := game.spawn_point
	game.player.air_jumps = 1
	game.player.die("checkpoint test")
	var deaths := game.run_deaths
	game.player.die("duplicate")
	check(game.run_deaths == deaths, "Hazard overlap counts a death only once")
	await frames(55)
	check(game.player.alive and game.player.position.distance_to(saved_spawn) < 4, "Respawn returns to the last checkpoint within half a second")
	check(game.player.air_jumps == 0 and game.player.chain == null, "Death clears temporary mobility and chain attachment")
	await place(TryWorld.CHECKPOINTS[1])
	check(game.checkpoint_index == 1, "Second and final checkpoint activates")
	await place(TryWorld.CHECKPOINTS[0])
	check(game.checkpoint_index == 1, "Backtracking never replaces a newer checkpoint")
	var retry := InputEventAction.new()
	retry.action = "retry"
	retry.pressed = true
	game._unhandled_input(retry)
	await frames(2)
	check(game.player.alive, "Manual retry respawns immediately")
	await place(Vector2(TryWorld.GOAL, 416))
	await frames(3)
	check(game.mode == OneMoreGame.Mode.CLEAR, "Only the real final exit completes the continuous run")
	check(game.records.data.clears == 1 and game.records.data.best_time > 0, "Clear stores a course best and one clear")
	var clear_count: int = game.records.data.clears
	game.finish_run()
	check(game.records.data.clears == clear_count, "Clear cannot award duplicate results")
	var loaded := TryRecords.new(true)
	loaded.load_records()
	check(loaded.data.deaths == game.records.data.deaths and loaded.data.course == TryRecords.COURSE_ID, "Saved records survive loading into a fresh store")
	check(is_equal_approx(loaded.data.best_time, game.records.data.best_time), "Personal best round-trips through JSON")
	var invalid_numbers := FileAccess.open(loaded.path, FileAccess.WRITE)
	invalid_numbers.store_string('{"version":1,"best_time":1e309,"deaths":1e309,"attempts":1e30,"clears":12,"music":false,"sfx":true}')
	invalid_numbers.close()
	var sanitized := TryRecords.new(true)
	sanitized.load_records()
	check(is_finite(sanitized.data.best_time) and sanitized.data.best_time == 0, "Non-finite best times cannot corrupt the record display")
	check(sanitized.data.deaths == 0 and sanitized.data.attempts == 0, "Non-finite or out-of-range counters are discarded before integer conversion")
	check(sanitized.data.clears == 12 and not sanitized.data.music and sanitized.data.sfx, "Invalid numeric fields do not discard valid records and preferences")
	check(not sanitized.data.get("muted", true), "Existing saves without a global mute field remain compatible")
	invalid_numbers = FileAccess.open(loaded.path, FileAccess.WRITE)
	invalid_numbers.store_string('{"version":1,"best_time":1e200}')
	invalid_numbers.close()
	sanitized = TryRecords.new(true)
	sanitized.load_records()
	check(sanitized.data.best_time == 0, "Finite times too large for centisecond formatting are rejected")
	var corrupt := FileAccess.open(loaded.path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	var recovered := TryRecords.new(true)
	recovered.load_records()
	check(recovered.data.deaths == 0 and not recovered.last_error.is_empty(), "Malformed save is handled without a crash")
	game.start_run()
	await frames(5)
	check(game.checkpoint_index == -1 and game.run_deaths == 0 and not game.secret_collected, "New run resets its checkpoint, deaths and course secret")
	check(game.records.data.clears == 1, "New run preserves lifetime records")
	var real_test_path: String = game.records.path
	game.records.path = "user://missing-save-parent/records.json"
	check(not game.save_records(), "Save failure is reported to callers")
	game.finish_run()
	await frames(2)
	check(game.toast_clock > 0 and game.toast_label.visible and not game.records.last_error.is_empty(), "Clear keeps a failed-save message visible")
	game.quit_game()
	await frames(2)
	check(game.quit_dialog.visible, "Save failure requires an explicit choice before exiting without records")
	check(game.quit_dialog.get_cancel_button().has_focus(), "Failed-save exit defaults to keeping the game open")
	game.quit_dialog.hide()
	game.records.path = real_test_path
	var legacy := FileAccess.open(loaded.path, FileAccess.WRITE)
	legacy.store_string('{"version":1,"best_time":14.81,"clears":3,"music":false,"no_death":true}')
	legacy.close()
	var migrated := TryRecords.new(true)
	migrated.load_records()
	check(migrated.data.best_time == 0 and not migrated.data.no_death and migrated.data.clears == 3 and not migrated.data.music, "Old short-course best is separated while lifetime totals and sound preferences survive")
	check(is_equal_approx(float(migrated.data.legacy["meadow-v1"].best_time), 14.81), "Previous course best remains archived rather than deleted")
	# A full no-teleport traversal with normal movement/jump inputs is run separately.
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_records.json"))
	print("\nRESULT: %d checks, %d failures" % [checks, failures])
	call_deferred("quit", 1 if failures else 0)
