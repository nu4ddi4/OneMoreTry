extends SceneTree

var game: OneMoreGame
var failed := false
var room := 1
var origin := 0.0
var isolated := 0
var fast_route := false
var frames_used := 0
var tape: Array[int] = []
var positions: Array = []
var room_stats: Dictionary = {}
var pause_candidates: Dictionary = {}
const ACTIONS := ["move_left", "move_right", "jump", "climb_up", "climb_down"]

func _initialize() -> void:
	fast_route = "--fast" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room="): isolated = int(argument.trim_prefix("--room="))
	call_deferred("run")

func tick(count: int = 1) -> void:
	for i in count:
		if failed: return
		var bits := 0
		for index in ACTIONS.size():
			if Input.is_action_pressed(ACTIONS[index]): bits |= 1 << index
		if not room_stats.has(room): room_stats[room] = {"ticks": 0, "still": 0}
		room_stats[room].ticks += 1
		if game.player.is_on_floor() and absf(game.player.velocity.x) < 5: room_stats[room].still += 1
		tape.append(bits)
		await physics_frame
		await process_frame
		positions.append([game.player.position.x, game.player.position.y])
		frames_used += 1
		if not pause_candidates.has(room):
			if (room == 6 and game.player.carrier == game.traps[5].surfaces.platform) or (room == 20 and game.player.chain != null and game.player.position.y < 300) or (room == 29 and game.player.carrier == game.traps[28].surfaces.lift and game.player.position.y < 400):
				pause_candidates[room] = frames_used
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
		if i == hold or (air_after >= 2 and i == air_after - 2): Input.action_release("jump")
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
		9, 18, 19, 37, 39: pass
		1:
			await go(210)
			await jump(10)
			await go(410, false)
			await jump()
		7:
			await go(238)
			await jump(70, 1, 24)
		2, 38:
			await go(180)
			await jump(6)
			await jump()
		3:
			await go(282, false)
			await jump()
		4:
			await go(144 if fast_route else 120)
			if fast_route: await jump(6, 0)
			else: await wait_clock(1.4)
			await go(180, false)
			await jump()
		5:
			await go(120)
			await go(88)
			await wait_clock(1.15)
		6:
			if fast_route:
				await go(187, false)
				await jump()
			else:
				await go(176)
				await wait_clock(2.6)
				await jump(6)
			horizontal(0)
			while not failed and game.traps[5].surfaces.platform.position.x < 350: await tick()
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
			if fast_route:
				await go(158)
				horizontal(0)
				Input.action_press("jump")
				await tick(24)
				Input.action_release("jump")
				await tick(2)
				Input.action_press("jump")
				await tick(20)
				await go(116)
				Input.action_release("jump")
				await land()
				await go(126)
				horizontal(0)
				Input.action_press("jump")
				await tick(28)
				horizontal(1)
				await tick(35)
				Input.action_release("jump")
			else:
				await go(156)
				await wait_clock(1.2)
		20:
			if fast_route:
				await go(292, false)
			else:
				await go(154, false)
				await jump(6, -1)
				await go(136)
				while not failed and game.traps[19].clock - game.traps[19].auxiliary < 1.05: await tick()
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
			var exchange: TryEncounter = game.traps[room - 1]
			while not failed and exchange.clock - exchange.auxiliary < (0.12 if room == 21 else 0.25): await tick()
			await jump(45 if room == 21 else 6, 0)
			while not failed and exchange.clock - exchange.auxiliary < 1.15: await tick()
		23:
			await go(294)
			await tick(52)
			await go(406, false)
			Input.action_press("climb_up")
			Input.action_press("jump")
			for i in 160:
				if i == 45: Input.action_release("jump")
				await tick()
				if failed or game.player.chain != null: break
			Input.action_release("jump")
			horizontal(0)
			await tick(55)
			Input.action_release("climb_up")
			horizontal(1)
			Input.action_press("jump")
			await go(568)
			Input.action_release("jump")
			for i in 90:
				if failed or game.player.air_jumps > 0: break
				await tick()
			if game.player.air_jumps == 0:
				failed = true
				push_error("Chain exit must collect the midair charge")
			await tick(2)
			Input.action_press("jump")
			await go(690, false, true)
			Input.action_release("jump")
		24:
			await go(290)
			await tick(170)
			await go(406)
			await jump()
		25:
			await go(314)
			await jump(12)
			await go(456)
			if not fast_route: await wait_clock(2.8)
		26:
			await go(146, false)
			await jump()
		27, 28:
			if fast_route and room == 27:
				await go(166)
				await wait_clock(0.5)
				await jump()
				await jump()
			else:
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
			if fast_route: await tick(16)
			else: await wait_clock(1.9)
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
			await go(226)
			while not failed and game.traps[32].clock - game.traps[32].auxiliary < 0.8: await tick()
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
	if not failed: await go(TryCourse.width(room) + 64, not (fast_route and room in [17,18,19]))
	if fast_route and room in [17, 18, 19] and game.player.position.y > 245:
		failed = true
		push_error("Fast route must actually use the connected upper bridge")

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
		origin = TryCourse.origin(room)
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
		var file := FileAccess.open("res://build/course-fast-replay.json" if fast_route else "res://build/course-replay.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"frames": tape, "positions": positions, "x": game.player.position.x, "time": game.elapsed, "course": TryRecords.COURSE_ID, "fast": fast_route, "stats": room_stats, "pauses": pause_candidates.values()}))
		file.close()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playthrough_records.json"))
	quit(1 if failed else 0)
