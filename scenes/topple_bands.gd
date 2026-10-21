class_name ToppleBands
extends RefCounted
## A toppling tower as floor bands (director 2026-10-21, comment #30: "each section of the
## building needs to shatter as it hits the ground in sequence"). At its first pose the lifted
## piece splits into bands of band_floors floors (at most band_max). They turn together about the
## pivot until the last bend_s of the fall, when each lower band leads so the bands come down base
## first, band_gap_s apart, the top one at the sim's landing; each shatters (ToppleFx.shatter) the
## moment it lies on the street. Broken on the kaiju (the sim's "hit", comments #24 #25), the bands
## below the crack come down in front of him base first over fold_lower_s; the ones above it fold
## off his side onto the sim's fold slabs, nearest the crack first, by fold_s, each shattering as
## it lands and showing its slab. No point of a band is ever below the street (lift()).
## Presentation only; part of ToppleFx. Every number is the "topple_fx" tuning.

const HALF_CELL := 0.5  # a part's "pos" is its chunk's centre
const FLAT := PI * 0.5

var _fx: ToppleFx
var _cfg: Dictionary
var _moving: Array[Dictionary] = []


func _init(fx: ToppleFx, cfg: Dictionary) -> void:
	_fx = fx
	_cfg = cfg


## Poses the fall's bands for time t of its `duration` (splitting it on the first call); false
## when the piece does not split (a landmark's burst), and the caller poses it whole.
func pose(f: Dictionary, view: BuildingView, t: float, duration: float) -> bool:
	if not f.has("bands") and not _split(f, view):
		return false
	var bands: Array = f["bands"]
	var n := bands.size()
	var dir: Vector2 = f["dir"]
	var rigid := ToppleFx.tilt(_cfg, t, duration)
	var gap := Num.f(_cfg["band_gap_s"])
	var bend_from := maxf(0.0, duration - gap * (n - 1) - Num.f(_cfg["bend_s"]))
	for i: int in n:
		var band := _live(bands[i])
		if band == null:
			continue
		var down_at := duration - gap * (n - 1 - i)  # when this band lies on the street
		var angle := rigid
		if i < n - 1 and t > bend_from:
			var lead := FLAT - ToppleFx.tilt(_cfg, down_at, duration)
			angle += lead * clampf((t - bend_from) / maxf(0.001, down_at - bend_from), 0.0, 1.0)
		angle = minf(angle, FLAT)
		_turn(band, dir, angle)
		if i < n - 1 and angle >= FLAT:
			_fx.shatter(band)
	return true


## The sim landed it on the street: whatever is not down yet lies flat and shatters.
func land(f: Dictionary) -> void:
	_release(f)
	var dir: Vector2 = f["dir"]
	for raw: Variant in f["bands"]:
		var band := _live(raw)
		if band != null:
			_turn(band, dir, FLAT)
			_fx.shatter(band)


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
