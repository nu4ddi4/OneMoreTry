extends "res://tests/gameplay_revision_tests.gd"

func contact(number: int, x: float, y: float = 416) -> void:
	game.player.respawn(Vector2(TryCourse.origin(number)+x,y))
	await ticks(4)

func body_at(encounter: TryEncounter, width: float, height: float) -> Rect2:
	for rect in encounter.hazards:
		if rect.size == Vector2(width,height): return rect
	return Rect2()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://fairness-test-records.json"
	await reset(35)
	await go(35,330)
	var puzzle: TryEncounter = game.traps[34]
	check(game.player.alive and puzzle.flags.get("left",false), "An ordinary walking descent actually operates the first lower latch")
	check(not puzzle.flags.get("right",false) and puzzle.surfaces.exit.latches.x == 1 and puzzle.surfaces.exit.latches.y == 0, "The door visibly remembers one completed latch without exposing floor sensors")
	check(puzzle.surfaces.exit.position.y == 248, "One latch alone keeps the ordinary exit shut")
	await contact(35,372,464)
	await contact(35,330,464)
	await ticks(48)
	check(puzzle.flags.get("open",false) and puzzle.surfaces.exit.position.y == 32, "Both completed latches visibly raise the actual door collider")
	check(game.player.alive, "The space between the two mechanisms remains a safe place to read their response")
	await reset(35)
	await contact(35,400,464)
	Input.action_press("move_right")
	await ticks(8)
	Input.action_release("move_right")
	check(game.player.alive and game.player.position.x - TryCourse.origin(35) <= 406.1, "A locked puzzle door blocks movement without an unexplained contact death")
	check(puzzle.flags.get("right",false) and not puzzle.flags.get("left",false), "Right-first contact operates only its matching latch")
	await contact(35,252,464)
	await contact(35,330,464)
	await ticks(48)
	check(puzzle.flags.get("open",false), "The two latches can be completed in either order")
	puzzle.reset()
	check(puzzle.surfaces.exit.latches == Vector2.ZERO and puzzle.surfaces.exit.position.y == 248 and puzzle.flags.is_empty(), "Retry restores closed hardware and removes all remembered latch state")
	await reset(35)
	Input.action_press("move_right")
	for n in 300:
		if game.run_deaths > 0 or game.player.position.x - TryCourse.origin(35) >= 405: break
		await ticks(1)
	Input.action_press("jump")
	await ticks(70)
	Input.action_release("jump")
	Input.action_release("move_right")
	check(game.run_deaths == 0 and puzzle.flags.get("open",false) and game.player.position.x > TryCourse.origin(35)+500, "A walking descent and one deliberate exit jump clear the latch puzzle without guessing a hidden stopping coordinate")
	await reset(35)
	await contact(35,252,464)
	await ticks(32)
	check(game.player.alive and not puzzle.preparations.is_empty() and puzzle.hazards.is_empty(), "Lower floor teeth visibly wind up before causing damage")
	var pose := puzzle.preparations.duplicate(true)
	var clock := puzzle.clock
	game.pause_game()
	await ticks(12)
	check(puzzle.clock == clock and puzzle.preparations == pose, "Pause freezes the physical preparation animation")
	game.resume_game()
	await ticks(30)
	check(not game.player.alive, "Ignoring an already visible armed mechanism is still fatal")
	puzzle.reset()
	check(puzzle.preparations.is_empty() and puzzle.scenery.is_empty(), "Reset removes every preparation and temporary visual")
	for number in [19,20]:
		await reset(number)
		await contact(number,144 if number==19 else 174)
		await ticks(18 if number==19 else 8)
		var trap: TryEncounter = game.traps[number-1]
		check(game.player.alive and not trap.preparations.is_empty() and body_at(trap,48 if number == 19 else 32,28) == Rect2(), "Encounter %d shows its activated ground mechanism before contact damage" % number)
		await ticks(18)
		check(not game.player.alive, "Encounter %d preserves its original fatal attack after preparation" % number)
	await reset(33)
	await contact(33,226)
	await ticks(52)
	var reignite: TryEncounter = game.traps[32]
	check(not reignite.preparations.is_empty() and body_at(reignite,64,28) == Rect2(), "The second ignition has a new visible preparation after the first attack ends")
	await ticks(20)
	check(body_at(reignite,64,28) != Rect2(), "The second ignition still becomes a real hazard")
	await reset(1)
	var ceiling: TryEncounter = game.traps[0]
	check(ceiling.scenery.is_empty() and ceiling.hazards.is_empty(), "The first square trap has no visible housing before activation")
	ceiling.arm()
	await ticks(2)
	check(ceiling.scenery.is_empty() and ceiling.hazards.is_empty(), "The first square stays absent until its original short activation threshold")
	await ticks(2)
	check(ceiling.scenery.is_empty() and ceiling.hazards == [Rect2(176,304,168,18)], "The first square appears at its original dangerous position without a descent animation")
	await reset(12)
	var block: TryEncounter = game.traps[11]
	check(body_at(block,56,48).position.y == 320, "The falling block is visible before the approach sensor fires")
	await contact(12,144)
	await ticks(10)
	check(body_at(block,56,48).position.y == 320, "The block briefly holds in its visible housing")
	await ticks(20)
	check(body_at(block,56,48).position.y > 320 and body_at(block,56,48).position.y < 368, "The block follows a continuous fall rather than appearing at head height")
	await reset(22)
	await contact(22,560)
	var rail: TryEncounter = game.traps[21]
	rail.auxiliary = 0
	rail.clock = 0.6
	rail._physics_process(0)
	check(body_at(rail,26,22).position.y > 338 and body_at(rail,26,22).position.y < 394, "The returning blade physically changes rails during its turnaround")
	await reset(36)
	await contact(36,270)
	var press: TryEncounter = game.traps[35]
	var previous := body_at(press,104,96).position.y
	var continuous := true
	for n in 24:
		await ticks(1)
		var y := body_at(press,104,96).position.y
		continuous = continuous and y >= previous and y - previous <= 3.34
		previous = y
	check(game.player.alive and continuous and previous > 208, "The overhead press is already visible and advances continuously while the player can react")
	await ticks(16)
	check(not game.player.alive, "Remaining under the visibly descending press still causes a real crush")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fairness-test-records.json"))
	print("Fairness: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
