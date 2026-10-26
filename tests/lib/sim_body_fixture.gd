extends RefCounted
## What the body-contact checks share (tests/lib/sim_body_contact.gd and sim_body_chew.gd): which
## building to walk into, where to set the body down, and how many chunks stand inside it.
## Static helpers only; no checks.

## A tower: at least this many floors and this many cells across (a young body cannot break one
## outright, D-091).
const TOWER_FLOORS := 10
const TOWER_SIDE := 4
## set_down_clear backs the body off this far at a time, up to this far in all.
const BACK_STEP := 1.0
const BACK_MAX := 80.0


## The nearest standing building of exactly this tier (no landmark, in the arena) to the kaiju,
## -1 when there is none; `at_least` (min height, min side) and `archetype` (a BuildingCells style,
## -1 any) narrow it.
static func nearest_of(sim: RampageSim, tier: int, at_least: Vector2i, archetype: int) -> int:
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if (
			b.tier != tier
			or b.landmark != ""
			or b.height < at_least.x
			or mini(b.w, b.d) < at_least.y
		):
			continue
		if archetype >= 0 and b.style % 4 != archetype:
			continue
		if not b.in_arena:
			continue  # the real band past the edge (CityBand): out of the kaiju's walk
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if d < best_d:
			best = i
			best_d = d
	return best


## The nearest tall tier-2 office tower (BuildingCells.OFFICE): the topple and swipe fixture.
static func nearest_office(sim: RampageSim) -> int:
	return nearest_of(sim, 2, Vector2i(TOWER_FLOORS, TOWER_SIDE), BuildingCells.OFFICE)


## The tower the chew fixtures use: the nearest office tower, else (a city with none in the arena,
## seeds 3 and 8) the nearest tall tier-2 building of any style; -1 only if the city has no tower.
static func nearest_tower(sim: RampageSim) -> int:
	var office := nearest_office(sim)
	if office >= 0:
		return office
	return nearest_of(sim, 2, Vector2i(TOWER_FLOORS, TOWER_SIDE), -1)


## Gives `sim` a body with the D-118 shove set aside (no chunks knocked off at a touch, no wall that
## ever gives way to a shove): a wall that dwarfs it yields to the D-091 chew alone.
static func chew_only(sim: RampageSim) -> void:
	var tuning := Content.tuning().duplicate(true)
	var contact: Dictionary = tuning["contact"]
	contact["shove_chunks"] = 0
	contact["shove_s"] = 1.0e9
	sim.body = BodyContact.new(sim, tuning)


## Sets the body down at `at` facing `facing`, wherever that is (it may overlap buildings).
static func set_down(sim: RampageSim, at: Vector2, facing: Vector2) -> void:
	sim.kaiju_pos = at
	sim.facing = facing
	sim.body.heading = facing


## set_down, backed off from `facing` until no chunk stands inside the body: a body set down on
## top of a taller neighbour starts inside it, and a taller building only gives under the chew.
## Returns how far it backed off, -1.0 if it found no clear spot within BACK_MAX.
static func set_down_clear(sim: RampageSim, at: Vector2, facing: Vector2) -> float:
	var backed := 0.0
	set_down(sim, at, facing)
	while count(sim.body.inside(sim.kaiju_pos, facing)) > 0:
		backed += BACK_STEP
		if backed > BACK_MAX:
			return -1.0
		set_down(sim, at - facing * backed, facing)
	return backed


## Chunks in a BodyContact.inside() result.
static func count(inside: Dictionary) -> int:
	var total := 0
	for index: int in inside:
		var cells: Dictionary = inside[index]
		total += cells.size()
	return total
