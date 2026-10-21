class_name ToppleBands
extends RefCounted
## A toppling tower as floor bands (director 2026-10-21, comment #30: "each section of the
## building needs to shatter as it hits the ground in sequence"). At its first pose the lifted
## piece splits into bands of band_floors floors (at most band_max). They turn together about the
## pivot until the last bend_s of the fall, when each upper band lags so the bands come down base
## first, band_gap_s apart, the base one at the sim's landing (so the slabs it left are known);
## each shatters (ToppleFx.shatter) the moment it lies on the street, and its share of the sim's
## slabs breaks out of it right there (comment #30: "each section ... shatter as it hits"). Broken on the kaiju (the sim's "hit", comments #24 #25), the bands
## below the crack come down in front of him base first over fold_lower_s; the ones above it fold
## off his side onto the sim's fold slabs, nearest the crack first, by fold_s, each shattering as
## it lands and showing its slab. No point of a band is ever below the street (lift()).
## Presentation only; part of ToppleFx. Every number is the "topple_fx" tuning.

const HALF_CELL := 0.5  # a part's "pos" is its chunk's centre
const FLAT := PI * 0.5

var _fx: ToppleFx
var _cfg: Dictionary
var _moving: Array[Dictionary] = []
var _landed: Array[Dictionary] = []  # falls the sim landed whose upper bands are still coming down


func _init(fx: ToppleFx, cfg: Dictionary) -> void:
	_fx = fx
	_cfg = cfg


## Poses the fall's bands for time t of its `duration` (splitting it on the first call); false
## when the piece does not split (a landmark's burst), and the caller poses it whole.
func pose(f: Dictionary, view: BuildingView, t: float, duration: float) -> bool:
	if not f.has("bands") and not _split(f, view):
		return false
	_turn_all(f, t, duration)
	return true


## Band i lags i * band_gap_s behind the base at the end: it lies flat at duration + that.
func _turn_all(f: Dictionary, t: float, duration: float) -> void:
	var bands: Array = f["bands"]
	var dir: Vector2 = f["dir"]
	var gap := Num.f(_cfg["band_gap_s"])
	var bend := Num.f(_cfg["bend_s"])
	var ramp := clampf((t - (duration - bend)) / maxf(0.001, bend), 0.0, 1.0)
	for i: int in bands.size():
		var band := _live(bands[i])
		if band != null:
			_turn(band, dir, minf(ToppleFx.tilt(_cfg, t - gap * i * ramp, duration), FLAT))


## The sim landed it on the street (slabs: its "slabs"): the base band lies flat and shatters
## now, the ones above as they reach the street; each band's share of the slabs (by where along
## the fall they lie) is returned held, to be revealed (reveal) as that band shatters, breaking
## out of it from its middle.
func land(f: Dictionary, slabs: Array) -> Array[Dictionary]:
	_release(f)
	var bands: Array = f["bands"]
	var dir: Vector2 = f["dir"]
	var held: Array[Dictionary] = []
	var ids: Array = []
	for i: int in bands.size():
		ids.append([])
	for slab: Dictionary in slabs:
		var pos: Vector2 = slab["pos"]
		var i := _band_at(bands, dir, pos)
		if i < 0:
			i = 0  # every band is already gone: it shows with the first
		var out := slab.duplicate()
		var node: Node3D = bands[i]
		var centre := _flat_centre(node, dir)
		out["from"] = Vector2(centre.x, centre.z)
		held.append(out)
		var mine: Array = ids[i]
		mine.append(slab["id"])
	f["band_ids"] = ids
	f["run"] = Num.f(f["t"])
	return held


## Starts the landed fall's bands shattering (after the held slabs were added).
func begin(f: Dictionary) -> void:
	_landed.append(f)
	_advance(f, 0.0)


## Seconds from the sim's landing until the last band has shattered.
func tail_s(n: int) -> float:
	return Num.f(_cfg["band_gap_s"]) * maxi(0, n - 1) + Num.f(_cfg["shatter_s"])


## The index of the band lying over `pos` (its height range up the tower holds pos's distance
## along the fall, else the nearest); -1 when there are no live bands.
func _band_at(bands: Array, dir: Vector2, pos: Vector2) -> int:
	var best := -1
	var near := INF
	for i: int in bands.size():
		var band := _live(bands[i])
		if band == null:
			continue
		var pivot: Vector3 = band.get_meta("pivot")
		var along := (pos - Vector2(pivot.x, pivot.z)).dot(dir)
		var corners: PackedVector3Array = band.get_meta("corners")
		var lo := INF
		var hi := -INF
		for c: Vector3 in corners:
			lo = minf(lo, c.y)
			hi = maxf(hi, c.y)
		var miss := maxf(lo - along, along - hi)
		if miss < near:
			near = miss
			best = i
	return best


## Where a band's middle is once it lies flat along dir.
static func _flat_centre(band: Node3D, dir: Vector2) -> Vector3:
	var pivot: Vector3 = band.get_meta("pivot")
	var centre: Vector3 = band.get_meta("centre")
	return pivot + FallMotion.topple_turn(dir, FLAT) * centre


## One step of a landed fall: bands still coming down turn on, each that lies flat shatters and
## shows its slabs.
func _advance(f: Dictionary, delta: float) -> void:
	var duration := Num.f(f["duration"])
	var run := Num.f(f["run"]) + delta
	f["run"] = run
	_turn_all(f, run, duration)
	var gap := Num.f(_cfg["band_gap_s"])
	var bands: Array = f["bands"]
	var ids: Array = f["band_ids"]
	var done := true
	for i: int in bands.size():
		var band := _live(bands[i])
		if band == null:
			continue
		if run >= duration + gap * i:
			_fx.shatter(band)
			var shows: Array = ids[i]
			_fx.reveal(shows)
		else:
			done = false
	if done:
		_landed.erase(f)


## It broke on the kaiju (the sim's hit: "crack" up its axis, "pieces" with "large" fold slabs
## first): the bands come down as the header says.
func fold(f: Dictionary, hit: Dictionary) -> void:
	_release(f)
	var crack := Num.f(hit["crack"])
	var dir: Vector2 = f["dir"]
	var lower: Array[Node3D] = []
	var upper: Array[Node3D] = []
	for raw: Variant in f["bands"]:
		var band := _live(raw)
		if band != null:
			(upper if Num.f(band.get_meta("mid")) >= crack else lower).append(band)
	if not upper.is_empty():
		_fx.edge(upper[0], crack, hit)
	elif not lower.is_empty():
		_fx.edge(lower[-1], crack, hit)
	var lower_s := Num.f(_cfg["fold_lower_s"])
	for i: int in lower.size():
		var band := lower[i]
		var from := band.basis.get_rotation_quaternion().get_angle()
		var span := lower_s * (i + 1) / lower.size()
		_moving.append({"band": band, "dir": dir, "from": from, "t": 0.0, "span": span})
	var pieces: Array = hit["pieces"]
	var large := Num.i(hit["large"])
	var side: Vector2 = hit["side"]
	var at: Vector3 = hit["at"]
	var rest := maxf(0.05, Num.f(_cfg["fold_s"]) - lower_s)
	for j: int in upper.size():
		var band := upper[j]
		var ids: Array = []
		var spot := Vector2(at.x, at.z) + side * Num.f(_cfg["fold_clear_view"])
		if large > 0:
			var slab: Dictionary = pieces[mini(large - 1, j * large / upper.size())]
			ids.append(slab["id"])
			spot = slab["pos"]
		var to := _flat_at(band, dir, spot)
		var span := lower_s + rest * (j + 1) / upper.size()
		_moving.append(
			{"band": band, "from": band.global_transform, "to": to, "t": 0.0, "span": span}
		)
		_moving[-1]["ids"] = ids


func process(delta: float) -> void:
	for f: Dictionary in _landed.duplicate():
		_advance(f, delta)
	for i: int in range(_moving.size() - 1, -1, -1):
		var m: Dictionary = _moving[i]
		var band := _live(m["band"])
		if band == null:
			_moving.remove_at(i)
			continue
		m["t"] = Num.f(m["t"]) + delta
		var k := clampf(Num.f(m["t"]) / Num.f(m["span"]), 0.0, 1.0)
		if m.has("to"):  # folding off his side: it keeps the speed it fell at
			var e := lerpf(k, k * k, Num.f(_cfg["fold_gravity"]))
			var from: Transform3D = m["from"]
			var to: Transform3D = m["to"]
			var basis := from.basis.orthonormalized().slerp(to.basis, e)
			band.global_transform = Transform3D(basis, from.origin.lerp(to.origin, e))
			lift(band)
		else:  # in front of him: it turns on down, gravity's ease
			var dir: Vector2 = m["dir"]
			_turn(band, dir, lerpf(Num.f(m["from"]), FLAT, k * k))
		if k >= 1.0:
			_fx.shatter(band)
			var ids: Array = m.get("ids", [])
			_fx.reveal(ids)
			_moving.remove_at(i)


## A band still whole (not freed, not breaking), else null.
static func _live(raw: Variant) -> Node3D:
	if not is_instance_valid(raw):
		return null
	var band: Node3D = raw
	return null if band.has_meta("breaking") else band


## The sim landed the fall: its own piece (band 0) is freed once it has shattered.
static func _release(f: Dictionary) -> void:
	var raw: Variant = f["node"]
	if is_instance_valid(raw):
		var node: Node3D = raw
		node.remove_meta("keep")
		if not node.visible:
			node.queue_free()


## Splits the fall's piece (its "node", "cells") into bands up its height; band 0 is the piece.
func _split(f: Dictionary, view: BuildingView) -> bool:
	var node: Node3D = f["node"]
	if view == null or not node.has_meta("alive") or not node.has_meta("pivot"):
		return false
	var pivot: Vector3 = node.get_meta("pivot")
	var cells: Array[Vector3i] = f["cells"]
	var high := 1.0
	for c: Vector3i in cells:
		high = maxf(high, c.y + 1.0 - pivot.y)
	var floors := Num.f(_cfg["band_floors"])
	var n := clampi(ceili(high / floors), 1, Num.i(_cfg["band_max"]))
	var step := high / n
	var bands: Array[Node3D] = []
	for i: int in range(n - 1, 0, -1):  # top band first: split_piece takes the parts above
		var low := step * i
		var band: Array[Vector3i] = []
		for c: Vector3i in cells:
			var y := c.y + 0.5 - pivot.y
			if y >= low and (i == n - 1 or y < low + step):
				band.append(c)
		if band.is_empty():
			continue
		var piece := view.split_piece(node, band, low)
		node.get_parent().add_child(piece)
		piece.global_transform = node.global_transform
		bands.push_front(piece)
	bands.push_front(node)
	node.set_meta("keep", true)  # CityView's fall record holds it until the sim lands it
	var total := 0
	for band: Node3D in bands:
		var parts: Array = band.get_meta("parts", [])
		total += parts.size()
	for band: Node3D in bands:
		_measure(band, total)
	f["bands"] = bands
	return true


## Keeps on a band (from its parts, about its pivot): "corners" of its box, "mid" its height up
## the tower, "centre" its middle, "share" its part of the tower's debris.
static func _measure(band: Node3D, total: int) -> void:
	var pivot: Vector3 = band.get_meta("pivot")
	var parts: Array = band.get_meta("parts", [])
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for part: Dictionary in parts:
		var pos: Vector3 = part["pos"]
		lo = lo.min(pos - pivot - Vector3.ONE * HALF_CELL)
		hi = hi.max(pos - pivot + Vector3.ONE * HALF_CELL)
	if parts.is_empty():
		lo = Vector3.ZERO
		hi = Vector3.ZERO
	var corners := PackedVector3Array()
	for k: int in 8:
		corners.append(
			Vector3(hi.x if k & 1 else lo.x, hi.y if k & 2 else lo.y, hi.z if k & 4 else lo.z)
		)
	band.set_meta("corners", corners)
	band.set_meta("centre", (lo + hi) * 0.5)
	band.set_meta("mid", (lo.y + hi.y) * 0.5)
	band.set_meta("share", float(parts.size()) / maxi(1, total))


## Turns a band about its pivot (the fall's base edge) to `angle` toward dir.
func _turn(band: Node3D, dir: Vector2, angle: float) -> void:
	band.basis = FallMotion.topple_turn(dir, angle)
	band.position = band.get_meta("pivot")
	lift(band)


## Lifts a band whose box would reach below the street onto it.
static func lift(band: Node3D) -> void:
	var corners: PackedVector3Array = band.get_meta("corners", PackedVector3Array())
	var low := lowest(band.global_transform, corners)
	if low < 0.0:
		band.global_position += Vector3(0, -low, 0)


static func lowest(xf: Transform3D, corners: PackedVector3Array) -> float:
	var low := INF
	for c: Vector3 in corners:
		low = minf(low, (xf * c).y)
	return 0.0 if is_inf(low) else low


## A band lying flat along dir on the street with its middle over `spot`.
static func _flat_at(band: Node3D, dir: Vector2, spot: Vector2) -> Transform3D:
	var basis := FallMotion.topple_turn(dir, FLAT)
	var centre: Vector3 = band.get_meta("centre")
	var xf := Transform3D(basis, Vector3(spot.x, 0, spot.y) - basis * centre)
	var corners: PackedVector3Array = band.get_meta("corners")
	var low := lowest(xf, corners)
	return Transform3D(basis, xf.origin - Vector3(0, low, 0))
