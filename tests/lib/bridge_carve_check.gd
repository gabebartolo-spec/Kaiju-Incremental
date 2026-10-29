extends RefCounted
## The carving suite's player-effect fixture "bridge_carve" (D-389; the director 2026-10-30:
## "Carve, spans drop"), split out to keep the runner small: the city's river bridges as the sim
## builds them (BridgeLayout), one blow through a piece's deck mid-span, every chunk across it
## (the deck and both parapets), with the kaiju off on the bank. On: the blow carves the piece's
## own cells (cells_carved) and the deck it cut off a pier falls as fine cells, from under the
## street (into the river). Off: no cells and no fine fall; the chunk Structure is as before.

## Steps an untouched bridge stands through (the carving suite's step), the kaiju far off.
const IDLE_STEPS := 30
const DT := 1.0 / 15.0

var _check: Callable
var _make: Callable


## check: the runner's check; make(layout, carve) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	_stands()
	for carve: bool in [true, false]:
		var sim: RampageSim = _make.call([] as Array[Dictionary], carve)
		var n := _piece(sim)
		if n < 0:
			_check.call(false, "bridge_carve: the city has a river bridge piece")
			sim.dispose()
			return
		var b := sim.buildings[n]
		var cut: Array[Vector3i] = []
		for y: int in b.height:
			for x: int in b.w:
				var c := Vector3i(x, y, b.d / 2)
				if b.frame.alive(c):
					cut.append(c)
		sim.kaiju_pos = Vector2(b.x + b.w * 4.0, b.z)
		var start := sim.events.size()
		sim.damage_chunks(n, cut, INF)
		var carved := 0
		var fall := {}
		for e: Dictionary in sim.events.slice(start):
			if Num.i(e.get("building", -1)) != n:
				continue
			var type := str(e["type"])
			carved += 1 if type == "cells_carved" else 0
			if type == "fall_start" and fall.is_empty():
				fall = e
		var fine: PackedInt32Array = fall.get("index", PackedInt32Array())
		if carve:
			var pivot: Vector3 = fall.get("pivot", Vector3.ZERO)
			var ok := sim.carving.takes(n) and carved > 0 and not fine.is_empty()
			var said := "bridge_carve on: the blow carves piece %d (%d events)" % [n, carved]
			said += ", the deck cut off its pier falls as %d fine cells" % fine.size()
			said += " (%s) from y %.2f, under the street" % [str(fall.get("kind", "")), pivot.y]
			_check.call(ok and pivot.y < 0.0, said)
		else:
			_check.call(
				not sim.carving.takes(n) and carved == 0 and fine.is_empty(),
				"bridge_carve off: chunks only (%d carve events)" % carved
			)
		sim.dispose()


## The first bridge piece cut into more than one along the river (a middle one when it has one).
static func _piece(sim: RampageSim) -> int:
	var found := -1
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if not b.is_bridge() or Num.i(b.bridge["of"]) < 2:
			continue
		if found < 0 or Num.i(b.bridge["piece"]) == 1:
			found = n
		if Num.i(b.bridge["piece"]) == 1:
			break
	return found


## An untouched bridge stands: with the kaiju far off, no piece loses a chunk or pays.
func _stands() -> void:
	var sim: RampageSim = _make.call([] as Array[Dictionary], true)
	sim.kaiju_pos = Vector2(sim.arena_half, sim.arena_half)
	var before := sim.rubble
	for i: int in IDLE_STEPS:
		sim.step(DT, Vector2.ZERO, false)
	var lost: Array[int] = []
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if b.is_bridge() and b.frame.alive_count < b.start_chunks:
			lost.append(n)
	_check.call(
		lost.is_empty(),
		(
			"bridge_carve: an untouched bridge stands (pieces that lost chunks: %s; paid %.2f)"
			% [str(lost), sim.rubble - before]
		)
	)
	sim.dispose()
