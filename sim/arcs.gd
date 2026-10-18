class_name Arcs
extends RefCounted
## A ring-shaped landmark's arcs (the stadium): its plan is cut into sectors round its middle,
## in two bands, the rim (outer wall and roof) and the stands inside it. The first chunk an arc
## loses brings down everything of it above a stub of `stub` floors as one toppling section, the
## rim outward and the stands inward, so a breach reads as a section of wall failing and lands as
## a rubble strip (Collapse), not as scattered holes. Part of Structure.settle(). Pure sim.

var stub := 0
var _w := 0
## Plan column (x + z * w) -> arc, or -1 (outside the ring: the corner masts).
var _of := PackedInt32Array()
var _dirs: Array[Vector2i] = []
## Standing chunks per arc when it last shed (or at the start).
var _whole := PackedInt32Array()


## cfg: {"sectors", "stub" (floors that stay standing), "inner" and "rim" (normalised radii where
## the stands and the rim start: 0 is the middle, 1 the footprint's inscribed ellipse; the
## pitch inside "inner" belongs to no arc)}.
static func build(frame: Structure, cfg: Dictionary) -> Arcs:
	var a := Arcs.new()
	var sectors := Num.i(cfg["sectors"])
	var rim := Num.f(cfg["rim"])
	var inner := Num.f(cfg["inner"])
	a.stub = Num.i(cfg["stub"])
	a._w = frame.w
	a._of.resize(frame.w * frame.d)
	a._of.fill(-1)
	for x: int in frame.w:
		for z: int in frame.d:
			var at := Vector2((x + 0.5) / (frame.w * 0.5) - 1.0, (z + 0.5) / (frame.d * 0.5) - 1.0)
			if at.length() > 1.0 or at.length() < inner:
				continue
			var band := 1 if at.length() >= rim else 0
			var s := posmod(floori((at.angle() + PI) / TAU * sectors), sectors)
			a._of[x + z * frame.w] = band * sectors + s
	for band: int in 2:
		for s: int in sectors:
			var out := Vector2.from_angle((s + 0.5) / sectors * TAU - PI)
			var dir := Vector2i(signi(roundi(out.x * 10.0)), 0)
			if absf(out.y) > absf(out.x):
				dir = Vector2i(0, signi(roundi(out.y * 10.0)))
			a._dirs.append(dir if band == 1 else -dir)
	a._whole = a._count(frame)
	return a


## The sections to bring down now: for each arc that lost a chunk since it last shed, every
## chunk of it still standing above the stub, as {"cells", "kind": "topple", "pivot", "dir"}.
## The caller removes them.
func shed(frame: Structure) -> Array[Dictionary]:
	var now := _count(frame)
	var out: Array[Dictionary] = []
	for g: int in now.size():
		if now[g] >= _whole[g]:
			continue
		var cells: Array[Vector3i] = []
		for y: int in range(stub, frame.h):
			for z: int in frame.d:
				for x: int in frame.w:
					if _of[x + z * _w] == g and frame.alive(Vector3i(x, y, z)):
						cells.append(Vector3i(x, y, z))
		_whole[g] = now[g] - cells.size()
		if not cells.is_empty():
			out.append(
				{
					"cells": cells,
					"kind": "topple",
					"pivot": _pivot(cells, _dirs[g]),
					"dir": _dirs[g]
				}
			)
	return out


func _count(frame: Structure) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(_dirs.size())
	for y: int in frame.h:
		for z: int in frame.d:
			for x: int in frame.w:
				var g := _of[x + z * _w]
				if g >= 0 and frame.alive(Vector3i(x, y, z)):
					out[g] += 1
	return out


## The edge it tips over: the section's far side toward `dir`, at the top of the stub.
func _pivot(cells: Array[Vector3i], dir: Vector2i) -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var sum := Vector2.ZERO
	for c: Vector3i in cells:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
		hi = Vector2(maxf(hi.x, c.x + 1), maxf(hi.y, c.z + 1))
		sum += Vector2(c.x + 0.5, c.z + 0.5)
	var mid := sum / cells.size()
	var px := hi.x if dir.x > 0 else (lo.x if dir.x < 0 else mid.x)
	var pz := hi.y if dir.y > 0 else (lo.y if dir.y < 0 else mid.y)
	return Vector3(px, stub, pz)
