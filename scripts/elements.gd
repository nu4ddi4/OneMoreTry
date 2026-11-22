class_name TryElements
extends RefCounted

const Art = preload("res://scripts/pixel_art.gd")

# One vocabulary for appearance, collision policy and editor/runtime groups.
enum Kind { TERRAIN, PLATFORM, BELT, DOOR, RELAY, SPRING, CHAIN, CHARGE, KEY, BLADE, TEETH, CRUSHER, BEAM }
const SOLID_LAYER := 1
const PLAYER_LAYER := 2
const PLAYER_VISUAL_HEIGHT := 37.0
const MIN_HEADROOM := 6.0
const LOW_ROOF_Y := 352.0
const ROOF_THICKNESS := 20.0
const OPENING_ROOF_Y := 304.0
const OPENING_ROOF_WIDTH := 168.0
const OPENING_ROOF_THICKNESS := 18.0
const STEEL_DARK := Art.INK
const STEEL := Art.STEEL
const STEEL_LIGHT := Art.STEEL_LIGHT
const BRASS := Art.BRASS
const CHARGE := Art.BRASS

static func family(kind: int) -> StringName:
	match kind:
		Kind.TERRAIN: return &"terrain"
		Kind.PLATFORM, Kind.BELT: return &"platforms"
		Kind.DOOR, Kind.RELAY: return &"mechanisms"
		Kind.SPRING, Kind.CHAIN: return &"traversal"
		Kind.CHARGE, Kind.KEY: return &"pickups"
		_: return &"hazards"

static func lethal(kind: int) -> bool:
	return kind in [Kind.BLADE, Kind.TEETH, Kind.CRUSHER, Kind.BEAM]

static func touches(kind: int, rect: Rect2, body: Rect2) -> bool:
	if kind == Kind.BLADE:
		var center := rect.get_center()
		var nearest := Vector2(clampf(center.x, body.position.x, body.end.x), clampf(center.y, body.position.y, body.end.y))
		return center.distance_squared_to(nearest) < pow(minf(rect.size.x,rect.size.y) / 2, 2)
	return rect.intersects(body)

static func terrain(canvas: Node2D, rect: Rect2, floating: bool = false, origin: Vector2 = Vector2.ZERO) -> void:
	canvas.draw_rect(rect, Art.SOIL)
	strip(canvas, rect, 0, 4, Art.GRASS_LIGHT)
	strip(canvas, rect, 4, 8, Art.GRASS)
	strip(canvas, rect, 12, 4, Art.CLAY)
	var world_rect := Rect2(rect.position + origin, rect.size)
	# Visible and disguised ground share the same masonry grid at both seams.
	for column in range(floori(world_rect.position.x / 24), ceili(world_rect.end.x / 24)):
		var edge := Rect2(column * 24.0 - origin.x, rect.position.y + 4, 2, 12).intersection(rect)
		if edge.has_area():
			canvas.draw_rect(edge, Art.CLAY)
	for row in range(1, ceili(rect.size.y / 18)):
		var stagger := posmod(row, 2) * 12
		for column in range(floori((world_rect.position.x - stagger) / 24), ceili((world_rect.end.x - stagger) / 24)):
			var at := Vector2(column * 24.0 + stagger - origin.x, rect.position.y + row * 18)
			var variation := posmod(column * 17 + row * 11, 9)
			var length := 12 + 2 * posmod(variation, 5)
			var stone := Rect2(at, Vector2(length, 4 + 2 * posmod(variation, 2))).intersection(rect)
			if stone.has_area():
				canvas.draw_rect(stone, Art.LOAM)
			var chip := Rect2(at + Vector2(2, 6), Vector2(length - 8, 2)).intersection(rect)
			if variation > 3 and chip.has_area():
				canvas.draw_rect(chip, Art.CLAY)
	if floating:
		strip(canvas, rect, maxf(0, rect.size.y - 2), 2, Art.INK)

static func strip(canvas: Node2D, rect: Rect2, offset: float, height: float, color: Color) -> void:
	var band := Rect2(rect.position + Vector2(0, offset), Vector2(rect.size.x, height)).intersection(rect)
	if band.has_area():
		canvas.draw_rect(band, color)

static func surface(canvas: Node2D, rect: Rect2, kind: int, belt_speed: float = 0, belt_phase: float = 0) -> void:
	if lethal(kind):
		hazard(canvas, rect, kind)
		return
	canvas.draw_rect(rect, Art.INK)
	var face := rect.grow(-2)
	if face.has_area():
		canvas.draw_rect(face, Art.STEEL)
	strip(canvas, rect, 0, 2, Art.BRASS if kind == Kind.RELAY else Art.STEEL_LIGHT)
	if rect.size.x >= 20 and rect.size.y >= 10:
		for x in [rect.position.x + 4, rect.end.x - 6]:
			Art.block(canvas, Vector2(x, rect.position.y + 4), Vector2(2, 2), Art.BRASS)
	if kind == Kind.BELT:
		var direction := signf(belt_speed)
		var phase := fposmod(snappedf(belt_phase, Art.DOT), 16.0)
		for x in range(-16, ceili(rect.size.x), 16):
			for step in 3:
				var offset := Vector2(x + phase + step * direction * 2, 6 + step * 2)
				var marker := Rect2(rect.position + offset, Vector2(2, 2)).intersection(rect)
				if marker.has_area():
					canvas.draw_rect(marker, Art.INK)

static func hazard(canvas: Node2D, rect: Rect2, kind: int, amount: float = 1, armed: bool = true, spin: float = 0) -> void:
	var edge := Art.ORANGE if armed else Art.STEEL_LIGHT
	if kind == Kind.BLADE:
		var radius := minf(rect.size.x, rect.size.y) / 2
		var center := rect.get_center()
		for y in range(-10, 11, 2):
			for x in range(-10, 11, 2):
				var offset := Vector2(x, y)
				var distance := offset.length()
				if distance > radius - Art.DOT / 2:
					continue
				var tooth := cos((offset.angle() - spin) * 8)
				var rim := distance >= radius - 4
				var color := Art.INK
				if distance <= 2:
					color = Art.BRASS
				elif rim:
					color = edge if tooth >= -0.35 else Art.SHADE
				elif tooth > 0.6:
					color = Art.STEEL_LIGHT
				Art.block(canvas, center + offset - Vector2.ONE, Vector2.ONE * Art.DOT, color)
		return
	if kind == Kind.TEETH:
		var height := rect.size.y * amount
		if height <= 0:
			return
		var exposed := Rect2(rect.position.x, rect.end.y - height, rect.size.x, height)
		canvas.draw_rect(exposed, Art.SHADE)
		for x in range(0, ceili(rect.size.x), 12):
			for column in 6:
				var edge_height := height * (1.0 - absf(column - 2.5) / 3.0)
				var tooth := Rect2(rect.position.x + x + column * 2, rect.end.y - edge_height, 2, edge_height).intersection(exposed)
				if tooth.has_area():
					canvas.draw_rect(tooth, edge)
		return
	canvas.draw_rect(rect, edge)
	var inset := rect.grow(-2)
	if inset.has_area():
		canvas.draw_rect(inset, Art.SHADE)
	for x in range(4, ceili(rect.size.x - 2), 12):
		for n in 3:
			var mark := Rect2(rect.position + Vector2(x + n * 2, 4 + n * 2), Vector2(2, 2)).intersection(inset)
			if inset.has_area() and mark.has_area():
				canvas.draw_rect(mark, Art.BRASS if armed else Art.STEEL)

static func cutter_socket(canvas: Node2D, x: float, width: float, floor_y: float) -> void:
	var at := Vector2(x - 2, floor_y)
	Art.block(canvas, at, Vector2(width + 4, 26), Art.INK)
	Art.block(canvas, at + Vector2(2, 2), Vector2(4, 22), Art.CLAY)
	Art.block(canvas, at + Vector2(width - 2, 2), Vector2(4, 22), Art.CLAY)
	Art.block(canvas, at + Vector2(0, 24), Vector2(width + 4, 2), Art.BRASS)

static func cutter(canvas: Node2D, rect: Rect2) -> void:
	# Draw within the danger rectangle, including a shallow rim at the root of the teeth.
	canvas.draw_rect(rect, Art.ORANGE)
	var blade_face := rect.grow_individual(-8, -2, -4, -2)
	if blade_face.has_area():
		canvas.draw_rect(blade_face, Art.CLAY)
	var spine := Rect2(rect.end.x - 4, rect.position.y, 4, rect.size.y)
	canvas.draw_rect(spine, Art.INK)
	for y in range(0, ceili(rect.size.y), 16):
		for step in 8:
			var point := ceili(absf(step - 2.5)) * 2
			var shadow := Rect2(rect.position + Vector2(0, y + step * 2), Vector2(point, 2)).intersection(rect)
			var edge := Rect2(rect.position + Vector2(point, y + step * 2), Vector2(3, 2)).intersection(rect)
			if shadow.has_area():
				canvas.draw_rect(shadow, Art.SOIL)
			if edge.has_area():
				canvas.draw_rect(edge, Art.CUTTING_EDGE)
		var rivet := Rect2(rect.position + Vector2(rect.size.x - 8, y + 6), Vector2(2, 2)).intersection(rect)
		if rivet.has_area():
			canvas.draw_rect(rivet, Art.BRASS)
	strip(canvas, rect, 0, 2, Art.CUTTING_EDGE)

static func charge(canvas: Node2D, key: bool = false) -> void:
	var tint := Art.BRASS if key else Art.CREAM
	for row in range(-6, 7):
		var half_width := maxi(2, 10 - absi(row) * 2)
		Art.block(canvas, Vector2(-half_width, row * 2), Vector2(half_width * 2, 2), Art.INK)
		if absi(row) <= 4:
			Art.block(canvas, Vector2(-half_width + 2, row * 2), Vector2(half_width * 2 - 4, 2), tint)
	Art.block(canvas, Vector2(-4, -6), Vector2(2, 4), Art.CREAM)

static func climb_wall(canvas: Node2D, rect: Rect2) -> void:
	for x in [rect.position.x, rect.end.x - 4]:
		Art.block(canvas, Vector2(x, rect.position.y), Vector2(4, rect.size.y), Art.INK)
		for y in range(int(rect.position.y) + 8, int(rect.end.y) - 4, 16):
			Art.block(canvas, Vector2(x, y), Vector2(4, 4), Art.STEEL_LIGHT)

static func door(canvas: Node2D, rect: Rect2) -> void:
	canvas.draw_rect(rect, Art.INK)
	canvas.draw_rect(rect.grow(-4), Art.GRASS)
	var opening := rect.grow_individual(-10, -10, -10, 0)
	canvas.draw_rect(opening, Art.BRASS)
	Art.block(canvas, opening.position, Vector2(4, opening.size.y), Art.CLAY)
	for x in [rect.position.x + 4, rect.end.x - 6]:
		Art.block(canvas, Vector2(x, rect.position.y + 4), Vector2(2, 2), Art.CREAM)
	Art.block(canvas, opening.get_center() + Vector2(4, 0), Vector2(4, 4), Art.INK)
