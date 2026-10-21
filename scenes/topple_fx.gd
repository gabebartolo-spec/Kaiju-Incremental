class_name ToppleFx
extends Node3D
## A toppling tower's weight (PR #89 motion review), inside the sim's fall time so nothing lags
## the sim: its base shudders and crumbles, it leans slowly, then gravity takes it; on landing the
## slab breaks up over a few frames (debris in waves, a burst of pale dust at the far end) instead
## of swapping to rubble at once, the sim's slabs slide to rest (RubbleView) and the heap slumps
## down into place. A tower comes down as floor bands that shatter one by one as each reaches
## the street, base first, also when it broke on the kaiju (ToppleBands, comments #24 #25 #30).
## Every timing and size is the "topple_fx" tuning. Presentation only. Part of CityView.

## Half a chunk's height (a part's "pos" is its chunk's centre).
const HALF_CELL := 0.5

var _city: CityView
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _breaking: Array[Dictionary] = []
var _rubble: RubbleView
var _bands: ToppleBands
var _bursts: Array[Dictionary] = []
var cubes := 0  # how many cubes the bands have burst into (the flow suite reads it)


func _init(city: CityView, rng: RandomNumberGenerator) -> void:
	_city = city
	_rng = rng
	_cfg = Content.section("topple_fx")
	_rubble = RubbleView.new(city, _cfg, rng)
	_bands = ToppleBands.new(self, _cfg)


## The piece's tilt (radians) t seconds into a fall the sim times at `duration` (the sim's own
## curve, FallContact.tilt, so where the sim says a tower met the kaiju is where it is drawn).
static func tilt(cfg: Dictionary, t: float, duration: float) -> float:
	return FallContact.tilt(cfg, t, duration)


## Poses a falling topple (CityView's fall record) for this frame; its base crumbles while it
## shudders.
func pose(f: Dictionary, delta: float) -> void:
	var node: Node3D = f["node"]
	var t := Num.f(f["t"])
	var duration := Num.f(f["duration"])
	var dir: Vector2 = f["dir"]
	var view: BuildingView = f.get("view")
	if not _bands.pose(f, view, t, duration):
		node.basis = FallMotion.topple_turn(dir, tilt(_cfg, t, duration))
	var shudder := minf(Num.f(_cfg["shudder_s"]), duration * Num.f(_cfg["shudder_max_share"]))
	if t > shudder or not node.has_meta("pivot"):  # a landmark's burst crumbles on its own
		return
	var due := Num.f(f.get("crumble", 0.0)) - delta
	if due > 0.0:
		f["crumble"] = due
		return
	f["crumble"] = due + Num.f(_cfg["crumble_every"])
	var base: Array = node.get_meta("base_parts", [])
	if base.is_empty():
		var pivot: Vector3 = node.get_meta("pivot")
		for part: Dictionary in node.get_meta("parts", []):
			var pos: Vector3 = part["pos"]
			if pos.y < pivot.y + Num.f(_cfg["crumble_floors"]):
				base.append(part)
		node.set_meta("base_parts", base)
	if base.is_empty():
		return
	for n: int in Num.i(_cfg["crumble_debris"]):
		var part: Dictionary = base[_rng.randi_range(0, base.size() - 1)]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		_city.debris(pos, color, Vector3.UP * 0.3)
	var at: Dictionary = base[_rng.randi_range(0, base.size() - 1)]
	var puff: Vector3 = at["pos"]
	_city.fx.dust(puff, Num.f(_cfg["crumble_dust"]))


## A topple landed (the sim's fall_land): the slab breaks up over breakup_s instead of vanishing,
## pale dust bursts at the far end and along the strip, and the heap built off-thread slumps
## into place with a few big chunks sliding to rest on it.
## fall: CityView's fall record (its "t", "dir", "cells"); view: the building's.
func land(node: Node3D, event: Dictionary, view: BuildingView, fall: Dictionary) -> void:
	var voxels := view.voxels
	var from: Vector2 = event["from"]
	var to: Vector2 = event["to"]
	var width := Num.f(event["width"])
	var a := Vector3(from.x, 0, from.y)
	var b := Vector3(to.x, 0, to.y)
	var lift := Vector3(0, Num.f(_cfg["dust_lift"]), 0)
	var dust := Color(str(_cfg["dust_color"]))
	var impact := Num.f(_cfg["contact_dust" if event.has("hit") else "impact_dust"])
	var banded := fall.has("bands") and not event.has("hit")
	if not banded:  # bands shatter in view: their own puffs, no cloud over the break
		_city.fx.dust(b + lift, impact, dust)  # on the kaiju: only a puff where it met him
		_city.fx.dust(a.lerp(b, 0.6) + lift, impact * 0.7, dust)
		_city.fx.dust_line(a, b, width, dust)
	var slabs: Array = event.get("slabs", [])
	var hold := 0.0  # the heap and its dust wait for the last band to break
	if event.has("hit"):
		_fold(node, event, view, fall)
	elif banded:
		var bands: Array = fall["bands"]
		_rubble.add(_bands.land(fall, slabs), voxels, false, true, true)
		_bands.begin(fall)
		hold = _bands.tail_s(bands.size())  # the heap starts rising as the cubes begin to lie
		slabs = []
	else:
		_break_up(node, Num.f(_cfg["breakup_s"]), Num.f(_cfg["impact_debris"]))
	var cfg := _cfg.duplicate()
	if hold > 0.0:  # a broken band's heap is the cubes' colours, not pale concrete
		cfg["rubble_tint_mix"] = cfg["band_heap_mix"]
	var settle := func(mmi: MultiMeshInstance3D) -> void: _settle(mmi, hold)
	_city.ruins().build(
		func() -> MultiMeshInstance3D: return Ruin.strip(voxels, a, b, width, cfg), settle
	)
	_rubble.add(slabs, voxels, true)


## The slabs a part that dropped onto the street left (the sim's fall_land "slabs").
func lay(slabs: Array, voxels: BuildingVoxels) -> void:
	_rubble.add(slabs, voxels, false)


## The sim broke a slab (RubbleSlabs): RubbleView shows it.
func slab_break(event: Dictionary, voxels: BuildingVoxels) -> void:
	_rubble.smash(event, voxels)


## A tower broke on the kaiju (the sim's "hit"): its bands come down (ToppleBands.fold); the
## fold slabs show as their bands land, the small edge slabs tumble out at once. A piece that
## never split (a landmark's) breaks up where it is.
func _fold(node: Node3D, event: Dictionary, view: BuildingView, fall: Dictionary) -> void:
	var hit: Dictionary = event["hit"]
	var pieces: Array = hit["pieces"]
	var large := Num.i(hit["large"])
	_rubble.add(pieces.slice(large), view.voxels, false)
	if fall.has("bands"):
		_rubble.add(pieces.slice(0, large), view.voxels, false, true)
		_bands.fold(fall, hit)
		return
	_rubble.add(pieces.slice(0, large), view.voxels, false)
	edge(node, Num.f(hit["crack"]), hit)
	_break_up(node, Num.f(_cfg["breakup_s"]), Num.f(_cfg["impact_debris"]))


## A band reached the street: it bursts into its own cubes, about shatter_cubes of its chunks
## (the facade's colours, mostly small, their places inside the band's footprint) released
## progressively along it over shatter_release_s as the band shortens behind them, then thrown
## out and tumbling to rest, a little gravel, a puff of dust (comment #30). Cubes that would land
## on the kaiju are thinned and pushed off him.
func shatter(band: Node3D) -> void:
	if band.has_meta("breaking"):
		return
	band.set_meta("breaking", true)
	var xf := band.global_transform
	var parts: Array = band.get_meta("parts", [])
	var pivot: Vector3 = band.get_meta("pivot", Vector3.ZERO)
	var palette: Dictionary = band.get_meta("palette", {})
	var keys: Array = _cfg["cube_keys"]
	var count := mini(parts.size(), Num.i(_cfg["shatter_cubes"]))
	var span: Array = _cfg["cube_size"]
	var unit := pow(float(parts.size()) / maxi(1, count), 1.0 / 3.0)
	var darkest := 0.0
	if palette.has("frame"):
		var frame: Color = palette["frame"]
		darkest = frame.get_luminance()  # nothing but glass is darker than the facade's brick
	var kaiju: Vector2 = _city.sim.kaiju_pos
	var clear := Num.f(_cfg["cube_kaiju_clear"])
	var specs: Array[Dictionary] = []
	for k: int in count:
		var part: Dictionary = parts[k * parts.size() / count]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		var key := str(keys[_rng.randi_range(0, keys.size() - 1)])
		if palette.has(key):  # the facade's own albedo (wall, pillar, window...)
			var base: Color = palette[key]
			color = Look.jitter(base, Vector3i(k, roundi(pos.y), roundi(pos.x)), k)
			if key != "window" and color.get_luminance() < darkest:
				color = palette["frame"]
		var world := xf * (pos - pivot)
		var away := Vector3.ZERO
		var off := Vector2(world.x - kaiju.x, world.z - kaiju.y)
		if off.length() < clear:  # over him: most never fall, the rest go off his side
			if k % 4 != 0:
				continue
			away = Vector3(off.x, 0.0, off.y).normalized() * Num.f(_cfg["shatter_out"]) * 2.0
		var f := lerpf(Num.f(span[0]), Num.f(span[1]), pow(_rng.randf(), Num.f(_cfg["cube_skew"])))
		specs.append({"at": pos.y - pivot.y, "world": world, "color": color, "away": away})
		specs[-1]["size"] = unit * f
	specs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return Num.f(x["at"]) < Num.f(y["at"]))
	var corners: PackedVector3Array = band.get_meta("corners", PackedVector3Array())
	var hi := -INF
	for c: Vector3 in corners:
		hi = maxf(hi, c.y)
	_bursts.append({"band": band, "specs": specs, "rest": xf, "hi": hi, "t": 0.0, "out": 0})
	var centre: Vector3 = band.get_meta("centre", Vector3.ZERO)
	var at := xf * centre
	_city.fx.dust(Vector3(at.x, Num.f(_cfg["dust_lift"]), at.z), Num.f(_cfg["band_dust"]))


## A band that is bursting this frame: more of its cubes leave, it shortens behind them.
func _burst(br: Dictionary, delta: float) -> bool:
	var band: Node3D = br["band"]
	if not is_instance_valid(band):
		return true
	br["t"] = Num.f(br["t"]) + delta
	var frac := clampf(Num.f(br["t"]) / Num.f(_cfg["shatter_release_s"]), 0.0, 1.0)
	var specs: Array = br["specs"]
	var rest: Transform3D = br["rest"]
	var upto := ceili(frac * specs.size())
	var stay := Num.f(_cfg["cube_stay_s"])
	var up := Vector3.UP * Num.f(_cfg["shatter_up"])
	for n: int in range(Num.i(br["out"]), upto):
		var spec: Dictionary = specs[n]
		var away: Vector3 = spec["away"]
		var world: Vector3 = spec["world"]
		var tint: Color = spec["color"]
		if away == Vector3.ZERO:
			var out := Vector3(world.x - rest.origin.x, 0.0, world.z - rest.origin.z)
			away = out.normalized() * Num.f(_cfg["shatter_out"])
		_city.debris_cube(world, tint, away + up, Num.f(spec["size"]), stay)
		cubes += 1
	br["out"] = upto
	var top := Vector3(0, Num.f(br["hi"]), 0)
	var scale := maxf(0.02, 1.0 - frac)
	var shrunk := rest.basis * Basis.from_scale(Vector3(1, scale, 1))
	var world_top := rest * top
	band.global_transform = Transform3D(shrunk, world_top - rest.basis * (top * scale))
	if frac < 1.0:
		return false
	var parts: Array = band.get_meta("parts", [])
	var pivot: Vector3 = band.get_meta("pivot", Vector3.ZERO)
	var share := Num.f(band.get_meta("share", 1.0))
	var gravel := roundi(Num.f(_cfg["impact_debris"]) * share * Num.f(_cfg["shatter_gravel"]))
	for n: int in gravel:
		var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		_city.debris(rest * (pos - pivot), color, Vector3.UP)
	if band.has_meta("keep"):
		band.visible = false  # the fall's own piece: CityView frees it when it lands
	else:
		band.queue_free()
	return true


## Shows the fold slabs RubbleView kept hidden (their band landed).
func reveal(ids: Array) -> void:
	if not ids.is_empty():
		_rubble.reveal(ids)


## The impact edge: debris from the piece's parts near the crack, thrown off his side (hit
## "side"), and a puff of dust where it met him (hit "at").
func edge(node: Node3D, crack: float, hit: Dictionary) -> void:
	var pivot: Vector3 = node.get_meta("pivot")
	var at: Vector3 = hit["at"]
	var side: Vector2 = hit["side"]
	var near: Array = []
	for part: Dictionary in node.get_meta("parts", []):
		var pos: Vector3 = part["pos"]
		if absf(pos.y - pivot.y - crack) < Num.f(_cfg["edge_band"]):
			near.append(part)
	var away := Vector3(side.x, Num.f(_cfg["gravel_up"]), side.y)
	if not near.is_empty():
		for n: int in Num.i(_cfg["edge_debris"]):
			var part: Dictionary = near[_rng.randi_range(0, near.size() - 1)]
			var pos: Vector3 = part["pos"]
			var color: Color = part["color"]
			_city.debris(node.global_transform * (pos - pivot), color, away)
	_city.fx.dust(at, Num.f(_cfg["contact_dust"]))


## A dropped part landed (the sim's fall_land): it crumbles down into the street over
## drop_crumble_s with debris in waves instead of vanishing on the landing frame (PR #89 review,
## capture 39277970463 frames 505-506).
func crumble(node: Node3D) -> void:
	var floor_y := INF  # what it came down on: the bottom of its lowest part
	var pivot: Vector3 = node.get_meta("pivot", Vector3.ZERO)
	for part: Dictionary in node.get_meta("parts", []):
		var pos: Vector3 = part["pos"]
		floor_y = minf(floor_y, (node.global_transform * (pos - pivot)).y - HALF_CELL)
	floor_y = 0.0 if is_inf(floor_y) else maxf(0.0, floor_y)
	_break_up(node, Num.f(_cfg["drop_crumble_s"]), Num.f(_cfg["drop_crumble_debris"]), floor_y)


## floor: the world height it landed on (the street, or the floors a drop came down on).
func _break_up(node: Node3D, span: float, debris: float, floor_y := 0.0) -> void:
	node.set_meta("breaking", true)
	var xf := node.global_transform
	var br := {"node": node, "t": 0.0, "basis": xf, "span": span, "debris": debris}
	br["floor"] = floor_y
	_breaking.append(br)


## A breaking piece at rest pose `rest`, crushed to `flat` of its height down onto floor_y (the
## world height it landed on): it breaks against what it hit (comment #26).
static func crushed(rest: Transform3D, flat: float, floor_y: float) -> Transform3D:
	var onto := Vector3(0, floor_y, 0)
	return Transform3D(Basis.from_scale(Vector3(1, flat, 1)), onto - onto * flat) * rest


func _process(delta: float) -> void:
	_bands.process(delta)
	for i: int in range(_bursts.size() - 1, -1, -1):
		if _burst(_bursts[i], delta):
			_bursts.remove_at(i)
	for i: int in range(_breaking.size() - 1, -1, -1):
		var br: Dictionary = _breaking[i]
		var node: Node3D = br["node"]
		var span := Num.f(br["span"])
		var per_s := Num.f(br["debris"]) / span
		br["t"] = Num.f(br["t"]) + delta
		var k := clampf(Num.f(br["t"]) / span, 0.0, 1.0)
		if not is_instance_valid(node) or k >= 1.0:
			if is_instance_valid(node) and node.has_meta("keep"):
				node.visible = false  # the fall's own piece: CityView frees it when it lands
			elif is_instance_valid(node):
				node.queue_free()
			_breaking.remove_at(i)
			continue
		var rest: Transform3D = br["basis"]
		var flat := lerpf(1.0, Num.f(_cfg["breakup_flatten"]), k)
		node.global_transform = crushed(rest, flat, Num.f(br["floor"]))
		var parts: Array = node.get_meta("parts", [])
		if parts.is_empty():
			continue
		var pivot: Vector3 = node.get_meta("pivot")
		for n: int in roundi(per_s * delta):
			var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
			var pos: Vector3 = part["pos"]
			var color: Color = part["color"]
			_city.debris(rest * (pos - pivot), color, Vector3.UP)


## The heap slumps: built taller than it rests, it settles down over settle_s.
func _settle(mmi: MultiMeshInstance3D, wait := 0.0) -> void:
	if wait > 0.0:  # under the bursting bands: out of sight until the cubes lie, then it rises
		mmi.visible = false
		mmi.scale = Vector3(1, 0.02, 1)
		await _city.get_tree().create_timer(wait).timeout
		if not is_instance_valid(mmi):
			return
		mmi.visible = true
		var up := mmi.create_tween()
		up.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		up.tween_property(mmi, "scale:y", 1.0, Num.f(_cfg["heap_rise_s"]))
		return
	mmi.scale = Vector3(1, Num.f(_cfg["settle_heap"]), 1)
	var tween := mmi.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mmi, "scale:y", 1.0, Num.f(_cfg["settle_s"]))
