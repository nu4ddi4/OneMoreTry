class_name TryCourse
extends RefCounted

const CELL := 640.0
const COUNT := 40
const LENGTH := CELL * COUNT
const FLOOR := 416.0
const GOAL := LENGTH - 64.0
const CHECKPOINTS := [Vector2(CELL * 16 + 32, FLOOR), Vector2(CELL * 32 + 32, FLOOR)]
const SECRET := Vector2(CELL * 23 + 330, 440)

# Developer identifiers only. Nothing in this table is shown to the player.
const NAMES := ["first_jump", "false_landing", "late_jump", "waiting_pit", "retreat", "reversing_platform", "bait", "bridge_pickup", "chaser", "obscured_gap", "false_shadow", "true_shadow", "hammer_wall", "release_plate", "head_bridge", "head_bait", "second_beat", "first_beat", "footprints", "spent_tile", "return_blade", "high_return", "hold_plate", "break_floor", "fast_belt", "reverse_belt", "second_ferry", "first_ferry", "leave_lift", "ride_lift", "air_brake", "drop_ferry", "reignite", "hide_below", "both_switches", "skip_plate", "false_impact", "combination", "false_finish", "final_brake"]

static func rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x, y, w, h)

static func definition(number: int) -> Dictionary:
	var d := {"id": number, "name": NAMES[number - 1], "x": (number - 1) * CELL, "gaps": [], "solids": [], "surfaces": [], "devices": []}
	match number:
		2, 38:
			d.gaps = [Vector2(190, 432)]
			d.solids = [rect(254, FLOOR, 44, 180)]
			d.surfaces = [["false", rect(298, FLOOR, 100, 18)]]
		4:
			d.gaps = [Vector2(196, 284)]
			d.surfaces = [["pit", rect(196, FLOOR, 88, 18)]]
		6:
			d.gaps = [Vector2(190, 496)]
			d.surfaces = [["platform", rect(232, FLOOR, 72, 18)]]
		7:
			d.devices = [["bait", Vector2(252, 366)]]
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
		15:
			d.gaps = [Vector2(256, 504)]
			d.surfaces = [["bridge", rect(256, FLOOR, 248, 18), false]]
		16:
			d.solids = [rect(244, FLOOR - 16, 32, 16)]
			d.gaps = [Vector2(128, 208)]
			d.surfaces = [["pit", rect(128, FLOOR, 80, 18)]]
		17:
			d.gaps = [Vector2(248, 302)]
			d.surfaces = [["pit", rect(248, FLOOR, 54, 18)]]
		20:
			d.gaps = [Vector2(384, 624)]
			d.devices = [["chain", Vector2(460, 176)]]
		22:
			d.devices = [["double", Vector2(444, 370)]]
		23:
			d.devices = [["chain", Vector2(480, 160)]]
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
			if number == 28:
				d.devices = [["chain", Vector2(354, 180)]]
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
			d.gaps = [Vector2(224, 416)]
			d.solids = [rect(208, FLOOR + 48, 224, 20)]
			d.devices = [["chain", Vector2(448, 156)]]
		37:
			d.gaps = [Vector2(208, 288)]
			d.surfaces = [["pit", rect(208, FLOOR, 80, 18)]]
		39:
			d.gaps = [Vector2(544, 608)]
			d.surfaces = [["pit", rect(544, FLOOR, 64, 18)]]
	return d

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for number in range(1, COUNT + 1):
		result.append(definition(number))
	return result
