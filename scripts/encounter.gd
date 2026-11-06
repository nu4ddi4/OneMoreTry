class_name TryEncounter
extends Node2D

const Elements = preload("res://scripts/elements.gd")
const Surface = preload("res://scripts/surface.gd")
const Device = preload("res://scripts/device.gd")
enum State { DORMANT, ARMED, ACTIVE, SPENT }
var definition: Dictionary
var game: Node2D
var id := 0
var state := State.DORMANT
var clock := 0.0
var item_taken := false
var surfaces: Dictionary = {}
var devices: Array[TryDevice] = []
var hazards: Array[Rect2] = []
var scenery: Array[Rect2] = []
var visual_kinds: Dictionary = {}
var preparations: Array[Dictionary] = []
var flags: Dictionary = {}
var samples: Array[float] = []
var held := 0.0
var auxiliary := -1.0
var previous_floor := false

func _ready() -> void:
	add_to_group(&"hazard_sources")
	process_physics_priority = 10
	id = definition.id
	position.x = definition.x
	for entry in definition.surfaces:
		make_surface(entry[0], entry[1], entry[2] if entry.size() > 2 else true, entry[3] if entry.size() > 3 else 0.0, entry[4] if entry.size() > 4 else Elements.Kind.PLATFORM)
	for entry in definition.devices:
		var device := Device.new()
		device.kind = entry[0]
		device.position = entry[1]
		device.game = game
		device.encounter = self
		add_child(device)
		devices.append(device)

func make_surface(key: String, rect: Rect2, active: bool = true, belt: float = 0, kind: int = Elements.Kind.PLATFORM) -> TrySurface:
	var surface := Surface.new()
	surface.game = game
	surface.position = rect.position
	surface.dimensions = rect.size
	surface.initial_active = active
	surface.belt_speed = belt
	surface.element_kind = Elements.Kind.BELT if belt != 0 else kind
	surface.camouflaged = key in ["false", "pit", "weak"] and rect.position.y == TryCourse.FLOOR
	if surface.camouflaged: surface.element_kind = Elements.Kind.TERRAIN
	if id == 35 and key == "exit":
		surface.latches = Vector2.ZERO
		surface.element_kind = Elements.Kind.DOOR
	add_child(surface)
	surfaces[key] = surface
	return surface

func reset() -> void:
	state = State.DORMANT
	clock = 0
	item_taken = false
	flags.clear()
	samples.clear()
	hazards.clear()
	scenery.clear()
	visual_kinds.clear()
	preparations.clear()
	held = 0
	auxiliary = -1
	previous_floor = false
	for surface in surfaces.values():
		surface.reset()
	for device in devices:
		device.reset()
	queue_redraw()

func arm() -> void:
	if state == State.DORMANT:
		state = State.ARMED
		clock = 0

func danger(rect: Rect2, active: bool = true, kind: int = Elements.Kind.CRUSHER) -> void:
	if active and rect.size.x > 0 and rect.size.y > 0:
		hazards.append(rect)
		visual_kinds[rect] = kind

func beam(x: float, width: float, active: bool = true) -> void:
	danger(Rect2(x, Elements.LOW_ROOF_Y, width, Elements.ROOF_THICKNESS), active, Elements.Kind.BEAM)

func blade(x: float, y: float = 394) -> void:
	danger(Rect2(x,y,26,22),true,Elements.Kind.BLADE)

func gate(key: String, x: float, opened: bool, y: float = 248, height: float = 168) -> void:
	if not surfaces.has(key):
		make_surface(key, Rect2(x, y, 24, height), false, 0, Elements.Kind.CRUSHER)
	var surface: TrySurface = surfaces[key]
	if surface.active == opened:
		surface.set_active(not opened)
	danger(Rect2(x, y, 24, height), not opened)

func drop(x: float, delay: float, start_y: float = 176, width: float = 56, gravity: float = 1500, moving: bool = true) -> void:
	# The suspended block exists before it starts falling.
	var t := maxf(0, clock - delay) if moving else 0.0
	var y := minf(368, start_y + gravity * t * t / 2.0)
	danger(Rect2(x, y, width, 48))

func eruption(key: String, rect: Rect2, t: float, start: float, duration: float, preparation: float = 0.2) -> void:
	if t >= start - preparation and t < start:
		preparations.append({"rect": rect, "amount": clampf((t - start + preparation) / preparation, 0, 1)})
		var sound_key := "mechanism:" + key
		if not flags.has(sound_key):
			flags[sound_key] = true
			game.sound.effect("click")
	danger(rect, t >= start and t < start + duration, Elements.Kind.TEETH)

func closing_gate(key: String, x: float, t: float) -> void:
	if not surfaces.has(key): make_surface(key, Rect2(x, 248, 24, 168), false, 0, Elements.Kind.CRUSHER)
	var gate_body: TrySurface = surfaces[key]
	var amount := clampf(t / 0.16, 0, 1)
	gate_body.position.y = 248 - 168 * (1 - amount)
	gate_body.set_active(t >= 0)
	var rect := Rect2(gate_body.position, gate_body.dimensions)
	if t < 0: scenery.append(rect)
	else: danger(rect)

func lower_latch(key: String, p: TryPlayer) -> void:
	if flags.get(key, false): return
	flags[key] = true
	flags[key + "_time"] = clock
	game.sound.effect("click")
	game.burst(p.position, Color("a77954"), 4)

func lower_exit() -> void:
	var door: TrySurface = surfaces.exit
	for n in 2:
		var key: String = ["left", "right"][n]
		door.latches[n] = clampf((clock - float(flags.get(key + "_time", clock))) / 0.12, 0, 1) if flags.get(key, false) else 0.0
	if flags.get("left", false) and flags.get("right", false) and not flags.has("exit_time"):
		flags.exit_time = clock
	var amount := clampf((clock - float(flags.get("exit_time", clock)) - 0.12) / 0.22, 0, 1) if flags.has("exit_time") else 0.0
	door.position.y = door.initial_position.y - 216 * amount
	flags.open = amount >= 1
	door.queue_redraw()

func on_plate(p: TryPlayer, x: float, width: float, y: float = 416) -> bool:
	return p.is_on_floor() and absf(p.position.y - y) < 7 and p.position.x - position.x > x and p.position.x - position.x < x + width

func collapse(key: String, value: bool) -> void:
	var surface: TrySurface = surfaces[key]
	if value and surface.active:
		surface.set_active(false)
	if value:
		surface.fallen = minf(190, surface.fallen + 6)
		surface.queue_redraw()

func _physics_process(delta: float) -> void:
	if not game.interaction_enabled():
		return
	var p: TryPlayer = game.player
	var x := p.position.x - position.x
	if x < -960 or x > 1600:
		return
	hazards.clear()
	scenery.clear()
	visual_kinds.clear()
	preparations.clear()
	var sensor: float = definition.sensor
	if state == State.DORMANT and x >= sensor and x < definition.width - 32:
		if id != 1 or (x >= 160 and x <= 344 and p.position.y < 410):
			arm()
	if state != State.DORMANT:
		clock += delta
		state = State.ARMED if clock < 0.025 else State.ACTIVE
		if clock > 6:
			state = State.SPENT
	var started := state != State.DORMANT
	match id:
		1:
			danger(Rect2(176, Elements.OPENING_ROOF_Y, Elements.OPENING_ROOF_WIDTH, Elements.OPENING_ROOF_THICKNESS), started and clock > 0.025, Elements.Kind.BEAM)
		2, 38:
			if x >= 228:
				flags.crossed = true
			collapse("false", flags.get("crossed", false))
			if id == 38:
				beam(112, 48)
				if on_plate(p, 250, 52) and auxiliary < 0:
					auxiliary = clock
				if auxiliary >= 0 and clock - auxiliary > 0.2 and clock - auxiliary < 0.95:
					blade(128 + (clock - auxiliary) * 360)
		3:
			beam(112, 156)
			if started and clock < 0.95:
				blade(88 + clock * 440)
		4:
			if p.is_on_ceiling() and x > 118 and x < 170 and p.last_vertical_speed < 0:
				flags.switch = true
			collapse("pit", started and clock > 0.2 and not flags.get("switch", false))
			beam(196, 88, started and clock > 0.3 and clock < 1.25 and not flags.get("switch", false))
			gate("crusher", 340, flags.get("switch", false) or (started and clock > 1.25))
		5:
			beam(128, 292)
			if started and clock > 0.1 and clock < 1.02:
				blade(maxf(112, 420 - (clock - 0.1) * 320))
		6:
			var carrier: TrySurface = surfaces.platform
			var t := clock if started else 0.0
			if p.carrier == carrier:
				flags.boarded = true
				held += delta
			if held > 2.4:
				carrier.set_active(false)
				carrier.fallen = minf(190, carrier.fallen + 6)
			if flags.get("boarded", false) and p.carrier != carrier and auxiliary < 0:
				auxiliary = clock
			var offset := (1.0 - cos(t * 2.2)) * 84
			if auxiliary >= 0 and clock - auxiliary < 0.6:
				offset = maxf(0, offset - (clock - auxiliary) * 100)
			carrier.position.x = carrier.initial_position.x + offset
		7:
			if x > 304 and auxiliary < 0: auxiliary = clock
			if auxiliary >= 0:
				danger(Rect2(424, 388, 64, 28), clock - auxiliary > 0.5 and clock - auxiliary < 1.1, Elements.Kind.TEETH)
				if clock - auxiliary > 0.3 and clock - auxiliary < 1.4:
					blade(224 + (clock - auxiliary - 0.3) * 260)
		8:
			if item_taken and auxiliary < 0:
				auxiliary = clock
			if item_taken:
				surfaces.bridge.set_active(clock - auxiliary < 1.6)
		9:
			if started and clock < 1.8:
				danger(Rect2(24 + minf(clock * 180, 440), 296, 28, 120))
		10:
			# Foreground is visual only; the pickup supplies the air jump.
			pass
		11:
			drop(284, 0.25, 176, 56, 1500, started)
		12:
			drop(196, 0.2, 320, 56, 2000, started)
			# The launch pad introduces a new vertical route above the next block.
		13:
			collapse("pit", started and clock > 0.2)
			if started and clock < 0.72:
				danger(Rect2(maxf(184, 360 - clock * 280), 304, 48, 112))
		14:
			var pressed := on_plate(p, 204, 40)
			if pressed:
				flags.pressed = true
			if flags.get("pressed", false) and not pressed:
				flags.open = true
			gate("door", 280, flags.get("open", false))
			if flags.get("pressed", false) and auxiliary < 0:
				auxiliary = clock
			if auxiliary >= 0:
				danger(Rect2(196, minf(336, 176 + pow(maxf(0, clock - auxiliary - 0.6), 2) * 1800), 56, 80), clock - auxiliary > 0.6)
		15, 16:
			var block := Rect2(188 if id == 15 else 236, 344 if id == 15 else 336, 48, 16)
			if not surfaces.has("head"):
				make_surface("head", block, true, 0, Elements.Kind.RELAY)
			if p.is_on_ceiling() and x > block.position.x - 10 and x < block.end.x + 10 and p.last_vertical_speed < 0:
				flags.head = true
			if id == 15:
				surfaces.bridge.set_active(flags.get("head", false))
			else:
				collapse("pit", started and clock > 1.0)
				if flags.get("head", false):
					if auxiliary < 0: auxiliary = clock
					drop(308, auxiliary + 0.1, 208, 72)
		17:
			gate("a", 208, started and (clock < 0.32 or clock > 1.05))
			gate("b", 328, started and clock > 0.85)
			surfaces.pit.set_active(not (started and clock > 0.5 and clock < 0.9))
		18:
			gate("a", 208, not started or clock < 1.1)
			gate("b", 328, not started or clock < 1.1)
			if started and clock > 0.3 and clock < 1.8:
				danger(Rect2(24 + (clock - 0.3) * 250, 296, 26, 120))
		19:
			if started:
				for n in 3:
					if samples.size() <= n and clock >= n * 0.1:
						samples.append(x)
					if samples.size() > n:
						eruption("foot:%d" % n, Rect2(samples[n] - 24, 388, 48, 28), clock, n * 0.1 + 0.3, 0.1, 0.22)
		20:
			if on_plate(p, 152, 40) and auxiliary < 0: auxiliary = clock
			var t := clock - auxiliary if auxiliary >= 0 else -1.0
			for n in 3:
				eruption("sequence:%d" % n, Rect2(160 + n * 80, 388, 32, 28), t, 0.2 + n * 0.267, 0.1, 0.18)
			beam(200, 48, t > 0.7 and t < 1.0)
			gate("door", 376, t > 0.85)
		21, 22:
			# Entry waiting cannot consume the attack. Crossing commits the exchange.
			if x >= 160 and auxiliary < 0: auxiliary = clock
			if auxiliary >= 0:
				var t := clock - auxiliary
				gate("rear", 120, false)
				if t < 1.1:
					var turn := 0.68 if id == 22 else 0.55
					var bx := 400 - t * 600 if t < 0.55 else 70 + maxf(0, t - turn) * 600
					var rail := lerpf(394, 338, clampf((t - 0.55) / (turn - 0.55), 0, 1)) if id == 22 else 394.0
					blade(bx, rail)
		23:
			gate("a", 208, not started or clock < 1.35)
			if on_plate(p, 272, 48): held += delta
			else: held = 0
			if held >= 0.4: flags.open = true
			gate("b", 368, flags.get("open", false))
			danger(Rect2(264, 320, 80, 96), started and clock > 2.2)
			# The next obstacle continues above the pit rather than returning to flat ground.
		24:
			danger(Rect2(344, 200, 96, 18), true, Elements.Kind.BEAM)
			if on_plate(p, 208, 144) and p.last_vertical_speed >= 340 and not flags.get("broken", false):
				flags.broken = true
				surfaces.weak.impacted = true
				game.sound.effect("crumble")
				game.burst(p.position, Color("967557"), 14)
				game.shake = maxf(game.shake, 2.5)
			collapse("weak", flags.get("broken", false))
			gate("door", 368, false, 248, 168)
			if started and clock > 2.5 and clock < 4:
				blade(112 + (clock - 2.5) * 220)
		25:
			if p.is_on_floor() and x > 432 and x < 468 and absf(p.velocity.x) < 35: flags.braked = true
			danger(Rect2(484, 304, 24, 112), not flags.get("braked", false) and (not started or clock < 2.6))
		26:
			if started and clock > 0.2 and clock < 1.8:
				blade(24 + (clock - 0.2) * 300)
		27, 28:
			var boat: TrySurface = surfaces.ferry
			var t := maxf(0, clock - 0.5)
			var cycle := fmod(t, 3.0)
			var travel := clampf((cycle - 0.25) / 0.9, 0, 1) if cycle < 1.5 else clampf(1.0 - (cycle - 1.5) / 0.9, 0, 1)
			boat.position.x = boat.initial_position.x + travel * 206
			if id == 27 and clock < 3.5 and p.carrier == boat:
				held += delta
				if held > 0.075:
					boat.set_active(false)
					boat.fallen = 72
			if id == 27 and clock >= 3.5:
				boat.set_active(true)
				boat.fallen = 0
			if id == 28 and started:
				danger(Rect2(96, minf(336, 96 + pow(maxf(0, clock - 1.2), 2) * 1100), 124, 80), clock > 1.2)
		29, 30:
			var lift: TrySurface = surfaces.lift
			if p.carrier == lift: flags.boarded = true
			if flags.get("boarded", false):
				if auxiliary < 0: auxiliary = clock
				var t := clock - auxiliary
				var height := 112.0 if id == 29 else 64.0
				lift.position.y = lift.initial_position.y - minf(height, t * 64)
				if id == 29:
					gate("door", 296, t > 0.55 and t < 1.4, 240, 128)
					danger(Rect2(208, 280, 88, 20), true, Elements.Kind.BEAM)
				else:
					gate("door", 296, t >= 0.95 and t < 2.4, 248, 104)
					danger(Rect2(208, 288, 88, 20), true, Elements.Kind.BEAM)
					if t > 2.2:
						lift.position.y += minf(64, (t - 2.2) * 110)
						danger(Rect2(208,394,88,22),true,Elements.Kind.TEETH)
			else:
				gate("door", 296, false, 240, 128)
		31:
			if p.is_on_floor() and x > 340 and x < 390 and absf(p.velocity.x) < 35: flags.braked = true
			danger(Rect2(402, 304, 26, 112), not flags.get("braked", false) and (not started or clock < 1.8))
		32:
			var boat: TrySurface = surfaces.ferry
			if x > 190 and not flags.get("departed", false):
				flags.departed = true
				auxiliary = clock
			if auxiliary >= 0:
				boat.position.x = boat.initial_position.x + minf(242, (clock - auxiliary) * 120)
				beam(190, 284, clock - auxiliary > 0.067 and clock - auxiliary < 0.8)
		33:
			beam(128, 208)
			if x >= 208 and auxiliary < 0: auxiliary = clock
			var t := clock - auxiliary if auxiliary >= 0 else -1.0
			eruption("reignite:first", Rect2(240, 388, 64, 28), t, 0.2, 0.1, 0.18)
			eruption("reignite:second", Rect2(240, 388, 64, 28), t, 0.6, 0.1, 0.22)
			gate("exit", 344, t > 0.75)
		34:
			if on_plate(p, 220, 60): held += delta
			if held >= 0.3: flags.lowered = true
			collapse("pit", flags.get("lowered", false))
			gate("exit", 384, started and clock > 1.8)
			if started and clock > 0.9 and clock < 1.7:
				blade(24 + (clock - 0.9) * 450)
		35:
			# A normal walk off the upper ledge must actually touch the first latch.
			if on_plate(p, 232, 80, 464): lower_latch("left", p)
			if on_plate(p, 352, 56, 464): lower_latch("right", p)
			lower_exit()
			for key in ["left", "right"]:
				if flags.has(key + "_time"):
					var t: float = clock - flags[key + "_time"]
					eruption("latch:" + key, Rect2(232 if key == "left" else 352, 408, 80 if key == "left" else 56, 56), t, 0.5, 0.2, 0.3)
		36:
			danger(Rect2(208,320,168,16),true,Elements.Kind.BEAM)
			if on_plate(p, 248, 48):
				flags.tripped = true
				if auxiliary < 0:
					auxiliary = clock
					game.sound.effect("click")
			var t := clock - auxiliary if auxiliary >= 0 else -1.0
			closing_gate("a", 208, t)
			closing_gate("b", 340, t)
			# The overhead press travels from its housing instead of appearing on the player.
			var press := clampf((t - 0.1) / 0.28, 0, 1)
			danger(Rect2(232, 208 + press * 112, 104, 96))
		37:
			if x > 208 and not flags.get("impact", false):
				flags.impact = true
				auxiliary = clock
				game.shake = 3
				game.sound.effect("death")
				game.burst(p.position + Vector2(0,-16), Color("f0d6ad"), 16)
				p.false_impact = 0.16
			collapse("pit", auxiliary >= 0 and clock - auxiliary > 0.32)
		39:
			if x >= 560 and not flags.get("finish", false):
				flags.finish = true
				auxiliary = clock
				game.sound.effect("checkpoint")
				game.burst(p.position + Vector2(0,-60), Color("f5d68a"), 24)
			collapse("pit", auxiliary >= 0 and clock - auxiliary > 0.2)
		40:
			var previous: TryEncounter = game.traps[38]
			if previous.auxiliary >= 0: clock = previous.clock - previous.auxiliary
			drop(128, 0.15, 176, 56, 1500, previous.auxiliary >= 0)
	for rect in hazards:
		if p.alive and Elements.touches(visual_kinds.get(rect, Elements.Kind.CRUSHER),Rect2(position+rect.position,rect.size),p.hitbox()):
			p.die("hazard")
	previous_floor = p.is_on_floor()
	queue_redraw()

func _draw() -> void:
	for rect in scenery:
		Elements.hazard(self,rect,visual_kinds.get(rect,Elements.Kind.CRUSHER),1,false)
	for rect in hazards:
		Elements.hazard(self,rect,visual_kinds[rect])
	for item in preparations:
		Elements.hazard(self,item.rect,Elements.Kind.TEETH,item.amount,false)
	if id == 35:
		draw_rect(Rect2(410, 240, 6, 232), Color("48635d"))
		draw_rect(Rect2(440, 240, 6, 232), Color("48635d"))
		draw_rect(Rect2(410, 238, 36, 8), Color("48635d"))
		for at in [Vector2(413,244),Vector2(443,244),Vector2(413,466),Vector2(443,466)]:
			draw_rect(Rect2(at-Vector2(1,1),Vector2(3,3)),Color("c7bf91"))
	if id == 10:
		draw_rect(Rect2(272, 240, 48, 320), Color("4b6e67b8"))
	if id == 39:
		draw_rect(Rect2(536,336,48,80), Color("456858"))
		draw_rect(Rect2(542,342,36,74), Color("e8cb90"))
