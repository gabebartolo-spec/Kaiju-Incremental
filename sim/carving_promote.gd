class_name CarvingPromote
extends RefCounted
## Promotes a building to its fine carving grid on its first hit (Carving): the grid that maps
## its fine cells to chunks, and the cells_promoted event for the view.


## Building n's generated cells (made once; promotion takes them).
static func cells_of(c: Carving, n: int) -> CellGrid:
	if c._party.is_empty():
		c._party = PartyWalls.of(c.sim.buildings)
	return c.promoter.on_hit(n, c.sim.buildings[n], c._party[n])


## Building n's grid, made on its first hit (a cells_promoted event for the view).
static func promote(c: Carving, n: int) -> Carving.Grid:
	if c.grids.has(n):
		return c.grids[n]
	var b := c.sim.buildings[n]
	var cells := cells_of(c, n)
	var g := Carving.Grid.new()
	var f := VoxelFrame.new(Vector3i(b.w, b.height, b.d), cells.res, c._materials)
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
		g.dead[ci] = int(not b.frame.alive(Carving._chunk_cell(g, ci)))
	c.grids[n] = g
	_announce(c, n, cells, f)
	return g


## The cells_promoted event: the view builds the building's fine cells from it.
static func _announce(c: Carving, n: int, cells: CellGrid, f: VoxelFrame) -> void:
	(
		c
		. sim
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


## Grid coordinate along one axis -> the chunk that owns it (clamped to the building).
static func _owners(size: int, offset: int, res: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(size)
	for g: int in size:
		out[g] = clampi(floori(float(g + offset) / res), 0, count - 1)
	return out
