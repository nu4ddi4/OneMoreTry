extends "res://tests/gameplay_revision_tests.gd"
func until(trap:TryEncounter,time:float) -> void:
	while game.player.alive and trap.clock-trap.auxiliary<time: await ticks(1)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path="user://wheel-sequence-tests.json"
	await reset(21)
	await go(21,165)
	var trap:TryEncounter=game.traps[20]
	var wheel:=Rect2()
	for rect in trap.hazards:
		if trap.visual_kinds.get(rect)==TryElements.Kind.BLADE: wheel=rect
	check(wheel.position.x>500 and not trap.flags.has("front_x"),"Wheel starts far away before the forward wall exists")
	await until(trap,1.2)
	check(trap.flags.has("front_x") and trap.surfaces.front.active and trap.flags.front_x>game.player.position.x-trap.position.x,"Forward wall appears near the player as the wheel approaches")
	await until(trap,1.3)
	Input.action_press("jump")
	await ticks(45)
	Input.action_release("jump")
	await ticks(85)
	check(game.run_deaths==0 and not trap.surfaces.front.active,"Stationary full jump clears first wheel and the forward wall later opens")
	await reset(22)
	await go(22,165)
	trap=game.traps[21]
	check(not trap.flags.get("roof",false),"Next ceiling is absent until the player jumps")
	Input.action_press("jump")
	await ticks(50)
	Input.action_release("jump")
	check(game.run_deaths>0,"Repeating a full stationary jump hits the summoned ceiling")
	await reset(22)
	await go(22,165)
	trap=game.traps[21]
	await until(trap,1.4)
	Input.action_press("jump")
	await ticks(10)
	Input.action_release("jump")
	await ticks(85)
	check(game.run_deaths==0 and trap.flags.get("roof",false),"Timed short jump clears the wheel below the ceiling")
	game.player.respawn(Vector2(TryCourse.origin(22)+500,416))
	await ticks(3)
	check(trap.flags.has("chase_time"),"Crossing the next boundary starts the third rear-wall encounter")
	await ticks(100)
	check(game.run_deaths>0,"Waiting at the third encounter is caught by the rear wall")
	await reset(22)
	game.traps[21].arm()
	game.traps[21].clock=3
	game.traps[21].auxiliary=0
	game.player.respawn(Vector2(TryCourse.origin(22)+500,416))
	Input.action_press("move_right")
	await ticks(155)
	Input.action_release("move_right")
	check(game.run_deaths==0 and game.player.position.x>TryCourse.origin(22)+790,"Immediate forward movement outruns the rear wall")
	await reset(22)
	check(not game.traps[21].flags.has("chase_time") and not game.traps[21].flags.has("roof"),"Retry resets all three decisions consistently")
	await reset(21)
	await go(21,210)
	trap=game.traps[20]
	await until(trap,1.2)
	check(trap.flags.get("front_x",0)>240 and trap.surfaces.front.position.x==trap.flags.front_x,"A different retry approach moves the actual front collider with its visible wall")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wheel-sequence-tests.json"))
	print("Wheel sequence: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
