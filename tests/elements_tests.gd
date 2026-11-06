extends "res://tests/gameplay_revision_tests.gd"

const Elements = preload("res://scripts/elements.gd")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.records.path = "user://elements-test-records.json"
	await reset(1)
	check(get_nodes_in_group(&"hazard_sources").size() == 40 and not get_nodes_in_group(&"terrain").is_empty(), "The shared world exposes terrain and all forty hazard sources as explicit groups")
	check(game.traps[23].surfaces.weak.element_kind == Elements.Kind.TERRAIN and not game.traps[23].surfaces.weak.lethal, "Concealed floors remain ordinary solid terrain until their mechanism acts")
	check(game.traps[24].surfaces.belt.is_in_group(&"platforms") and not game.traps[24].surfaces.belt.lethal, "A conveyor belongs to the safe carrier family")
	check(game.traps[34].surfaces.exit.is_in_group(&"mechanisms") and not game.traps[34].surfaces.exit.lethal, "The two-latch exit remains a safe mechanism")
	check(game.traps[19].devices[0].is_in_group(&"traversal") and game.traps[9].devices[0].is_in_group(&"pickups"), "Ropes and charges use their own reusable interaction groups")
	await reset(4)
	check(game.traps[3].surfaces.switch.element_kind == Elements.Kind.RELAY and not game.traps[3].surfaces.switch.lethal, "The early head switch uses the same nonlethal relay contract as later switches")
	var low_clearance := TryCourse.FLOOR - Elements.PLAYER_VISUAL_HEIGHT - Elements.LOW_ROOF_Y - Elements.ROOF_THICKNESS
	check(low_clearance >= Elements.MIN_HEADROOM, "Common low roofs leave at least 48 pixels above the visible standing character")
	var opening := TryCourse.definition(1).solids[0] as Rect2
	check(opening.position.y - Elements.PLAYER_VISUAL_HEIGHT - Elements.OPENING_ROOF_Y - Elements.ROOF_THICKNESS >= Elements.MIN_HEADROOM, "The raised opening step has generous visual clearance below its active ceiling")
	await reset(15)
	var relay: TrySurface = game.traps[14].surfaces.head
	check(416 - Elements.PLAYER_VISUAL_HEIGHT - relay.position.y - relay.dimensions.y >= Elements.MIN_HEADROOM, "The bridge relay uses the same comfortable standing clearance")
	await reset(16)
	relay = game.traps[15].surfaces.head
	check(400 - Elements.PLAYER_VISUAL_HEIGHT - relay.position.y - relay.dimensions.y >= Elements.MIN_HEADROOM, "The false relay also leaves room above its raised step")
	await reset(12)
	var block: Rect2 = game.traps[11].hazards[0]
	check(416 - Elements.PLAYER_VISUAL_HEIGHT - block.end.y >= Elements.MIN_HEADROOM, "The early suspended weight starts well above the character")
	await reset(1)
	await go(1,210)
	Input.action_press("move_right")
	Input.action_press("jump")
	var smallest_gap := INF
	for n in 90:
		if n == 45: Input.action_release("jump")
		await ticks(1)
		if game.player.position.x < 384:
			smallest_gap = minf(smallest_gap,game.player.position.y - Elements.PLAYER_VISUAL_HEIGHT - Elements.OPENING_ROOF_Y - Elements.ROOF_THICKNESS)
	Input.action_release("move_right")
	check(game.run_deaths == 0 and game.player.position.x > 344, "An ordinary full first jump now clears the opening obstacle")
	check(smallest_gap >= 16, "The visible character keeps air space even at that full jump's apex")
	await reset(1)
	game.player.respawn(Vector2(272,384))
	await ticks(30)
	Input.action_press("jump")
	await ticks(60)
	Input.action_release("jump")
	check(game.run_deaths > 0, "The raised ceiling still punishes a full jump from the elevated step")
	var rect := Rect2(100,100,26,22)
	check(not Elements.touches(Elements.Kind.BLADE,rect,Rect2(100,100,2,2)), "A round blade has no invisible rectangular corner damage")
	check(Elements.touches(Elements.Kind.BLADE,rect,Rect2(110,105,8,10)), "A visible blade center remains lethal")
	check(Elements.touches(Elements.Kind.CRUSHER,rect,Rect2(100,100,2,2)), "An equally sized rectangular press retains its actual rectangular contact")
	# Actual solid contact, with identical dimensions: the element contract decides the result.
	await reset(1)
	for encounter in game.traps: encounter.set_physics_process(false)
	var door := TrySurface.new()
	door.game = game
	door.position = Vector2(650,248)
	door.dimensions = Vector2(24,168)
	door.element_kind = Elements.Kind.DOOR
	game.add_child(door)
	game.player.respawn(Vector2(610,416))
	Input.action_press("move_right")
	await ticks(40)
	check(game.player.alive and game.player.position.x <= 640.1, "Touching a safe door blocks the real character without killing it")
	door.set_element(Elements.Kind.CRUSHER)
	await ticks(2)
	Input.action_release("move_right")
	check(game.run_deaths > 0 and door.is_in_group(&"hazards") and not door.is_in_group(&"mechanisms"), "An identically sized lethal press kills on actual solid contact and changes its group")
	# Course changes archive comparable best times while keeping lifetime totals.
	var records := TryRecords.new(true)
	records.path = "user://elements-migration.json"
	var out := FileAccess.open(records.path,FileAccess.WRITE)
	out.store_string(JSON.stringify({"version":1,"course":"continuous-40-v2","deaths":88,"attempts":12,"clears":3,"best_time":135.5,"no_death":true,"secret":true,"music":false}))
	out.close()
	records.load_records()
	check(records.data.best_time == 0 and records.data.legacy["continuous-40-v2"].best_time == 135.5, "The previous course best is archived rather than compared against the redesigned opening")
	check(records.data.deaths == 88 and records.data.clears == 3 and not records.data.music, "Lifetime counts and audio settings survive the element redesign")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(records.path))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://elements-test-records.json"))
	print("Elements: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
