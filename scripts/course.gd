class_name TryCourse
extends RefCounted

const Elements = preload("res://scripts/elements.gd")

const COUNT := 40
const WIDTHS := [736, 672, 608, 816, 592, 784, 560, 720, 608, 896, 560, 752, 624, 848, 608, 576, 672, 592, 704, 864, 608, 800, 736, 720, 592, 688, 880, 640, 752, 608, 784, 672, 592, 752, 896, 560, 704, 816, 640, 736]
const OFFSETS := [0, 736, 1408, 2016, 2832, 3424, 4208, 4768, 5488, 6096, 6992, 7552, 8304, 8928, 9776, 10384, 10960, 11632, 12224, 12928, 13792, 14400, 15200, 15936, 16656, 17248, 17936, 18816, 19456, 20208, 20816, 21600, 22272, 22864, 23616, 24512, 25072, 25776, 26592, 27232]
const LENGTH := 27968.0
const FLOOR := 416.0
const GOAL := LENGTH - 64.0
const CHECKPOINTS := [Vector2(10992, FLOOR), Vector2(22304, FLOOR)]
const SECRET := Vector2(16266, 440)

static func origin(number: int) -> float:
	return float(OFFSETS[clampi(number - 1, 0, COUNT - 1)])

static func width(number: int) -> float:
	return float(WIDTHS[clampi(number - 1, 0, COUNT - 1)])

static func number_at(x: float) -> int:
	for n in range(COUNT - 1, -1, -1):
		if x >= OFFSETS[n]: return n + 1
	return 1

# Developer identifiers only. Nothing in this table is shown to the player.
const NAMES := ["first_jump", "false_landing", "late_jump", "waiting_pit", "retreat", "reversing_platform", "bait", "bridge_pickup", "chaser", "obscured_gap", "false_shadow", "true_shadow", "hammer_wall", "release_plate", "head_bridge", "head_bait", "second_beat", "first_beat", "footprints", "spent_tile", "return_blade", "high_return", "hold_plate", "break_floor", "fast_belt", "reverse_belt", "second_ferry", "first_ferry", "leave_lift", "ride_lift", "air_brake", "drop_ferry", "reignite", "hide_below", "both_switches", "skip_plate", "false_impact", "combination", "false_finish", "final_brake"]

static func rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x, y, w, h)

static func definition(number: int) -> Dictionary:
	var d := {"id": number, "name": NAMES[number - 1], "x": origin(number), "width": width(number), "sensor": 208.0 if number == 3 else (192.0 if number == 13 else 112.0), "gaps": [], "solids": [], "climbable_solids": [], "surfaces": [], "devices": []}
	match number:
		1:
			d.solids = [rect(240, FLOOR - 32, 64, 32), rect(448, FLOOR - 64, 48, 64)]
		2, 38:
			d.gaps = [Vector2(190, 432)]
			d.solids = [rect(254, FLOOR, 44, 180)]
			d.surfaces = [["false", rect(298, FLOOR, 100, 18)]]
		4:
			d.gaps = [Vector2(196, 284)]
			d.surfaces = [["pit", rect(196, FLOOR, 88, 18)], ["switch", rect(128, 344, 32, 16), true, 0.0, Elements.Kind.RELAY]]
		6:
			d.gaps = [Vector2(190, 496)]
			d.surfaces = [["platform", rect(232, FLOOR, 72, 18)]]
		7:
			d.devices = [["double", Vector2(252, 366)]]
			d.solids = [rect(364, 280, 32, 136)]
		8:
			d.gaps = [Vector2(216, 488)]
			d.devices = [["key", Vector2(168, 370)]]
			d.surfaces = [["bridge", rect(216, FLOOR, 272, 18), false]]
		10:
			d.gaps = [Vector2(228, 492)]
			d.devices = [["double", Vector2(170, 372)]]
		12:
			d.devices = [["pad", Vector2(300, FLOOR)]]
			d.solids = [rect(394, 268, 132, 20)]
		13:
			d.gaps = [Vector2(184, 280)]
			d.solids = [rect(112, FLOOR - 48, 64, 16)]
			d.surfaces = [["pit", rect(184, FLOOR, 96, 18)]]
		14:
			d.solids = [rect(344, 224, 32, 192), rect(414, 224, 100, 16)]
			d.climbable_solids = [0]
		15:
			d.gaps = [Vector2(256, 504)]
			d.surfaces = [["bridge", rect(256, FLOOR, 248, 18), false]]
		16:
			d.solids = [rect(244, FLOOR - 16, 32, 16)]
			d.gaps = [Vector2(128, 208)]
			d.surfaces = [["pit", rect(128, FLOOR, 80, 18)]]
		17:
			d.devices = [["double", Vector2(120, 392)]]
			d.solids = [rect(96, 304, 40, 16)]
			d.gaps = [Vector2(248, 302)]
			d.surfaces = [["pit", rect(248, FLOOR, 54, 18)], ["skyway", rect(176, 240, width(17) + width(18) + width(19) + 128, 16), true, 180.0]]
		20:
			d.gaps = [Vector2(384, 624)]
			d.devices = [["chain", Vector2(460, 176)]]
		22:
			d.devices = [["double", Vector2(444, 370)]]
		23:
			d.gaps = [Vector2(432, 704)]
			d.devices = [["chain", Vector2(480, 160)], ["double", Vector2(568, 230)]]
			d.solids = [rect(616, 200, 32, 216), rect(648, 200, 40, 16)]
		24:
			d.gaps = [Vector2(208, 416)]
			d.solids = [rect(176, FLOOR + 64, 240, 28)]
			d.surfaces = [["weak", rect(208, FLOOR, 144, 18)]]
			d.devices = [["pad", Vector2(168, FLOOR)]]
		25:
			d.gaps = [Vector2(128, 300), Vector2(332, 426)]
			d.surfaces = [["belt", rect(128, FLOOR, 172, 18), true, 100.0]]
		26:
			d.gaps = [Vector2(160, 332)]
			d.surfaces = [["belt", rect(160, FLOOR, 172, 18), true, -100.0]]
		27, 28:
			d.gaps = [Vector2(190, 496)]
			d.surfaces = [["ferry", rect(216, FLOOR, 80, 18)]]
			d.devices = [["chain", Vector2(354, 180)]]
			if number == 27: d.devices.append(["double", Vector2(174, 372)])
		29, 30:
			d.gaps = [Vector2(208, 432)]
			d.surfaces = [["lift", rect(208, FLOOR, 88, 18)]]
			d.solids = [rect(296, FLOOR - (48 if number == 29 else 64), 168, 18)]
		31:
			d.gaps = [Vector2(190, 428)]
			d.solids = [rect(350, FLOOR, 52, 140)]
			d.devices = [["double", Vector2(154, 370)]]
		32:
			d.gaps = [Vector2(190, 480)]
			d.surfaces = [["ferry", rect(238, FLOOR + 48, 96, 18)]]
		33:
			d.devices = [["chain", Vector2(480, 160)]]
		34:
			d.gaps = [Vector2(220, 280)]
			d.solids = [rect(208, FLOOR + 48, 88, 18)]
			d.surfaces = [["pit", rect(220, FLOOR, 60, 16)]]
		35:
			d.surfaces = [["exit", rect(416, 248, 24, 216)]]
			d.gaps = [Vector2(224, 416)]
			d.solids = [rect(208, FLOOR + 48, 224, 20)]
			d.devices = [["chain", Vector2(448, 156)]]
		37:
			d.gaps = [Vector2(208, 288)]
			d.surfaces = [["pit", rect(208, FLOOR, 80, 18)]]
		39:
			d.gaps = [Vector2(544, 608)]
			d.surfaces = [["pit", rect(544, FLOOR, 64, 18)]]
	# Entry positions are distributed independently of the editing boundaries.
	if number in [2, 7, 8, 10, 15, 16, 19, 23, 24, 26, 28, 31, 35, 36, 37, 39]:
		d.sensor = {2: 136.0, 7: 164.0, 8: 148.0, 10: 160.0, 15: 128.0, 16: 96.0, 19: 88.0, 23: 176.0, 24: 144.0, 26: 128.0, 28: 136.0, 31: 144.0, 35: 184.0, 36: 168.0, 37: 192.0, 39: 320.0}[number]
	return d

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for number in range(1, COUNT + 1):
		result.append(definition(number))
	return result
