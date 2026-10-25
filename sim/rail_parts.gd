class_name RailParts
extends RefCounted
## The railway as structures that break (the director 2026-10-25, on trains.mp4: "the kaiju just
## clips right into the building, zero carve, it needs to be destroyed with the same logic as all
## other buildings"; "if buildings fall on the track they should damage it too"; asked whether the
## railway itself should break, "Yes, all of it"). The viaduct is column bents (two pillars each),
## the deck spans between them, the station's platform segments and its stairs; each is a part with
## a box, a toughness and what holds it up. The kaiju's body (BodyVolume's discs, swept as it sweeps
## buildings), a hit (RampageSim.hit_area's force), a toppling tower (Collapse) and the registry's
## destroy all break parts alike; a part whose support is gone falls (spans, platforms), landing in
## the street, and a fallen span breaks the track there and derails a train on it. Pure and seeded
## like the rest of the sim: ids are list positions; the view reads the parts and the events
## rail_part_broken and rail_part_landed. Every number: tuning "rail" and "rail_look".

const PILLAR := "pillar"
const SPAN := "span"
const STATION := "station"
const STAIRS := "stairs"


class Part:
	var id := 0
	var kind := ""
	## -1 west, +1 east of the deck; 0 on it.
	var side := 0
	## Centre x, half width across x, and the along-z range of its box (world).
	var x := 0.0
	var half := 0.0
	var z0 := 0.0
	var z1 := 0.0
	var y0 := 0.0
	var y1 := 0.0
	var hp := 0.0
	var alive := true
	## Seconds it has been falling (< 0: not), how long the fall takes, and whether it is down (a
	## pillar that snaps never falls).
	var fall_t := -1.0
	var fall_for := 0.0
	var landed := false
	## Part ids that hold it up: it falls when any of them is gone.
	var supports: Array[int] = []

	func box() -> Rect2:
		return Rect2(x - half, z0, half * 2.0, z1 - z0)

	func middle() -> Vector2:
		return Vector2(x, (z0 + z1) * 0.5)


var list: Array[Part] = []
var sim: RampageSim
var cfg: Dictionary
var _x := 0.0
var _gravity := 30.0
## How far from the deck's middle the widest part reaches across x.
var _wide := 0.0


## x: the viaduct's middle; z0..z1: the deck's ends (the station sits station_share of the way).
func _init(p_sim: RampageSim, tuning: Dictionary, x: float, z0: float, z1: float) -> void:
	sim = p_sim
	cfg = tuning["rail"]
	_x = x
	_gravity = Num.f(tuning["city"]["fall_gravity"])
	var look: Dictionary = tuning["rail_look"]
	var bents := _bents(z0, z1, Num.f(look["bent_every"]))
	var columns := _pillars(bents)
	_spans(z0, z1, bents, columns)
	_station(z0, z1, Num.f(look["platform"]))
	for part: Part in list:
		_wide = maxf(_wide, absf(part.x - _x) + part.half)


func _vox() -> float:
	return Num.f(cfg["voxel"])


func _deck_half_cells() -> int:
	return roundi(Num.f(cfg["deck_width"]) * 0.5 / _vox())


func _add(kind: String, side: int, x: float, half: float, zr: Vector2, ys: Vector2) -> Part:
	var part := Part.new()
	part.id = list.size()
	part.kind = kind
	part.side = side
	part.x = x
	part.half = half
	part.z0 = zr.x
	part.z1 = zr.y
	part.y0 = ys.x
	part.y1 = ys.y
	part.hp = Num.f(cfg["part_hp"][kind])
	list.append(part)
	return part


## The bents' z: every bent_every on the world grid, inside the deck (as the model places them).
func _bents(z0: float, z1: float, every: float) -> Array[float]:
	var out: Array[float] = []
	var k := ceili(z0 / every)
	while k * every <= z1:
		out.append(k * every)
		k += 1
	return out


## Two pillars to a bent, inside the deck's edges; returns the pillar ids of each bent.
func _pillars(bents: Array[float]) -> Array:
	var cx := roundi(_x / _vox())
	var top := Num.f(cfg["deck_y"]) - _vox()
	var out: Array = []
	for z: float in bents:
		var ids: Array[int] = []
		for side: int in [-1, 1]:
			var x := (cx + side * (_deck_half_cells() - 2)) * _vox()
			var zr := Vector2(z, z + _vox() * 2.0)
			ids.append(_add(PILLAR, side, x, _vox() * 0.5, zr, Vector2(0.0, top)).id)
		out.append(ids)
	return out


## The deck between the ends and the bents: each span rests on the bents at its ends.
func _spans(z0: float, z1: float, bents: Array[float], columns: Array) -> void:
	var edges: Array[float] = [z0]
	edges.append_array(bents)
	edges.append(z1)
	var half := _deck_half_cells() * _vox() + _vox() * 0.5
	var deck := Num.f(cfg["deck_y"])
	var ys := Vector2(deck - _vox() * 1.2, deck + _vox() * 3.0)
	for k: int in edges.size() - 1:
		if edges[k + 1] - edges[k] < _vox():
			continue
		var span := _add(SPAN, 0, _x, half, Vector2(edges[k], edges[k + 1]), ys)
		if k >= 1:
			var west: Array = columns[k - 1]
			span.supports.append_array(west)
		if k < bents.size():
			var east: Array = columns[k]
			span.supports.append_array(east)


## The station's platform segments (each side, resting on the span under them) and its stairs.
func _station(z0: float, z1: float, platform: float) -> void:
	var south := z0 + (z1 - z0) * Num.f(cfg["station_share"])
	var long := Rail.station_long(cfg)
	var north := south - long
	var seg := Num.f(cfg["station_seg"])
	var deck := Num.f(cfg["deck_y"])
	var ys := Vector2(deck - _vox() * 0.5, deck + 10.0 * _vox())
	for side: int in [-1, 1]:
		var x := _x + side * ((_deck_half_cells() + 1) * _vox() + platform * 0.5)
		for k: int in ceili(long / seg):
			var zr := Vector2(north + k * seg, minf(north + (k + 1) * seg, south))
			var part := _add(STATION, side, x, (platform + _vox()) * 0.5, zr, ys)
			part.supports.append(_span_at((zr.x + zr.y) * 0.5))
		var cells := _deck_half_cells() + roundi(platform / _vox()) + 2
		var zr := Vector2(south - 6.0 * _vox(), south)
		_add(STAIRS, side, _x + side * cells * _vox(), _vox() * 1.5, zr, Vector2(0.0, deck))


## The id of the span holding the deck at `z` (-1 if none).
func _span_at(z: float) -> int:
	for part: Part in list:
		if part.kind == SPAN and z >= part.z0 and z <= part.z1:
			return part.id
	return -1


## The deck stands at `z` (a span there is up): a wreck's car over a gap falls.
func deck_at(z: float) -> bool:
	for part: Part in list:
		if part.kind == SPAN and part.alive and z >= part.z0 and z <= part.z1:
			return true
	return false


func of_kind(kind: String) -> Array[Part]:
	var out: Array[Part] = []
	for part: Part in list:
		if part.kind == kind:
			out.append(part)
	return out


## Falling spans, platforms and stairs come down; a landed one crushes the tanks under it.
func step(dt: float) -> void:
	for part: Part in list:
		if part.fall_t < 0.0 or part.landed:
			continue
		part.fall_t += dt
		if part.fall_t >= part.fall_for:
			part.landed = true
			sim.events.append({"type": "rail_part_landed", "id": part.id, "kind": part.kind})
			_crush_below(part)


func _crush_below(part: Part) -> void:
	var box := part.box().grow(RampageSim.TANK_RADIUS)
	for tank: RampageSim.Tank in sim.tanks:
		if box.has_point(tank.pos):
			tank.hp = 0.0
	sim.army_units.clear_dead()


## Damages every standing part by `damage` x force(its middle, its radius).
func hit(force: Callable, damage: float) -> void:
	for part: Part in list:
		if not part.alive:
			continue
		var k: float = force.call(part.middle(), Num.f(cfg["part_radius"][part.kind]))
		if k > 0.0:
			damage_part(part, damage * k, 1.0)


## Takes `amount` off a part's toughness; at zero it breaks. Returns whether it broke.
func damage_part(part: Part, amount: float, pay: float) -> bool:
	if not part.alive:
		return false
	part.hp -= amount
	if part.hp > 0.0:
		return false
	break_part(part, pay)
	return true


## Breaks a part now: it pays a share of a vehicle's worth, a pillar snaps, a span, platform or
## stair comes down; what it held loses its support and falls too; the track is broken under a
## span and a train on it derails.
func break_part(part: Part, pay: float) -> void:
	if not part.alive:
		return
	part.alive = false
	part.hp = 0.0
	var rubble := Num.f(sim.army["tank_rubble"]) * Num.f(cfg["part_pay"][part.kind]) * pay
	sim.rubble += rubble * sim.stat("rubble_mult")
	if part.kind == PILLAR:
		part.landed = true
	else:
		part.fall_t = 0.0
		part.fall_for = sqrt(2.0 * maxf(part.y0, 0.3) / _gravity)
	var at := part.middle()
	sim.events.append(
		{
			"type": "rail_part_broken",
			"id": part.id,
			"kind": part.kind,
			"side": part.side,
			"at": Vector3(part.x, part.y1, at.y),
			"rubble": rubble,
		}
	)
	if part.kind == SPAN:
		sim.rail.span_down(part.z0, part.z1)
	for other: Part in list:
		if other.alive and other.supports.has(part.id):
			break_part(other, pay)


## Damages every standing part `inside` (a Callable(middle: Vector2, radius: float) -> bool)
## holds, by `damage`: a toppling tower's landing strip.
func crush(inside: Callable, damage: float) -> void:
	for part: Part in list:
		if part.alive and inside.call(part.middle(), Num.f(cfg["part_radius"][part.kind])):
			damage_part(part, damage, 1.0)


## The body sweeping from one pose to the next breaks every part its discs touch (a railway holds
## no wall against it: parts snap, they are not chewed). Returns the parts broken.
func sweep(volume: BodyVolume, from: Vector2, fh: Vector2, to: Vector2, th: Vector2) -> int:
	var reach := volume.reach()
	if minf(absf(from.x - _x), absf(to.x - _x)) > reach + _wide:
		return 0
	var broken := 0
	var pay := Num.f(sim.body.cfg["pay_mult"])
	for pose: Array in volume.poses(from, fh, to, th):
		var at: Vector2 = pose[0]
		var facing: Vector2 = pose[1]
		for part: Part in list:
			if part.alive and volume.touches(at, facing, part.box(), part.y0, part.y1):
				break_part(part, pay)
				broken += 1
	return broken


## The registry's list (Structures): every part, standing or not.
func structures() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: Part in list:
		out.append({"id": part.id, "kind": part.kind, "pos": part.middle(), "alive": part.alive})
	return out


## The registry's destroy: breaks the part through the same path as a blow. Returns whether it did.
func destroy_structure(id: int) -> bool:
	break_part(list[id], 1.0)
	return not list[id].alive
