class_name TryElements
extends RefCounted

# One vocabulary for appearance, collision policy and editor/runtime groups.
enum Kind { TERRAIN, PLATFORM, BELT, DOOR, RELAY, SPRING, CHAIN, CHARGE, KEY, BLADE, TEETH, CRUSHER, BEAM }
const SOLID_LAYER := 1
const PLAYER_LAYER := 2
const PLAYER_VISUAL_HEIGHT := 37.0
const MIN_HEADROOM := 48.0
const LOW_ROOF_Y := 312.0
const ROOF_THICKNESS := 16.0
const OPENING_ROOF_Y := 256.0
const OPENING_STOW_Y := 224.0
const OPENING_ROOF_WIDTH := 208.0
const SOIL := Color("73594c")
const SOIL_LIGHT := Color("a77954")
const GRASS := Color("3e7f66")
const GRASS_LIGHT := Color("b7d081")
const STEEL_DARK := Color("263f45")
const STEEL := Color("4e7478")
const STEEL_LIGHT := Color("b0d1c8")
const BRASS := Color("d3bd78")
const HAZARD_BODY := Color("39494e")
const HOT_EDGE := Color("ed876c")
const HOT_LIGHT := Color("ffcca1")
const CHARGE := Color("80e5e0")

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
	canvas.draw_rect(rect, SOIL)
	canvas.draw_rect(Rect2(rect.position+Vector2(0,8),Vector2(rect.size.x,15)),SOIL_LIGHT)
	canvas.draw_rect(Rect2(rect.position,Vector2(rect.size.x,7)),GRASS)
	canvas.draw_rect(Rect2(rect.position,Vector2(rect.size.x,3)),GRASS_LIGHT)
	var world_rect := Rect2(rect.position + origin, rect.size)
	for n in range(ceili(world_rect.position.x / 20), ceili(world_rect.end.x / 20)):
		var x := n * 20.0 - origin.x
		canvas.draw_rect(Rect2(x,rect.position.y+7,minf(8,rect.end.x-x),5+absi(n)%3),GRASS)
	if floating:
		canvas.draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-3),Vector2(rect.size.x,3)),Color("4c5a47"))
	else:
		for wy in range(ceili((world_rect.position.y+32)/23)*23, ceili(world_rect.end.y),23):
			for wx in range(ceili((world_rect.position.x+8)/32)*32,int(world_rect.end.x)-8,32):
				canvas.draw_rect(Rect2(wx-origin.x,wy-origin.y,7,3),Color("88654f"))

static func surface(canvas: Node2D, rect: Rect2, kind: int, belt_speed: float = 0) -> void:
	if lethal(kind):
		hazard(canvas,rect,kind)
		return
	canvas.draw_rect(rect,STEEL_DARK)
	if rect.size.x > 4 and rect.size.y > 4: canvas.draw_rect(rect.grow(-2),STEEL)
	canvas.draw_rect(Rect2(rect.position,Vector2(rect.size.x,3)),BRASS if kind == Kind.RELAY else STEEL_LIGHT)
	if rect.size.x >= 20:
		for x in [rect.position.x+5,rect.end.x-7]:
			canvas.draw_rect(Rect2(x,rect.position.y+6,2,2),BRASS if kind in [Kind.RELAY,Kind.DOOR] else STEEL_LIGHT)
	if kind == Kind.BELT:
		var direction := signf(belt_speed)
		for x in range(int(rect.position.x)+8,int(rect.end.x)-6,16):
			canvas.draw_polyline(PackedVector2Array([Vector2(x-3*direction,rect.position.y+7),Vector2(x+2*direction,rect.position.y+10),Vector2(x-3*direction,rect.position.y+13)]),STEEL_DARK,2)

static func hazard(canvas: Node2D, rect: Rect2, kind: int, amount: float = 1, armed: bool = true) -> void:
	var edge := HOT_EDGE if armed else STEEL_LIGHT
	if kind == Kind.BLADE:
		var center := rect.get_center()
		var radius := minf(rect.size.x,rect.size.y)/2
		canvas.draw_circle(center,radius,STEEL_DARK)
		canvas.draw_arc(center,radius-2,0,TAU,16,edge,3)
		canvas.draw_circle(center,3,BRASS)
		for n in 6:
			var angle := n * TAU / 6
			canvas.draw_line(center+Vector2.from_angle(angle)*4,center+Vector2.from_angle(angle)*(radius-3),STEEL_LIGHT,1)
		return
	if kind == Kind.TEETH:
		var height := maxf(1, rect.size.y * amount)
		if height > 2: canvas.draw_rect(Rect2(rect.position.x,rect.end.y-height,rect.size.x,height),HAZARD_BODY)
		for x in range(int(rect.position.x)+2,int(rect.end.x)-6,10):
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x,rect.end.y),Vector2(x+4,rect.end.y-height),Vector2(x+8,rect.end.y)]),edge)
		return
	canvas.draw_rect(rect,STEEL_DARK)
	if rect.size.x > 4 and rect.size.y > 4: canvas.draw_rect(rect.grow(-2),HAZARD_BODY)
	canvas.draw_rect(rect,edge,false,2)
	for x in range(int(rect.position.x)+6,int(rect.end.x)-4,16):
		canvas.draw_line(Vector2(x,rect.position.y+3),Vector2(x+4,rect.position.y+7),HOT_LIGHT if armed else STEEL,2)

static func charge(canvas: Node2D, key: bool = false) -> void:
	var tint := BRASS if key else CHARGE
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(9,0),Vector2(0,13),Vector2(-9,0)]),STEEL_DARK)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-10),Vector2(6,0),Vector2(0,10),Vector2(-6,0)]),tint)
	canvas.draw_line(Vector2(-2,-5),Vector2(2,-1),Color("f4ecd4"),2)
