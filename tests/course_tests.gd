extends SceneTree

var game: OneMoreGame
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if condition: print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: " + description)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func snapshot(encounter: TryEncounter) -> Dictionary:
	var data := {"clock": encounter.clock, "state": encounter.state, "held": encounter.held, "auxiliary": encounter.auxiliary, "item": encounter.item_taken, "flags": encounter.flags.duplicate(true), "samples": encounter.samples.duplicate(), "positions": [], "active": [], "devices": [], "hazards": encounter.hazards.duplicate()}
	for surface in encounter.surfaces.values():
		data.positions.append(surface.position)
		data.active.append(surface.active)
	for device in encounter.devices:
		data.devices.append([device.collected, device.clock, device.cooldown])
	return data
func fixture(number: int) -> void:
	for action in ["move_left", "move_right", "jump", "climb_up", "climb_down"]: Input.action_release(action)
	game.start_run()
	game.player.respawn(Vector2((number - 1) * 640 + (96 if number == 40 else 620), 416))
	await frames(3)
	game.traps[number - 1].arm()
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://course-test-records.json"
	check(game.traps.size() == 40, "Forty encounters are connected in one scene")
	var ids: Array[int] = []
	for encounter in game.traps: ids.append(encounter.id)
	check(ids == range(1,41), "Encounter order is complete and unique")
	check(TryWorld.CHECKPOINTS[0].x > 10000 and TryWorld.CHECKPOINTS[1].x - TryWorld.CHECKPOINTS[0].x > 10000, "Checkpoints are separated by over ten thousand pixels")
	for number in range(1,41):
		await fixture(number)
		var encounter: TryEncounter = game.traps[number - 1]
		await frames(10)
		var before := snapshot(encounter)
		game.pause_game()
		var p := game.player.position
		await frames(12)
		check(snapshot(encounter) == before and game.player.position == p, "Encounter %02d pauses its timers, surfaces and hazards" % number)
		game.resume_game()
		encounter.flags.injected = true
		encounter.item_taken = true
		encounter.samples.append(123)
		encounter.reset()
		check(encounter.state == TryEncounter.State.DORMANT and encounter.clock == 0 and encounter.flags.is_empty() and encounter.samples.is_empty() and not encounter.item_taken, "Encounter %02d clears all attempt state" % number)
		await fixture(number)
		await frames(10)
		check(snapshot(encounter) == before, "Encounter %02d repeats identical physics after reset" % number)
	# Temporary mechanics reset together with the hazards, never with a scene load.
	game.start_run()
	var chain: TryDevice = game.traps[19].devices[0]
	game.player.respawn(chain.tip(170) + Vector2(0,14))
	Input.action_press("climb_up")
	await frames(2)
	check(game.player.chain == chain, "Up input grabs a real chain at contact")
	var before_distance := game.player.chain_distance
	await frames(20)
	check(game.player.chain_distance < before_distance - 15, "Up input climbs along the hanging chain")
	game.pause_game()
	var chain_clock := chain.clock
	var hanging := game.player.position
	await frames(12)
	check(chain.clock == chain_clock and game.player.position == hanging, "Chain motion and rider freeze together on pause")
	game.resume_game()
	Input.action_press("jump")
	await frames(2)
	check(game.player.chain == null and game.player.velocity.y < -300, "Jump releases the chain with a real launch")
	Input.action_release("jump")
	Input.action_release("climb_up")
	game.player.die("test")
	await frames(52)
	check(game.player.chain == null and chain.rider == null and game.player.air_jumps == 0, "Respawn clears chain ownership and temporary charges")
	game.start_run()
	var fake: TryEncounter = game.traps[36]
	game.player.respawn(Vector2(fake.position.x + 218, 416))
	await frames(2)
	check(game.player.alive and game.run_deaths == 0 and game.mode == OneMoreGame.Mode.PLAYING and fake.flags.get("impact", false), "False impact never invokes death or blocks input")
	game.start_run()
	fake = game.traps[38]
	game.player.respawn(Vector2(fake.position.x + 564, 416))
	await frames(2)
	check(game.mode == OneMoreGame.Mode.PLAYING and game.records.data.clears == 0 and fake.flags.get("finish", false), "False finish never awards a clear or changes run mode")
	game.player.die("reset shared timer")
	await frames(52)
	check(game.traps[38].auxiliary < 0 and game.traps[39].clock == 0, "Fake finish and final attack share a full death reset")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://course-test-records.json"))
	print("Course systems: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
