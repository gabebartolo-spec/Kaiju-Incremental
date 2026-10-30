class_name Carving
extends RefCounted
## The rampage on the fine destruction grid (D-094 WP7; D-097 "true physics ... carving
## included"; D-099 carved towers fall toward the cut side). A building's first hit promotes it
## (CellPromoter: its BuildingCells grid in a VoxelFrame); from then on every blow carves its
## cells, and VoxelFrame.settle() (VoxelSupport) decides what drops and what topples, and which
## way. Part of RampageSim. Landmarks carve too ("carve is universal", director 2026-10-26): their
## grid is LandmarkCells (WP6), and a ring landmark's arc (the stadium) that has lost
## arc_shed_cells cells brings its section above the stub down as one topple before the settle,
## the chunk Structure's rule (Arcs) on cells.
##
## Wear: each grid column keeps, per floor, the sum of every blow that reached it (the force at
## that column, so a stomp's falloff carves a round crater); a cell breaks once its column's sum
## reaches its material's strength x the building's chunk_hp, today's chunk rule cell by cell
## (a building that dwarfs the kaiju takes Growth.dwarf_mult of each blow, D-091, and they
## still add up).
##
## The chunk Structure stays as a coarse mirror for what still reads chunks (army squads, the
## kaiju's climb and blocking, nearest_standing): a chunk is gone once at most chunk_alive_share
## of the cells it had at promotion are left, and only then pays its rubble and counts as
## destroyed, as a broken chunk does today (one that falls pays when it lands, with the topple
## bonus). Pure and deterministic: fixed scan orders, no RNG, no clock.


## One promoted building's grid and the bookkeeping beside it.
class Grid:
	var frame: VoxelFrame
	## Per grid column and floor: the blows it has taken (x + z * w + floor * w * d).
	var wear := PackedFloat32Array()
	## Per chunk (Structure.index): cells left, cells at promotion, 1 once the chunk is gone.
	var live := PackedInt32Array()
	var full := PackedInt32Array()
	var dead := PackedByteArray()
	## Grid x, z, y -> the chunk column and floor that owns it (BuildingCells.clear_chunk's
	## rule: what stands proud of a face or above the roof belongs to the edge chunk).
	var cx := PackedInt32Array()
	var cz := PackedInt32Array()
	var fy := PackedInt32Array()
	var bw: int
	var bd: int
	var floors: int
	var hp: float
	## A ring landmark's grid (its arcs count what it loses, LandmarkCells.shed), else null.
	var ring: LandmarkCells
	## What the blow being worked out has broken: grid indices and their materials.
	var removed := PackedInt32Array()
	var mats := PackedByteArray()

	func chunk(i: int) -> int:
		var w := frame.w
		var x := cx[i % w]
		var z := cz[(i / w) % frame.d]
		return x + z * bw + fy[i / (w * frame.d)] * bw * bd


var sim: RampageSim
## Off: every building stays on its chunk Structure (data/tuning.json destruction.carve).
var on := false
var alive_share := 0.5
## How far beyond the kaiju's strike reach a building is warmed (sim units, tuning destruction),
## and how far while it emerges (it strikes nothing then, so the nearest are made ready first).
var warm_margin := 3.0
var warm_emerge_margin := 3.0
var promoter := CellPromoter.new()
## Building index -> Grid, for the buildings hit so far.
var grids: Dictionary = {}
## Cells carved by blows and cells that fell, over the rampage.
var cells_carved := 0
var cells_fallen := 0
var _materials: Array[Dictionary] = []
var _strength := PackedFloat32Array()
var _weakest := INF
var _party: Array[Dictionary] = []
## The building being warmed and the stage it is at (see warm()); -1 when none.
var _warming := -1
var _warm_stage := 0


func _init(p_sim: RampageSim, tuning: Dictionary) -> void:
	sim = p_sim
	var cfg: Dictionary = tuning.get("destruction", {})
	on = cfg.get("carve", false) == true
	alive_share = Num.f(cfg.get("chunk_alive_share", 0.5))
	warm_margin = Num.f(cfg.get("warm_margin", 3.0))
	warm_emerge_margin = Num.f(cfg.get("warm_emerge_margin", warm_margin))
	_materials = Content.materials()
	LandmarkCells.preload_models(on)  # a landmark's first hit then only builds its grid
	_strength.resize(256)
	for m: Dictionary in _materials:
		var s := Num.f(m.get("strength", 1.0))
		_strength[Num.i(m["id"])] = s
		_weakest = minf(_weakest, s)


## True when building n is carved rather than broken by chunks.
func takes(_n: int) -> bool:
	return on


func promoted(n: int) -> bool:
	return grids.has(n)


func frame(n: int) -> VoxelFrame:
	var g: Grid = grids.get(n, null)
	return g.frame if g != null else null


## Pre-promotion (b2-3): one stage of the work a building's first hit would otherwise do all at
## once, per sim step, on the nearest buildings the kaiju can reach (or is about to) that are not
## promoted yet: stage 0 generates its cells, stage 1 makes the fine grid, stage 2 does its first
## settle. A hit that arrives first just does the stages it finds undone. Nearest first, ties
## by building index: the same order for the same run. Nothing a hit would not do is done, only
## sooner: the first settle's falls (if the generated grid had any) start as any settle's do.
## While the kaiju emerges (Emergence.step) it warms out to warm_emerge_margin instead.
func warm(emerging: bool = false) -> void:
	if not on:
		return
	if _warming < 0:
		var margin := warm_emerge_margin if emerging else warm_margin
		_warming = WarmOrder.next_cold(self, sim.buildings, margin)
		_warm_stage = 0
		if _warming < 0:
			return
	var n := _warming
	if _warm_stage == 0:
		_cells_of(n)
	elif _warm_stage == 1:
		_promote(n)
	elif _warm_stage == 2 and not frame(n).settled_once:
		sim.collapse.settle(n)
	_warm_stage += 1
	if _warm_stage > 2:
		_warming = -1


## A force-shaped blow (RampageSim.hit_area's force and damage) on floors floors.x..floors.y-1
## of building n (a coating, sim.hit_coat, covers the chunks it reaches).
func hit(n: int, force: Callable, damage: float, floors: Vector2i) -> void:
	var b := sim.buildings[n]
	var g: Grid = grids.get(n, null)
	var chunks: Array[Vector3i] = []
	for y: int in range(maxi(0, floors.x), mini(floors.y, b.height)):
		for x: int in b.w:
			for z: int in b.d:
				var c := Vector3i(x, y, z)
				if not (b.frame.alive(c) if g == null else g.live[b.frame.index(c)] > 0):
					continue
				var p := b.chunk_world(c)
				var k: float = force.call(Vector2(p.x, p.z), 0.5)
				if k > 0.0:
					chunks.append(c)
	if chunks.is_empty():
		return
	if not sim.hit_coat.is_empty():
		sim.powers.coat(n, chunks)
	g = _promote(n)
	var f := g.frame
	var res := f.res
	var mult := _mult(b)
	var at := PackedFloat32Array()  # the force at each grid column, sampled once
	at.resize(f.w * f.d)
	at.fill(-1.0)
	var spans := PackedInt32Array()  # per chunk: its grid columns and floor
	for c: Vector3i in chunks:
		var xs := _span(c.x, b.w, f.offset.x, f.w, res)
		var zs := _span(c.z, b.d, f.offset.z, f.d, res)
		spans.append_array([xs.x, xs.y, zs.x, zs.y, c.y])
		for gz: int in range(zs.x, zs.y):
			for gx: int in range(xs.x, xs.y):
				var col := gx + gz * f.w
				if at[col] < 0.0:
					var local := Vector3(gx + f.offset.x + 0.5, 0.0, gz + f.offset.z + 0.5) / res
					var p := b.local_to_world(local)
					var k: float = force.call(Vector2(p.x, p.z), 0.5 / res)
					at[col] = maxf(0.0, k)
	CarvingCells.wear(self, g, spans, at, PackedFloat32Array(), damage, mult)
	_finish(n, g)


## Even blows on chunks of building n, each by its own amount (impacts, coatings, powers).
## Returns the chunks that went.
func apply(n: int, cells: Array[Vector3i], amounts: PackedFloat32Array) -> int:
	var b := sim.buildings[n]
	var g: Grid = grids.get(n, null)
	var hits: Array[int] = []
	for k: int in cells.size():
		var c := cells[k]
		if b.frame.inside(c) and (b.frame.alive(c) if g == null else g.live[b.frame.index(c)] > 0):
			hits.append(k)
	if hits.is_empty():
		return 0
	g = _promote(n)
	var f := g.frame
	var spans := PackedInt32Array()  # per chunk hit: its grid columns and floor, and its blow
	var each := PackedFloat32Array()
	for k: int in hits:
		var c := cells[k]
		var xs := _span(c.x, b.w, f.offset.x, f.w, f.res)
		var zs := _span(c.z, b.d, f.offset.z, f.d, f.res)
		spans.append_array([xs.x, xs.y, zs.x, zs.y, c.y])
		each.append(amounts[k])
	CarvingCells.wear(self, g, spans, PackedFloat32Array(), each, 0.0, _mult(b))
	return _finish(n, g)


## What lost support in building n since its last settle, in Collapse's part shape: "cells"
## are the chunks the part took with it (they pay when it lands), and the fine part rides along
## ("index": grid indices, "mats": their materials, "low" and "height" in floors, "width"
## across a topple and "drop" for the rest, in sim units; "base": the footprint of its lowest
## layer, building-local x, z; "gutted": nothing under that layer and taller than its narrower
## side, Collapse's rule for a tower whose base went at once, D-099).
func settle(n: int) -> Array[Dictionary]:
	var g: Grid = grids[n]
	var f := g.frame
	var out: Array[Dictionary] = []
	for part: Dictionary in _shed(g) + f.settle():
		var index: PackedInt32Array = part["index"]
		_lost(g, index)
		var info := CarvingCells.fallen(g, index)  # g.live loses its cells
		cells_fallen += index.size()
		out.append(CarvingCells.part_event(f, part, info, _deaths(n, g)))
	return out


## A ring landmark's arcs that lost arc_shed_cells cells (LandmarkCells.shed): each section above
## the stub taken out of the grid as a topple over the stub's edge, the rim outward and the stands
## inward, in settle()'s part shape.
func _shed(g: Grid) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if g.ring == null:
		return out
	var f := g.frame
	for section: Dictionary in g.ring.shed():
		var index := PackedInt32Array()
		for c: Vector3i in section["cells"]:
			g.ring.clear_cell(c)
			var i := f.index(c)
			if f.cells[i] != VoxelFrame.EMPTY:
				index.append(i)
		if index.is_empty():
			continue
		var part := f.take(index)
		var pivot: Vector3 = section["pivot"]
		part["kind"] = "topple"
		part["pivot"] = pivot / f.res
		part["dir"] = section["dir"]
		out.append(part)
	return out


## Cells that left grid g: a ring landmark's arcs count them (a cell already gone from its own
## copy counts nothing).
func _lost(g: Grid, index: PackedInt32Array) -> void:
	if g.ring == null:
		return
	var f := g.frame
	var plan := f.w * f.d
	for i: int in index:
		g.ring.clear_cell(Vector3i(i % f.w, i / plan, (i / f.w) % f.d) + f.offset)


## Building n's generated cells (made once; promotion takes them).
func _cells_of(n: int) -> CellGrid:
	if _party.is_empty():
		_party = PartyWalls.of(sim.buildings)
	return promoter.on_hit(n, sim.buildings[n], _party[n])


## Building n's grid, made on its first hit (a cells_promoted event for the view).
func _promote(n: int) -> Grid:
	if grids.has(n):
		return grids[n]
	var b := sim.buildings[n]
	var cells := _cells_of(n)
	var g := Grid.new()
	var f := VoxelFrame.new(Vector3i(b.w, b.height, b.d), cells.res, _materials)
	f.adopt(cells.dims, cells.offset, cells.cells)
	g.frame = f
	if cells is LandmarkCells and (cells as LandmarkCells).arcs != null:
		g.ring = cells
	g.bw = b.w
	g.bd = b.d
	g.floors = b.height
	g.hp = b.frame.max_hp
	g.cx = _owners(f.w, f.offset.x, f.res, b.w)
	g.cz = _owners(f.d, f.offset.z, f.res, b.d)
	g.fy = _owners(f.h, f.offset.y, f.res, b.height)
	g.wear.resize(f.w * f.d * b.height)
	var chunks := b.w * b.d * b.height
	g.full = CarvingCells.counts(g, chunks)
	g.dead.resize(chunks)
	g.live = g.full.duplicate()
	for ci: int in chunks:
		g.dead[ci] = int(not b.frame.alive(_chunk_cell(g, ci)))
	grids[n] = g
	(
		sim
		. events
		. append(
			{
				"type": "cells_promoted",
				"building": n,
				"dims": cells.dims,
				"offset": cells.offset,
				"cells": f.alive_count,
			}
		)
	)
	return g


## By material id, the blow (in chunk_hp) that breaks a cell of it; and the weakest of them.
func strengths() -> PackedFloat32Array:
	return _strength


func weakest() -> float:
	return _weakest


## A blow of `amount` on grid column `col` (x + z * w) at floor `floor_y`: breaks every cell
## there whose material its worn total now reaches (into g.removed and g.mats).
func wear_column(g: Grid, col: int, floor_y: int, amount: float) -> void:
	var f := g.frame
	var wi := col + floor_y * f.w * f.d
	g.wear[wi] += amount
	var level := g.wear[wi] / g.hp
	if level < _weakest:
		return
	var plan := f.w * f.d
	var rows := _span(floor_y, g.floors, f.offset.y, f.h, f.res)
	for gy: int in range(rows.x, rows.y):
		var i := col + gy * plan
		var m := f.cells[i]
		if m != VoxelFrame.EMPTY and level >= _strength[m]:
			f.clear_index(i)
			g.removed.append(i)
			g.mats.append(m)
			g.live[g.chunk(i)] -= 1


## After a blow: the events, the chunks it finished (paid now) and the settle. Returns the
## chunks that went.
func _finish(n: int, g: Grid) -> int:
	var b := sim.buildings[n]
	var removed := g.removed
	var mats := g.mats
	g.removed = PackedInt32Array()
	g.mats = PackedByteArray()
	if removed.is_empty():
		return 0
	cells_carved += removed.size()
	_lost(g, removed)
	sim.events.append({"type": "cells_carved", "building": n, "index": removed, "mats": mats})
	var broken := _deaths(n, g)
	if not broken.is_empty():
		sim.pay(b, broken.size(), 1.0)
		sim.events.append({"type": "chunks_broken", "building": n, "cells": broken})
	sim.collapse.settle(n)
	return broken.size()


## Chunks of building n left with at most alive_share of their cells: gone from the Structure
## mirror now (scan order).
func _deaths(n: int, g: Grid) -> Array[Vector3i]:
	var b := sim.buildings[n]
	var out: Array[Vector3i] = []
	for ci: int in g.live.size():
		if g.dead[ci] == 0 and g.live[ci] <= floori(g.full[ci] * alive_share):
			g.dead[ci] = 1
			var c := _chunk_cell(g, ci)
			b.frame.remove(c)
			out.append(c)
	return out


func _mult(b: RampageSim.Building) -> float:
	return Growth.dwarf_mult(sim.size_tier(), b.tier, sim.city)


static func _chunk_cell(g: Grid, ci: int) -> Vector3i:
	return Vector3i(ci % g.bw, ci / (g.bw * g.bd), (ci / g.bw) % g.bd)


## Grid range [x, y) along one axis of chunk `c` (of `count`): RES cells, run on to the grid's
## edge for the first and last chunk.
static func _span(c: int, count: int, offset: int, size: int, res: int) -> Vector2i:
	var lo := 0 if c == 0 else c * res - offset
	var hi := size if c == count - 1 else (c + 1) * res - offset
	return Vector2i(clampi(lo, 0, size), clampi(hi, 0, size))


## Grid coordinate along one axis -> the chunk that owns it (clamped to the building).
static func _owners(size: int, offset: int, res: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(size)
	for g: int in size:
		out[g] = clampi(floori(float(g + offset) / res), 0, count - 1)
	return out
