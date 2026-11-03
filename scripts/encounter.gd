class_name TryEncounter
extends Node2D

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
var flags: Dictionary = {}
var samples: Array[float] = []
var held := 0.0
var auxiliary := -1.0
var previous_floor := false

func _ready() -> void:
	process_physics_priority = 10
	id = definition.id
	position.x = definition.x
	for entry in definition.surfaces:
		make_surface(entry[0], entry[1], entry[2] if entry.size() > 2 else true, entry[3] if entry.size() > 3 else 0.0)
	for entry in definition.devices:
		var device := Device.new()
		device.kind = entry[0]
		device.position = entry[1]
		device.game = game
		device.encounter = self
		add_child(device)
		devices.append(device)

func make_surface(key: String, rect: Rect2, active: bool = true, belt: float = 0) -> TrySurface:
	var surface := Surface.new()
	surface.game = game
	surface.position = rect.position
	surface.dimensions = rect.size
	surface.initial_active = active
	surface.belt_speed = belt
	surface.camouflaged = key in ["false", "pit", "weak"] and rect.position.y == TryCourse.FLOOR
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

func danger(rect: Rect2, active: bool = true) -> void:
	if active and rect.size.x > 0 and rect.size.y > 0:
		hazards.append(rect)

func beam(x: float, width: float, active: bool = true) -> void:
	danger(Rect2(x, 368, width, 20), active)

func blade(x: float, y: float = 394, width: float = 26) -> void:
	danger(Rect2(x, y, width, 22))

func gate(key: String, x: float, opened: bool, y: float = 248, height: float = 168) -> void:
	if not surfaces.has(key):
		make_surface(key, Rect2(x, y, 24, height), false)
	var surface: TrySurface = surfaces[key]
	if surface.active == opened:
		surface.set_active(not opened)
	danger(Rect2(x, y, 24, height).grow(2), not opened)

func drop(x: float, delay: float, start_y: float = 176, width: float = 56, gravity: float = 1500) -> void:
	var t := maxf(0, clock - delay)
	var y := minf(368, start_y + gravity * t * t / 2.0)
	danger(Rect2(x, y, width, 48), clock >= delay)

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
			danger(Rect2(176, 304, 168, 18), started and clock > 0.025)
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
				danger(Rect2(424, 388, 64, 28), clock - auxiliary > 0.5 and clock - auxiliary < 1.1)
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
			if started:
				drop(284, 0.2)
		12:
			if started:
				drop(196, 0.1, 320, 56, 2000)
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
				make_surface("head", block)
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
						danger(Rect2(samples[n] - 24, 388, 48, 28), clock >= n * 0.1 + 0.3 and clock < n * 0.1 + 0.4)
		20:
			if on_plate(p, 152, 40) and auxiliary < 0: auxiliary = clock
			var t := clock - auxiliary if auxiliary >= 0 else -1.0
			for n in 3:
				danger(Rect2(160 + n * 80, 388, 32, 28), t >= 0.2 + n * 0.267 and t < 0.3 + n * 0.267)
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
					blade(bx, 338 if id == 22 and t >= turn else 394)
		23:
			gate("a", 208, not started or clock < 1.35)
			if on_plate(p, 272, 48): held += delta
			else: held = 0
			if held >= 0.4: flags.open = true
			gate("b", 368, flags.get("open", false))
			danger(Rect2(264, 320, 80, 96), started and clock > 2.2)
			# The next obstacle continues above the pit rather than returning to flat ground.
		24:
			danger(Rect2(344, 200, 96, 18))
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
					danger(Rect2(208, 280, 88, 20))
				else:
					gate("door", 296, t >= 0.95 and t < 2.4, 248, 104)
					danger(Rect2(208, 288, 88, 20))
					if t > 2.2:
						lift.position.y += minf(64, (t - 2.2) * 110)
						blade(208, 394, 88)
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
			danger(Rect2(240, 388, 64, 28), (t > 0.2 and t < 0.3) or (t > 0.6 and t < 0.7))
			gate("exit", 344, t > 0.75)
		34:
			if on_plate(p, 220, 60): held += delta
			if held >= 0.3: flags.lowered = true
			collapse("pit", flags.get("lowered", false))
			gate("exit", 384, started and clock > 1.8)
			if started and clock > 0.9 and clock < 1.7:
				blade(24 + (clock - 0.9) * 450)
		35:
			if on_plate(p, 232, 40, 464): flags.left = true
			if on_plate(p, 368, 40, 464): flags.right = true
			gate("exit", 416, flags.get("left", false) and flags.get("right", false), 248, 216)
			for key in ["left", "right"]:
				if flags.get(key, false) and not flags.has(key + "_time"): flags[key + "_time"] = clock
				if flags.has(key + "_time"):
					var t: float = clock - flags[key + "_time"]
					danger(Rect2(232 if key == "left" else 368, 408, 32, 56), t > 0.2 and t < 0.5)
		36:
			danger(Rect2(208, 320, 168, 16))
			if on_plate(p, 248, 48):
				flags.tripped = true
				if auxiliary < 0: auxiliary = clock
			gate("a", 208, not flags.get("tripped", false) or clock - auxiliary < 0.05)
			gate("b", 340, not flags.get("tripped", false) or clock - auxiliary < 0.05)
			danger(Rect2(232, 320, 104, 96), auxiliary >= 0 and clock - auxiliary > 0.3)
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
			if previous.auxiliary >= 0:
				clock = previous.clock - previous.auxiliary
				drop(128, 0.15)
	for rect in hazards:
		if p.alive and p.hitbox().intersects(Rect2(position + rect.position, rect.size)):
			p.die("hazard")
	previous_floor = p.is_on_floor()
	queue_redraw()

func _draw() -> void:
	for rect in hazards:
		draw_rect(rect, Color("674e57"))
		if rect.size.y == 22 and rect.size.x <= 28:
			var center := rect.get_center()
			draw_circle(center, 9, Color("d9bf93"))
			draw_arc(center, 5, 0, TAU, 12, Color("edf0ce"), 2)
			draw_circle(center, 2, Color("67565a"))
		elif rect.size.y == 28:
			draw_rect(rect.grow(-2), Color("cf7866"))
			for x in range(int(rect.position.x) + 3, int(rect.end.x) - 5, 10):
				draw_colored_polygon(PackedVector2Array([Vector2(x,rect.end.y-2),Vector2(x+4,rect.position.y+2),Vector2(x+8,rect.end.y-2)]), Color("f3ca82"))
		elif rect.size.y == 48:
			draw_rect(rect.grow(-3), Color("b0aaa0"))
			draw_rect(rect.grow(-8), Color("77857b"))
			for offset in [Vector2(5,5), Vector2(rect.size.x-8,5),Vector2(5,40),Vector2(rect.size.x-8,40)]:
				draw_rect(Rect2(rect.position+offset,Vector2(3,3)), Color("eee0b3"))
		else:
			draw_rect(rect.grow(-3), Color("c99a77"))
		if rect.size.x > 28 and rect.size.y != 28:
			for x in range(int(rect.position.x) + 5, int(rect.end.x) - 4, 12):
				draw_line(Vector2(x, rect.position.y + 3), Vector2(x + 6, rect.position.y + 9), Color("f6dbab"), 2)
	if id == 10:
		draw_rect(Rect2(272, 240, 48, 320), Color("4b6e67b8"))
	if id == 39:
		draw_rect(Rect2(536,336,48,80), Color("456858"))
		draw_rect(Rect2(542,342,36,74), Color("e8cb90"))
