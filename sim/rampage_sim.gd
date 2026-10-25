class_name RampageSim
extends RefCounted
## One rampage, as pure simulation: the kaiju, the city's buildings as real structures
## (Structure: chunks that fall when unsupported and towers that topple), the army.
## Presentation feeds input to step() and draws the events it returns; it never decides an
## outcome. Ground-plane coordinates are Vector2(x, z); chunk centres are world Vector3.


class Building:
	var x: float
	var z: float
	var w: int
	var d: int
	var height: int
	var tier: int
	var style: int
	var frame: Structure
	## A landmark's id (data/landmarks.json) or ""; rubble_bonus multiplies what its chunks pay.
	var landmark := ""
	var rubble_bonus := 1.0
	## False past the arena's edge (CityBand): it breaks and pays, but never counts to the fall.
	var in_arena := true
	## What its chunks pay, as a share of a smash: a burnt-out building's (FireSpread) is less.
	var pay_share := 1.0
	## A piece of the railway's viaduct or station (RailLayout: {"piece", "station"}), else empty.
	var rail: Dictionary = {}
	## Chunks it stood with when the rampage began (RunTally reads a landmark's against it).
	var start_chunks := 0

	func is_rail() -> bool:
		return not rail.is_empty()

	## Kept meshed wherever the kaiju is (BuildingStream): a landmark, or the railway.
	func is_held() -> bool:
		return landmark != "" or is_rail()

	## World centre of chunk c.
	func chunk_world(c: Vector3i) -> Vector3:
		return Vector3(x - w * 0.5 + c.x + 0.5, c.y + 0.5, z - d * 0.5 + c.z + 0.5)

	## World position of a local frame point (e.g. a pivot edge).
	func local_to_world(p: Vector3) -> Vector3:
		return Vector3(x - w * 0.5 + p.x, p.y, z - d * 0.5 + p.z)


## A part of a building on its way down: dropping straight, or toppling over an edge.
class Fall:
	var id: int
	var building: int
	var cells: Array[Vector3i]
	var kind: String
	var pivot: Vector3
	var dir: Vector2
	var drop: float
	var height: float
	var width := -1.0  # across a topple, sim units (a carved part's; < 0: from its chunks)
	var t := 0.0
	var duration: float


class Tank:
	var id: int
	var pos: Vector2
	var hp: float
	var cooldown: float
	## Burning or ink-coated: damage per second until coat_t runs out.
	var coat_t := 0.0
	var coat_dps := 0.0


## step() button flags.
const HELD := 1
const ULTIMATE := 2
## A tank's footprint radius for area hits.
const TANK_RADIUS := 0.6

var stats: Dictionary
var army: Dictionary
var city: Dictionary
var ability_type := "ring"
var buildings: Array[Building] = []
var tanks: Array[Tank] = []
var kaiju_pos := Vector2.ZERO
var facing := Vector2(0, -1)
var hp: float
var max_hp: float
var time_left: float
var rubble: float = 0.0
## The elevated railway and its trains (Rail).
var rail: Rail
var chunks_destroyed := 0
var chunks_total := 0
var falls: Array[Fall] = []
var tanks_destroyed := 0
var ability_ready_in := 0.0
var over := false
var end_reason := ""
## Seconds the rampage has run, and the demo's Endless mode (Endless), null in a normal run.
var elapsed := 0.0
var endless: Endless
var arena_half: float
var next_fall_id := 0
var collapse: Collapse
## The fine destruction grid (Carving): buildings carved cell by cell once first hit.
var carving: Carving
## The tanks' behaviour (Army); the tanks themselves are in `tanks`.
var army_units: Army
## Species powers (SpeciesPowers), the helicopters (AirWing) and the insectoid's young (Brood).
var powers: SpeciesPowers
var air: AirWing
var brood: Brood
var stomp: RampageStomp
var emerge: Emergence  # the rise from the river that starts a game's run (D-083)
## The body as a solid that breaks what it walks into; it steers the facing with weight.
var body: BodyContact
var powers_cfg: Dictionary
## How high the kaiju stands (floors): 0 on the street, more on a roof it climbed.
var stand_y := 0.0
## In the air (gliding): no stomps, no blocking.
var airborne := false
var ultimate_ready_in := 0.0
## While set, every chunk and unit _hit_area damages is coated: {"kind", "dps", "seconds"}.
var hit_coat: Dictionary = {}
## While true, _hit_area also reaches helicopters whatever the kaiju's height.
var hit_air := false
## Events of the current step (Collapse appends here too).
var events: Array[Dictionary]:
	get:
		return _events
var _rng: RandomNumberGenerator
var _events: Array[Dictionary] = []


## Set ability_type ("cone", "leap" or "ring") before the first step.
func _init(
	p_stats: Dictionary, tuning: Dictionary, layout: Array[Dictionary], rng: RandomNumberGenerator
) -> void:
	stats = Growth.stage_stats(p_stats, tuning)
	army = tuning["army"]
	city = tuning["city"]
	powers_cfg = tuning["powers"]
	_rng = rng
	hp = stat("hp")
	max_hp = hp
	time_left = stat("run_seconds")
	arena_half = CityGen.half_extent(city) + Num.f(city["arena_margin"])
	for entry: Dictionary in layout:
		var b := Landmarks.building(entry, Num.f(city["chunk_hp"]))
		b.in_arena = CityBand.touches(b.x, b.z, Vector2(b.w, b.d), arena_half)
		b.start_chunks = b.frame.alive_count
		buildings.append(b)
		chunks_total += b.frame.alive_count if b.in_arena else 0
	var rail_cfg: Dictionary = tuning["rail"]
	var rail_from := RailLayout.add_pieces(buildings, city, rail_cfg)
	kaiju_pos = Vector2(0.0, CityGen.half_extent(city))  # on the ring avenue, at the south edge
	collapse = Collapse.new(self)
	carving = Carving.new(self, tuning)
	army_units = Army.new(self, rng)
	powers = SpeciesPowers.new(self, Seeds.derive(rng, 0x5EED))
	var air_cfg: Dictionary = tuning["air"]
	air = AirWing.new(self, air_cfg, Seeds.derive(rng, 0xA1))
	brood = Brood.new(self, Seeds.derive(rng, 0xB0))
	stomp = RampageStomp.new(self)
	emerge = Emergence.new(city, tuning)
	body = BodyContact.new(self, tuning)
	rail = Rail.new(self, tuning, Seeds.derive(rng, 0x7A11))
	for n: int in range(rail_from, buildings.size()):
		rail.add_piece(n)


## The buildings that stand on lots: all but the railway's pieces, which stand over a street.
func lot_buildings() -> Array[Building]:
	return buildings.filter(func(b: Building) -> bool: return not b.is_rail())


func stat(stat_name: String) -> float:
	return Num.f(stats.get(stat_name, 0.0))


func size_tier() -> int:
	return Num.i(stat("size"))


## How big the kaiju is drawn and how far its attacks reach (Growth.body_scale).
func body_scale() -> float:
	return Growth.body_scale(stats, city)


func stomp_radius() -> float:
	return stat("stomp_radius") * body_scale()


func ability_reach() -> float:
	return stat("ability_range") * body_scale()


## How high the kaiju can strike: a young one only reaches the lower floors.
func reach_height() -> float:
	return Num.f(city["kaiju_height"]) * body_scale()


## The highest point it can strike from where it stands (a climbed roof adds its height).
func reach_top() -> float:
	return stand_y + reach_height()


## Chunks' worth of how far the city has fallen, as the army and air wing escalate on it.
func escalation() -> int:
	return chunks_destroyed + Endless.escalation(self)


func destruction() -> float:
	return Num.f(chunks_destroyed) / maxf(1.0, Num.f(chunks_total))


## What the rampage did, for the results screen (and the save's bests). "best_combo" is the combo
## system's hook (D-259): it is absent until the combo lands, and the screen shows a dash.
func result() -> Dictionary:
	return {
		"rubble": Num.i(floor(rubble)),
		"destruction": destruction(),
		"buildings": collapse.destroyed_buildings(),
		"seconds": elapsed,
		"tanks": tanks_destroyed,
		"helis": air.destroyed,
		"rooftops": army_units.rooftops_destroyed,
		"agents": army_units.taskforce.kills,
		"city_seconds": army_units.taskforce.city_seconds(),
		"toppled": collapse.toppled,
		"tallest_topple": collapse.tallest_topple,
		"landmarks": RunTally.landmarks_felled(buildings),
		"reason": end_reason,
	}


## Advances the rampage by dt (move, signature pressed, button flags HELD/ULTIMATE/Dash.BUTTON).
func step(dt: float, move: Vector2, signature_pressed: bool, buttons: int = 0) -> Array[Dictionary]:
	var signature_held := buttons & HELD != 0
	_events = []
	if over or emerge.step(self, dt):
		return _events
	time_left -= dt
	elapsed += dt
	hp = minf(max_hp, hp + stat("regen") * dt)
	var old_facing := facing
	var moving := move.length() > 0.05
	var stride := body.steer(dt, move.limit_length(1.0) * float(moving))  # a stick at rest: zero
	if moving:  # along the body's heading as it turns (BodyContact.steer): a turn walks an arc
		var speed := stat("speed") * powers.speed_mult() * stride
		kaiju_pos = clamp_to_arena(kaiju_pos + body.heading * speed * dt)
		body.walked(speed * dt, dt)
	powers.after_move(dt, old_facing, moving)
	body.step(dt, buttons & Dash.BUTTON != 0)
	stomp.step(dt)
	ability_ready_in = maxf(0.0, ability_ready_in - dt)
	if signature_pressed and ability_ready_in <= 0.0:
		ability_ready_in = maxf(0.5, stat("ability_cooldown"))
		_signature()
	ultimate_ready_in = maxf(0.0, ultimate_ready_in - dt)
	if buttons & ULTIMATE != 0 and ultimate_ready_in <= 0.0 and powers.has_ultimate():
		ultimate_ready_in = Num.f(powers_cfg["ultimate_cooldown"])
		powers.ultimate()
	powers.step(dt, signature_held)
	brood.step(dt)
	collapse.step(dt)
	army_units.step(dt)
	air.step(dt)
	rail.step(dt)
	Endless.step(self, dt)
	var why := Endless.over_reason(self)
	if why != "":
		end(why)
	return _events


## Lets go of the rings between the sim and its parts (SimTeardown, D-179) so a dropped sim is
## freed: Godot never frees objects that count each other, and every rampage kept its city in
## memory (about 240 MB a rampage in tools/pacing.gd). Call it when the rampage is over for good,
## after result() is read: the parts no longer reach the sim, so it cannot be stepped again.
func dispose() -> void:
	SimTeardown.cut(self)


## Ends the rampage (also the pause menu's End Rampage, reason "ended"); earnings are kept.
func end(reason: String) -> void:
	over = true
	end_reason = reason
	hp = maxf(0.0, hp)
	_events.append({"type": "run_over", "reason": reason})


func clamp_to_arena(pos: Vector2) -> Vector2:
	return pos.clamp(Vector2(-arena_half, -arena_half), Vector2(arena_half, arena_half))


## Full force within `radius`, fading to nothing at twice the radius: a harder blow breaks a
## wider crater, because more of the fading edge still beats what a chunk can take.
static func falloff(distance: float, radius: float) -> float:
	if distance <= radius:
		return 1.0
	return clampf(1.0 - (distance - radius) / radius, 0.0, 1.0)


func _signature() -> void:
	var reach := ability_reach()
	var damage := stat("ability_damage")
	match ability_type:
		"cone":
			BreathCone.breathe(self, reach, damage)
		"leap":
			var from := kaiju_pos
			kaiju_pos = clamp_to_arena(
				kaiju_pos + facing * Num.f(city["leap_distance"]) * body_scale()
			)
			var land := kaiju_pos
			_events.append({"type": "ability", "kind": "leap", "reach": reach, "from": from})
			hit_area(
				func(p: Vector2, r: float) -> float: return falloff(p.distance_to(land) - r, reach),
				damage
			)
			powers.leap_landed()
		_:
			var centre := kaiju_pos
			_events.append({"type": "ability", "kind": "ring", "reach": reach})
			hit_area(
				func(p: Vector2, r: float) -> float:
					return falloff(p.distance_to(centre) - r, reach),
				damage
			)


## Damages every standing chunk on floors y_lo..y_hi-1 (y_hi < 0: up to the kaiju's reach), every
## tank, roof squad and helicopter it can reach, by damage x force(position, own radius), force
## 0..1; then lets the hit buildings settle. hit_coat and hit_air widen what it does.
func hit_area(force: Callable, damage: float, y_lo: int = 0, y_hi: int = -1) -> void:
	var top := ceili(reach_height()) if y_hi < 0 else y_hi
	StrayShell.hit_buildings(self, force, damage, Vector2i(y_lo, top))
	for tank: Tank in tanks:
		var k: float = force.call(tank.pos, TANK_RADIUS)
		tank.hp -= damage * k
		if k > 0.0 and not hit_coat.is_empty():
			tank.coat_t = Num.f(hit_coat["seconds"])
			tank.coat_dps = Num.f(hit_coat["dps"]) * Num.f(powers_cfg["ink_unit_mult"])
	army_units.splash(force, maxi(0, y_lo), top)  # then clears dead tanks and squads
	air.hit(force, damage, hit_air or reach_top() >= air.altitude())
	rail.hit(force, damage)


## Nearest standing ground-floor chunk in the arena to `from` (an attacker's goal), or INF.
func nearest_standing(from: Vector2) -> Vector2:
	var best := Vector2(INF, INF)
	var best_d := INF
	for b: Building in buildings:
		if b.frame.alive_count == 0 or not b.in_arena:
			continue
		for x: int in b.w:
			for z: int in b.d:
				if b.frame.alive(Vector3i(x, 0, z)):
					var p := b.chunk_world(Vector3i(x, 0, z))
					var d := from.distance_squared_to(Vector2(p.x, p.z))
					if d < best_d:
						best_d = d
						best = Vector2(p.x, p.z)
	return best


## Damages chunks of one building by the same amount each.
func damage_chunks(index: int, cells: Array[Vector3i], amount: float) -> int:
	var amounts := PackedFloat32Array()
	amounts.resize(cells.size())
	amounts.fill(amount)
	return damage_cells(index, cells, amounts)


## Damages chunks of one building, each by its own amount. A building that dwarfs the kaiju
## takes less of each blow (Growth.dwarf_mult, D-091). Broken chunks pay rubble; then whatever
## lost support starts to fall. Returns chunks broken. A carved building goes to Carving.
func damage_cells(index: int, cells: Array[Vector3i], amounts: PackedFloat32Array) -> int:
	if carving.takes(index):
		return carving.apply(index, cells, amounts)
	var b := buildings[index]
	var mult := Growth.dwarf_mult(size_tier(), b.tier, city)
	var broken: Array[Vector3i] = []
	for n: int in cells.size():
		if b.frame.damage(cells[n], amounts[n] * mult):
			broken.append(cells[n])
	if broken.is_empty():
		return 0
	pay(b, broken.size(), 1.0)
	_events.append({"type": "chunks_broken", "building": index, "cells": broken})
	collapse.settle(index)
	return broken.size()


func pay(b: Building, chunks: int, bonus: float) -> void:
	chunks_destroyed += chunks if b.in_arena else 0
	var mult := bonus * b.rubble_bonus * b.pay_share * stat("rubble_mult")
	rubble += chunks * b.tier * Num.f(city["chunk_rubble"]) * mult
