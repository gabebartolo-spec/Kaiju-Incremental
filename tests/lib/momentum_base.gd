extends "res://tests/lib/leap_base.gd"
## Shared fixtures for the titan's run suite (run_momentum_tests, D-337): the croc at (0, 30)
## facing north on hand-made layouts, with the run on or off, and the seeded charge.

const NORTH := Vector2(0.0, -1.0)
const EAST := Vector2(1.0, 0.0)
## The charge: the croc at (0, 30) walks north CHARGE_S; the first building's near face stands
## LEAD beyond his snout (he meets it at full momentum), the rest of a row GAP apart.
const CHARGE_S := 13.0  # his walk (about 2.75 units a second, young speed 0.5) clears the row
const LEAD := 9.0
const GAP := 6.0
const ROW := 4
const WIDTH := 3  # cells a side
const SHORT := 2  # floors: under the young croc's shoulder (about 3.1)
const TALL := 8  # floors: over it
const BETWEEN := 5  # floors: over the young croc's shoulder, under the Behemoth's (about 6.5)
const DWARFS := 2  # a building tier that dwarfs the young croc (Growth.dwarf_mult < 1)


## The croc at `levels` on `layout`, the claws idle, with the run on (his entry) or off (none).
func _runner(levels: Dictionary, layout: Array[Dictionary], on: bool = true) -> RampageSim:
	var sim := _croc(levels, layout)
	sim.stats["swipe_damage"] = 0.0
	if not on:
		sim.powers.run.titan = {}
	return sim


## The croc's entry, as the reptilian plays it.
func _titan() -> Dictionary:
	return _croc({}, []).powers.run.titan


## The z of a WIDTH-deep building's centre whose near face stands `lead` beyond the snout of the
## croc at `levels` standing at (0, 30) facing north.
func _ahead_of_snout(levels: Dictionary, lead: float) -> float:
	return 30.0 - _snout(levels) - lead - WIDTH * 0.5


## How far ahead of kaiju_pos the croc at `levels` reaches (world units): his snout.
func _snout(levels: Dictionary) -> float:
	var probe := _croc(levels, [])
	var front := 0.0
	for d: Array in probe.body.discs():
		front = maxf(front, Num.f(d[0]) + Num.f(d[1]))
	return front * probe.body_scale()


## A row of ROW short buildings up the street from LEAD beyond the young croc's snout, of a
## tier that dwarfs him (BodyVolume.sweep: without the run he is held, chewing each).
func _row() -> Array[Dictionary]:
	var first := _ahead_of_snout({}, LEAD)
	var row: Array[Dictionary] = []
	for n: int in ROW:
		row.append(_tiered(Vector2(0.0, first - n * GAP), WIDTH, SHORT, DWARFS))
	return row


## A WIDTH-wide block of `floors` at `at`, of `tier`.
func _tiered(at: Vector2, w: int, floors: int, tier: int) -> Dictionary:
	var block := _block(at, w, floors)
	block["tier"] = tier
	return block


## Walks `sim` north CHARGE_S: where he ended (z), the least momentum on a step that broke
## something, the slams, and the chunks each of the first `count` buildings lost.
func _charge(sim: RampageSim, count: int) -> Dictionary:
	var full: Array[int] = []
	for n: int in count:
		full.append(sim.buildings[n].frame.alive_count)
	var low := INF
	var slams := 0
	for _n: int in roundi(CHARGE_S / DT):
		var before := sim.chunks_destroyed
		slams += _count(sim.step(DT, NORTH, false, 0), "slam")
		if sim.chunks_destroyed > before:
			low = minf(low, sim.powers.momentum)
	var lost: Array[int] = []
	for n: int in count:
		lost.append(full[n] - sim.buildings[n].frame.alive_count)
	return {"z": snappedf(sim.kaiju_pos.y, 0.001), "low": low, "slams": slams, "lost": lost}


func _count(events: Array[Dictionary], kind: String) -> int:
	var n := 0
	for event: Dictionary in events:
		if str(event["type"]) == kind:
			n += 1
	return n


func _walk(sim: RampageSim, seconds: float, stick: Vector2) -> void:
	for _n: int in roundi(seconds / DT):
		sim.step(DT, stick, false, 0)
