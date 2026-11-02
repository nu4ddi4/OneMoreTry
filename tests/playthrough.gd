extends SceneTree

var game: OneMoreGame
var failed := false
var room := 1
var origin := 0.0
var isolated := 0
var frames_used := 0
var tape: Array[int] = []
var positions: Array = []
const ACTIONS := ["move_left", "move_right", "jump", "climb_up", "climb_down"]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room="): isolated = int(argument.trim_prefix("--room="))
	call_deferred("run")

func tick(count: int = 1) -> void:
	for i in count:
		if failed: return
		var bits := 0
		for index in ACTIONS.size():
			if Input.is_action_pressed(ACTIONS[index]): bits |= 1 << index
		tape.append(bits)
		await physics_frame
		await process_frame
		positions.append([game.player.position.x, game.player.position.y])
		frames_used += 1
		if not game.player.alive or game.run_deaths > 0:
			failed = true
			push_error("ROUTE died: room=%d x=%.1f y=%.1f clock=%.3f velocity=%s" % [room, game.player.position.x - origin, game.player.position.y, game.traps[room - 1].clock, game.player.velocity])

func horizontal(value: int) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if value > 0: Input.action_press("move_right")
	if value < 0: Input.action_press("move_left")

func go(x: float, stop: bool = true, climb: bool = false) -> void:
	if climb: Input.action_press("climb_up")
	for i in 1800:
		if failed or game.mode == OneMoreGame.Mode.CLEAR: break
		var distance := origin + x - game.player.position.x
		if not stop and distance <= 1: break
		if stop and absf(distance) < 2.5 and absf(game.player.velocity.x) < 25: break
		var braking := game.player.velocity.x * game.player.velocity.x / (2 * (2100.0 if game.player.is_on_floor() else 1500.0))
		if stop and absf(distance) <= braking + 1 and signf(distance) == signf(game.player.velocity.x): horizontal(0)
		else: horizontal(1 if distance > 0 else -1)
		await tick()
		if i == 1799:
			failed = true
			push_error("ROUTE stuck: room=%d x=%.1f y=%.1f target=%.1f chain=%s" % [room, game.player.position.x-origin,game.player.position.y,x,game.player.chain != null])
	if stop: horizontal(0)
	if climb: Input.action_release("climb_up")

func land(limit: int = 240) -> void:
	await tick(3)
	for i in limit:
		if failed or game.player.is_on_floor(): return
		await tick()
	failed = true
	push_error("ROUTE no landing in room %d at %s" % [room, game.player.position])

func jump(hold: int = 45, direction: int = 1, air_after: int = -1) -> void:
	horizontal(direction)
	Input.action_press("jump")
	for i in 200:
		if i == hold: Input.action_release("jump")
		if i == air_after: Input.action_press("jump")
		if air_after >= 0 and i == air_after + hold: Input.action_release("jump")
		await tick()
		if failed: break
		if i > 4 and game.player.is_on_floor() and (air_after < 0 or i > air_after): break
	Input.action_release("jump")

func wait_clock(t: float) -> void:
	horizontal(0)
	while not failed and game.traps[room - 1].clock < t:
		await tick()

func ride(key: String, second: bool) -> void:
	await go(166)
	await wait_clock(3.5 if second else 0.5)
	horizontal(1)
	Input.action_press("jump")
	for i in 150:
		if i == 6: Input.action_release("jump")
		await tick()
		if failed: break
		if game.player.carrier == game.traps[room - 1].surfaces[key]: break
	Input.action_release("jump")
	horizontal(0)
	for i in 350:
		if failed: break
		if game.traps[room - 1].surfaces[key].global_position.x - origin >= 376: break
		await tick()
	await jump()

func route() -> void:
	match room:
		1, 7, 9, 18, 19, 37, 39: pass
		2, 38:
			await go(180)
			await jump(6)
			await jump()
		3:
			await go(282, false)
			await jump()
		4:
			await go(120)
			await wait_clock(1.4)
			await go(180, false)
			await jump()
		5:
			await go(120)
			await go(88)
			await wait_clock(1.15)
		6:
			await go(176)
			await wait_clock(2.6)
			await jump(6)
			horizontal(0)
			while not failed and game.traps[5].surfaces.platform.position.x < 350:
				await tick()
			await jump()
		8:
			await go(168)
			Input.action_press("jump")
			await tick(10)
			Input.action_release("jump")
		10:
			await go(170)
			await jump(6, 0)
			await go(218, false)
			await jump(40, 1, 48)
		11:
			await go(190)
			await wait_clock(1.0)
			await go(224, false)
			await jump()
		12:
			await go(124)
			await wait_clock(0.8)
			await go(136, false)
			await jump()
		13:
			await go(194, false, true)
			await jump(45, -1)
			await wait_clock(1.0)
			await go(164)
			await jump()
		14:
			await go(224)
			await go(180)
			await go(540, true, true)
		15:
			await go(208)
			await jump(45, 0)
		16:
			await go(218, false)
			await jump(6)
		17:
			await go(156)
			await wait_clock(1.2)
		20:
			await go(136)
			await wait_clock(1.95)
			await go(370, false)
			Input.action_press("climb_up")
			Input.action_press("jump")
			for i in 180:
				if i == 45: Input.action_release("jump")
				await tick()
				if failed or game.player.chain != null: break
			Input.action_release("jump")
			horizontal(0)
			await tick(90)
			Input.action_release("climb_up")
			await jump()
		21, 22:
			await go(165)
			await wait_clock(0.22 if room == 21 else 0.28)
			await jump(45 if room == 21 else 6, 0)
			await wait_clock(1.15)
		23:
			await go(294)
			await tick(52)
		24:
			await go(290)
			await tick(170)
			await go(406)
			await jump()
		25:
			await go(314)
			await jump(12)
			await go(456)
			await wait_clock(2.8)
		26:
			await go(146, false)
			await jump()
		27, 28:
			await ride("ferry", room == 27)
		29, 30:
			await go(236)
			var encounter: TryEncounter = game.traps[room - 1]
			while not failed and (encounter.auxiliary < 0 or encounter.clock - encounter.auxiliary < (0.6 if room == 29 else 1.1)):
				await tick()
			if room == 29:
				await go(290, false)
				await jump()
		31:
			await go(182)
			horizontal(1)
			Input.action_press("jump")
			for i in 160:
				if i == 45: Input.action_release("jump")
				if game.player.position.x - origin >= 330: horizontal(0)
				await tick()
				if failed or (i > 5 and game.player.is_on_floor()): break
			Input.action_release("jump")
			await wait_clock(1.9)
			await go(380, false)
			await jump(6)
		32:
			horizontal(1)
			for i in 300:
				await tick()
				if failed or game.player.carrier != null: break
			horizontal(0)
			for i in 300:
				if failed or game.player.position.x - origin > 412: break
				await tick()
			await jump()
		33:
			await go(136)
			await wait_clock(0.9)
		34:
			await go(248)
			await wait_clock(2.0)
			await go(254)
			await jump()
		35:
			await go(252)
			await go(372)
			await jump()
		36:
			await go(220, false)
			await jump(6)
		40:
			await tick(100)
			await go(80, false)
			await jump()
	if not failed: await go(704)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://playthrough_records.json"
	game.start_run()
	await tick(8)
	var first := isolated if isolated > 0 else 1
	var last := isolated if isolated > 0 else 40
	for number in range(first, last + 1):
		room = number
		origin = (room - 1) * 640.0
		if isolated > 0:
			game.player.respawn(Vector2(origin + 64, 416))
			await tick(5)
		print("ENTER ", room, " q=",game.player.position.x-origin, " y=",game.player.position.y)
		await route()
		if failed: break
		print("EXIT ",room," q=",game.player.position.x-origin," y=",game.player.position.y)
	if isolated == 0 and (game.mode != OneMoreGame.Mode.CLEAR or game.checkpoint_index != 1 or not game.secret_collected):
		failed = true
	print("FULL PLAYTHROUGH: %s rooms=%d deaths=%d time=%s frames=%d checkpoints=%d secret=%s" % ["FAIL" if failed else "PASS",room,game.run_deaths,OneMoreGame.format_time(game.elapsed),frames_used, game.checkpoint_index + 1, game.secret_collected])
	if not failed and isolated == 0:
		DirAccess.make_dir_recursive_absolute("res://build")
		var file := FileAccess.open("res://build/course-replay.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"frames": tape, "positions": positions, "x": game.player.position.x, "time": game.elapsed}))
		file.close()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playthrough_records.json"))
	quit(1 if failed else 0)
