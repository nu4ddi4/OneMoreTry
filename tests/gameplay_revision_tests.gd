extends SceneTree

var game: OneMoreGame
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func ticks(count: int) -> void:
	for n in count:
		await physics_frame
		await process_frame
func reset(number: int) -> void:
	for action in ["move_left", "move_right", "jump", "climb_up", "climb_down"]: Input.action_release(action)
	game.start_run()
	game.spawn_point = Vector2(TryCourse.origin(number) + 64, 416)
	game.player.respawn(game.spawn_point)
	await ticks(4)
func go(number: int, x: float) -> void:
	for n in 900:
		if game.run_deaths > 0: break
		var distance := TryCourse.origin(number) + x - game.player.position.x
		if absf(distance) < 2 and absf(game.player.velocity.x) < 25: break
		var braking := game.player.velocity.x * game.player.velocity.x / 4200
		var direction := 0 if absf(distance) <= braking + 1 and signf(distance) == signf(game.player.velocity.x) else (1 if distance > 0 else -1)
		Input.action_release("move_left")
		Input.action_release("move_right")
		if direction != 0: Input.action_press("move_right" if direction > 0 else "move_left")
		await ticks(1)
	Input.action_release("move_left")
	Input.action_release("move_right")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://revision-test-records.json"
	var lengths: Dictionary = {}
	var sensors: Dictionary = {}
	for n in range(1,41):
		lengths[TryCourse.width(n)] = true
		sensors[TryCourse.definition(n).sensor] = true
		check(TryCourse.number_at(TryCourse.origin(n) + 64) == n, "Variable boundary maps to encounter %02d" % n)
	check(lengths.size() > 8 and sensors.size() > 8, "Encounter spacing and entry positions are independently varied")
	check(TryCourse.CHECKPOINTS.size() == 2 and TryCourse.CHECKPOINTS[0].x == TryCourse.origin(17)+32 and TryCourse.CHECKPOINTS[1].x == TryCourse.origin(33)+32, "Only two real checkpoints remain after encounters 16 and 32")
	for number in [20,21,22,33]:
		await reset(number)
		await go(number,120)
		await go(number,48)
		await ticks(240)
		check(game.traps[number-1].auxiliary < 0, "Entry camping cannot consume encounter %02d's committed attack" % number)
		if number != 20:
			await go(number,560)
			check(game.run_deaths > 0, "Old no-jump retreat/wait shortcut fails in encounter %02d" % number)
	await reset(4)
	await go(4,144)
	Input.action_press("jump")
	await ticks(10)
	Input.action_release("jump")
	check(game.traps[3].flags.get("switch",false) and not game.traps[3].surfaces.crusher.active and game.traps[3].clock < 1.25, "A real head impact opens the first timed passage early")
	# Landing feedback occurs only after contact, with a clear soft/hard distinction.
	await reset(24)
	game.player.respawn(Vector2(TryCourse.origin(24)+280,410))
	game.player.velocity.y = 60
	await ticks(10)
	check(game.traps[23].surfaces.weak.active and not game.traps[23].flags.get("broken",false), "A soft landing leaves the disguised floor intact")
	game.player.respawn(Vector2(TryCourse.origin(24)+280,360))
	game.player.velocity.y = 420
	await ticks(15)
	check(game.traps[23].flags.get("broken",false) and not game.traps[23].surfaces.weak.active and game.particles.size() > 5, "A hard landing breaks the floor and emits physical debris")
	game.traps[23].reset()
	check(game.traps[23].surfaces.weak.active and not game.traps[23].surfaces.weak.impacted, "Retry removes every impact trace")
	# Real controls alter the rope and inherited launch speed, then reset cleanly.
	await reset(20)
	var chain: TryDevice = game.traps[19].devices[0]
	game.player.respawn(chain.tip(170)+Vector2(0,14))
	Input.action_press("climb_up")
	await ticks(2)
	check(game.player.chain == chain, "Chain control starts from an actual contact grab")
	Input.action_release("climb_up")
	Input.action_press("move_right")
	await ticks(48)
	check(chain.swing > 0.1 and chain.release_velocity(game.player.chain_distance).x > 0, "Horizontal input builds a controlled swing")
	Input.action_press("jump")
	await ticks(1)
	check(game.player.chain == null and game.player.velocity.x > TryPlayer.SPEED, "Chain jump inherits earned horizontal speed")
	Input.action_release("jump")
	Input.action_release("move_right")
	chain.reset()
	check(chain.swing == 0 and chain.swing_velocity == 0 and chain.rider == null, "Reset clears swing energy and ownership")
	# Changed terrain must never silently replace an old personal best.
	var records := TryRecords.new(true)
	records.path = "user://revision-migration.json"
	var out := FileAccess.open(records.path,FileAccess.WRITE)
	out.store_string(JSON.stringify({"version":1,"course":"continuous-40-v1","deaths":88,"attempts":12,"clears":3,"best_time":138.4,"no_death":true,"secret":true,"music":false}))
	out.close()
	records.load_records()
	check(records.data.best_time == 0 and not records.data.no_death and not records.data.secret and records.data.legacy["continuous-40-v1"].best_time == 138.4, "Previous course achievements are archived under their actual course")
	check(records.data.deaths == 88 and records.data.attempts == 12 and records.data.clears == 3 and not records.data.music, "Lifetime counts and audio preferences survive the course change")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(records.path))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://revision-test-records.json"))
	print("Gameplay revision: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
