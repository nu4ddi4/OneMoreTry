extends SceneTree

var game: OneMoreGame
var room := 1
var origin := 0.0
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func tick(count: int = 1) -> void:
	for i in count:
		if game.run_deaths > 0: return
		await physics_frame
		await process_frame
func right() -> void:
	Input.action_release("move_left")
	Input.action_press("move_right")
func stop() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
func go(q: float) -> void:
	right()
	for i in 900:
		if game.run_deaths > 0 or game.player.position.x - origin >= q: return
		await tick()
func wait_until(t: float) -> void:
	stop()
	for i in 900:
		if game.run_deaths > 0 or game.traps[room - 1].clock >= t: return
		await tick()
func press_jump(hold: int) -> void:
	Input.action_press("jump")
	await tick(hold)
	Input.action_release("jump")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://wrong-route-records.json"
	for id in range(1, 41):
		room = id
		origin = TryCourse.origin(id)
		stop()
		Input.action_release("jump")
		Input.action_release("climb_up")
		game.start_run()
		game.player.respawn(Vector2(origin + 64, 416))
		await tick(4)
		match id:
			1:
				await go(210)
				right()
				await press_jump(10)
				for n in 120:
					if game.player.position.x - origin >= 272: stop()
					await tick()
					if game.player.is_on_floor(): break
				stop()
				await tick(20)
				await press_jump(45)
			7:
				await go(228)
				Input.action_press("jump")
				await go(350)
				stop()
				Input.action_release("jump")
			9,18,19,33:
				await go(144)
				stop()
				if id == 33:
					await wait_until(0.34)
					await go(264)
			12:
				await go(184)
				stop()
			13:
				Input.action_press("climb_up")
				await go(270)
			14:
				await go(220)
				stop()
			16:
				await go(214)
				await press_jump(45)
			22:
				await go(165)
				stop()
				while game.run_deaths == 0 and game.traps[21].clock - game.traps[21].auxiliary < 0.25: await tick()
				await press_jump(45)
			27:
				await go(166)
				await wait_until(0.5)
				right()
				await press_jump(6)
			28:
				await go(166)
				stop()
			29,30:
				await go(236)
				stop()
				if id == 30: await press_jump(45)
			31:
				await go(182)
				await press_jump(45)
			32:
				await go(178)
				await press_jump(45)
			35:
				await go(210)
				await press_jump(45)
			37:
				await go(232)
				stop()
			39:
				await go(560)
				stop()
			40:
				var previous: TryEncounter = game.traps[38]
				previous.arm()
				previous.auxiliary = 0
				previous.clock = 0.55
				previous.flags.finish = true
				await go(500)
			_:
				await go(560)
		await tick(400)
		checks += 1
		if game.run_deaths > 0:
			print("PASS: wrong decision has a physical consequence in encounter ", id)
		else:
			failures += 1
			push_error("WRONG ROUTE survived: room=%d x=%.1f y=%.1f clock=%.3f flags=%s" % [id,game.player.position.x-origin,game.player.position.y,game.traps[id-1].clock,game.traps[id-1].flags])
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wrong-route-records.json"))
	print("Wrong decisions: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
