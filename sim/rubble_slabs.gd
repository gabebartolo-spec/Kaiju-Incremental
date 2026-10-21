class_name RubbleSlabs
extends RefCounted
## The big slabs a toppled tower leaves on the street (D-110: "rubble blocks are probably too
## big, the kaiju is gonna clip through them"; he picked destructible). Each landed slab is a box
## on the ground the sim knows; a stomp, swipe, breath, any area blow (RampageSim.hit_area) or
## the kaiju's body moving into it (BodyContact, a dash too) breaks it: into a few smaller slabs
## pushed out from the blow, which break again the same way, and below gravel_size into gravel
## only. So nothing the kaiju touches is left standing inside him. Numbers: data/tuning.json
## "rubble". Pure: its own seeded stream (Seeds.derive), fixed scan order, no clock.


class Slab:
	var id: int
	var building: int
	var pos: Vector2  # centre on the ground plane at rest
	var from: Vector2  # where it started sliding from (the view slides it here)
	var dims: Vector3  # x along its yaw, y up, z across
	var yaw: float  # radians about up (the view's rotation.y)
	var base: float  # what it rests on: the strip's heap (rest_y) or the street (0)
	var top: float  # world height of its highest point


var sim: RampageSim
var cfg: Dictionary
var slabs: Array[Slab] = []
## Slabs broken this rampage (the destruction suite and benches read it).
var broken := 0
## False: nothing breaks a slab (the sim suite's fixture for the game before D-110).
var breaks := true
var _rng: RandomNumberGenerator
var _next_id := 0


## cfg: the "rubble" tuning; empty turns slabs off (a fixture with a trimmed tuning).
func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng


func on() -> bool:
	return not cfg.is_empty()


## The slabs a tower toppled along the strip start-finish (half_width across) leaves, as event
## dictionaries (slab_dict); `count` of them (Collapse scales it to what reached the ground).
## discs (BodyContact.world_discs, may be empty): a slab that would rest in the body comes to
## rest short of it instead, back along the strip.
## line: [start (Vector2), finish (Vector2), half_width].
func strip(building: int, line: Array, count: int, discs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not on():
		return out
	var start: Vector2 = line[0]
	var finish: Vector2 = line[1]
	var half_width := Num.f(line[2])
	var along := (finish - start).normalized()
	var side := Vector2(-along.y, along.x)
	var sizes: Array = cfg["slab_size"]
	var spread: Array = cfg["along"]
	for n: int in count:
		var size := _rng.randf_range(Num.f(sizes[0]), Num.f(sizes[1]))
		var long := _rng.randf_range(Num.f(cfg["long"][0]), Num.f(cfg["long"][1]))
		var dims := Vector3(size, size * Num.f(cfg["depth"]), size * long)
		var t := _rng.randf_range(Num.f(spread[0]), Num.f(spread[1]))
		var lateral := _rng.randf_range(-1.0, 1.0) * Num.f(cfg["side"]) * half_width * 2.0
		var at := start.lerp(finish, t) + side * lateral
		var slide := along * Num.f(cfg["slide"]) * _rng.randf_range(0.4, 1.0)
		var yaw := _rng.randf()
		var rest := at + slide
		if not discs.is_empty():
			var back := ceili(start.distance_to(rest) / Num.f(cfg["clear_step"])) + 1
			rest = clear_of(rest, dims, yaw, -along, discs, Num.f(cfg["clear_step"]), back)
		out.append(_add(_make(building, [at, rest], dims, Vector2(yaw, Num.f(cfg["rest_y"])))))
	return out


## A slab of building's sliding along path [from, to] to rest; pose: (yaw, base).
static func _make(building: int, path: Array, dims: Vector3, pose: Vector2) -> Slab:
	var s := Slab.new()
	s.building = building
	s.from = path[0]
	s.pos = path[1]
	s.dims = dims
	s.yaw = pose.x
	s.base = pose.y
	s.top = pose.y + dims.y
	return s


## Lays a slab on the street (its id is the next) and returns its event dictionary.
func _add(s: Slab) -> Dictionary:
	s.id = _next_id
	_next_id += 1
	slabs.append(s)
	return slab_dict(s)


static func slab_dict(s: Slab) -> Dictionary:
	return {"id": s.id, "from": s.from, "pos": s.pos, "dims": s.dims, "yaw": s.yaw, "base": s.base}


## Adds a slab of `dims` turned `yaw` resting on the street, sliding along path [from, to]
## (Collapse's fold pieces).
func place(building: int, path: Array, dims: Vector3, yaw: float) -> Dictionary:
	return _add(_make(building, path, dims, Vector2(yaw, 0.0)))


## An area blow (RampageSim.hit_area's force and damage, floors from y_lo): every slab it
## reaches hard enough (break_hp) breaks, pushed away from the kaiju.
func hit(force: Callable, damage: float, y_lo: int) -> void:
	if slabs.is_empty() or not breaks:
		return
	var hits: Array[Slab] = []
	for s: Slab in slabs:
		if float(y_lo) >= s.top:
			continue
		var k: float = force.call(s.pos, Vector2(s.dims.x, s.dims.z).length() * 0.5)
		if k > 0.0 and damage * k >= Num.f(cfg["break_hp"]):
			hits.append(s)
	for s: Slab in hits:
		_break(s, sim.kaiju_pos, "blow")


## The body moved from pose (from, from_heading) to (to, to_heading): every slab a disc
## touches on the way breaks, its pieces pushed out from the body's centre; the sweep is
## sampled like BodyContact's, so a dash never skips a slab.
## poses: [from, from_heading, to, to_heading].
func touch(poses: PackedVector2Array, body: BodyContact) -> void:
	if slabs.is_empty() or not breaks:
		return
	var from := poses[0]
	var from_heading := poses[1]
	var to := poses[2]
	var to_heading := poses[3]
	var reach := 0.0
	for d: Array in body.discs():
		reach = maxf(reach, absf(Num.f(d[0])) + Num.f(d[1]))
	reach *= sim.body_scale()
	var near: Array[Slab] = []
	var lo := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * reach
	var hi := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * reach
	for s: Slab in slabs:
		var r := Vector2.ONE * maxf(s.dims.x, s.dims.z)
		if Rect2(lo, hi - lo).intersects(Rect2(s.pos - r, r * 2.0)):
			near.append(s)
	if near.is_empty():
		return
	var travel := from.distance_to(to) + absf(from_heading.angle_to(to_heading)) * reach
	var samples := maxi(1, ceili(travel / maxf(0.05, Num.f(body.cfg["sample"]))))
	var hits: Dictionary = {}
	for n: int in range(1, samples + 1):
		var pose := BodyContact.sweep_pose(from, from_heading, to, to_heading, float(n) / samples)
		var at: Vector2 = pose[0]
		var facing: Vector2 = pose[1]
		for d: Array in body.world_discs(at, facing):
			var c: Vector2 = d[0]
			for s: Slab in near:
				if not hits.has(s.id) and _overlaps(s, c, Num.f(d[1]), Num.f(d[2])):
					hits[s.id] = s
	for s: Slab in near:  # scan order, not the order the sweep met them
		if hits.has(s.id):
			_break(s, to, "body")


## Where a slab of `dims` turned `yaw` near `at` first lies clear of every disc
## (BodyContact.world_discs), moving out along `out` (a unit) in steps of `step`; at most
## `tries` steps.
static func clear_of(
	at: Vector2, dims: Vector3, yaw: float, out: Vector2, discs: Array, step: float, tries: int
) -> Vector2:
	var probe := Slab.new()
	probe.dims = dims
	probe.yaw = yaw
	probe.top = INF
	probe.pos = at
	for n: int in tries:
		var inside := false
		for d: Array in discs:
			var c: Vector2 = d[0]
			if _overlaps(probe, c, Num.f(d[1]), -INF):
				inside = true
				break
		if not inside:
			break
		probe.pos += out * step
	return probe.pos


## Whether a disc (centre, radius, bottom) overlaps the slab's box.
static func _overlaps(s: Slab, c: Vector2, r: float, bottom: float) -> bool:
	if bottom >= s.top:
		return false
	var rel := c - s.pos
	var cs := cos(s.yaw)
	var sn := sin(s.yaw)
	var local := Vector2(rel.x * cs - rel.y * sn, rel.x * sn + rel.y * cs)
	var gap := Vector2(
		maxf(absf(local.x) - s.dims.x * 0.5, 0.0), maxf(absf(local.y) - s.dims.z * 0.5, 0.0)
	)
	return gap.length() < r


## Breaks a slab: a few smaller slabs (piece_scale of it) pushed away from `away`, or gravel
## only once they would be smaller than gravel_size. One "slab_break" event; `by` is "body" or
## "blow".
func _break(s: Slab, away: Vector2, by: String) -> void:
	slabs.erase(s)
	broken += 1
	var scale: Array = cfg["piece_scale"]
	var push := s.pos - away
	push = push.normalized() if push.length() > 0.01 else Vector2.from_angle(s.yaw)
	var cs := cos(s.yaw)
	var sn := sin(s.yaw)
	var pieces: Array[Dictionary] = []
	var gravel := Num.i(cfg["gravel"])
	for n: int in Num.i(cfg["pieces"]):
		var k := _rng.randf_range(Num.f(scale[0]), Num.f(scale[1]))
		var dims := s.dims * k
		var off := Vector2(
			_rng.randf_range(-0.5, 0.5) * s.dims.x, _rng.randf_range(-0.5, 0.5) * s.dims.z
		)
		var from := s.pos + Vector2(off.x * cs + off.y * sn, -off.x * sn + off.y * cs)
		var out := push * Num.f(cfg["piece_push"]) * _rng.randf_range(0.5, 1.0)
		if maxf(dims.x, dims.z) < Num.f(cfg["gravel_size"]):
			gravel += Num.i(cfg["gravel_per_piece"])
			continue
		pieces.append(
			_add(_make(s.building, [from, from + out], dims, Vector2(_rng.randf(), s.base)))
		)
	(
		sim
		. events
		. append(
			{
				"type": "slab_break",
				"id": s.id,
				"building": s.building,
				"pos": s.pos,
				"push": push,
				"pieces": pieces,
				"gravel": gravel,
				"by": by,
			}
		)
	)


## A digest of what lies on the street (replay checks).
func digest() -> int:
	var parts: Array = [broken, _next_id]
	for s: Slab in slabs:
		parts.append([s.id, s.pos, s.dims, s.yaw])
	return hash(parts)
