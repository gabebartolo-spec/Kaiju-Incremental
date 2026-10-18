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
var chunks_destroyed := 0
var chunks_total := 0
var falls: Array[Fall] = []
var tanks_destroyed := 0
var ability_ready_in := 0.0
var over := false
var end_reason := ""
var arena_half: float
var next_fall_id := 0
var collapse: Collapse
## The tanks' behaviour (Army); the tanks themselves are in `tanks`.
var army_units: Army
## Species powers (SpeciesPowers), the helicopters (AirWing) and the insectoid's young (Brood).
var powers: SpeciesPowers
var air: AirWing
var brood: Brood
var powers_cfg: Dictionary
## How high the kaiju stands (floors): 0 on the street, more on a roof it climbed.
var stand_y := 0.0
## In the air (gliding): no stomps, no blocking.
var airborne := false
var ultimate_ready_in := 0.0
## While set, every chunk and unit _hit_area damages is also coated with it:
## {"kind": "burn"|"ink", "dps": float, "seconds": float}.
var hit_coat: Dictionary = {}
## While true, _hit_area also reaches helicopters whatever the kaiju's height.
var hit_air := false
## Events of the current step (Collapse appends here too).
var events: Array[Dictionary]:
	get:
		return _events
var _rng: RandomNumberGenerator
var _stomp_timer := 0.0
var _events: Array[Dictionary] = []


## Set ability_type ("cone", "leap" or "ring") before the first step.
func _init(
	p_stats: Dictionary, tuning: Dictionary, layout: Array[Dictionary], rng: RandomNumberGenerator
) -> void:
	stats = p_stats
	army = tuning["army"]
	city = tuning["city"]
	powers_cfg = tuning["powers"]
	_rng = rng
	hp = stat("hp")
	max_hp = hp
	time_left = stat("run_seconds")
	for entry: Dictionary in layout:
		var b := Building.new()
		b.x = Num.f(entry["x"])
		b.z = Num.f(entry["z"])
		b.w = Num.i(entry["w"])
		b.d = Num.i(entry["d"])
		b.height = Num.i(entry["h"])
		b.tier = Num.i(entry["tier"])
		b.style = Num.i(entry["style"])
		b.frame = Structure.new(b.w, b.d, b.height, Num.f(city["chunk_hp"]) * b.tier)
		buildings.append(b)
		chunks_total += b.w * b.d * b.height
	var city_half := CityGen.half_extent(city)
	arena_half = city_half + Num.f(city["arena_margin"])
	kaiju_pos = Vector2(0.0, city_half)  # on the ring avenue, at the south edge
	collapse = Collapse.new(self)
	army_units = Army.new(self, rng)
	powers = SpeciesPowers.new(self, Seeds.derive(rng, 0x5EED))
	var air_cfg: Dictionary = tuning["air"]
	air = AirWing.new(self, air_cfg, Seeds.derive(rng, 0xA1))
	brood = Brood.new(self, Seeds.derive(rng, 0xB0))


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


func destruction() -> float:
	return Num.f(chunks_destroyed) / maxf(1.0, Num.f(chunks_total))


func result() -> Dictionary:
	return {
		"rubble": Num.i(floor(rubble)),
		"destruction": destruction(),
		"tanks": tanks_destroyed,
		"helis": air.destroyed,
		"rooftops": army_units.rooftops_destroyed,
		"toppled": collapse.toppled,
		"tallest_topple": collapse.tallest_topple,
		"reason": end_reason,
	}


## Advances the rampage by dt with the player's move vector, the signature button pressed
## this step, and the other buttons as flags (HELD: signature held down, ULTIMATE: pressed).
## Returns the events of this step for presentation.
func step(dt: float, move: Vector2, signature_pressed: bool, buttons: int = 0) -> Array[Dictionary]:
	var signature_held := buttons & HELD != 0
	var ultimate_pressed := buttons & ULTIMATE != 0
	_events = []
	if over:
		return _events
	time_left -= dt
	hp = minf(max_hp, hp + stat("regen") * dt)
	var old_facing := facing
	var moving := move.length() > 0.05
	if moving:
		var dir := move.limit_length(1.0)
		var speed := stat("speed") * powers.speed_mult()
		kaiju_pos = clamp_to_arena(kaiju_pos + dir * speed * dt)
		facing = powers.turn_toward(facing, dir.normalized(), dt)
	powers.after_move(dt, old_facing, moving)
	_stomp_timer -= dt
	if _stomp_timer <= 0.0:
		_stomp_timer += maxf(0.1, stat("stomp_interval"))
		if not airborne:
			_stomp()
	ability_ready_in = maxf(0.0, ability_ready_in - dt)
	if signature_pressed and ability_ready_in <= 0.0:
		ability_ready_in = maxf(0.5, stat("ability_cooldown"))
		_signature()
	ultimate_ready_in = maxf(0.0, ultimate_ready_in - dt)
	if ultimate_pressed and ultimate_ready_in <= 0.0 and powers.has_ultimate():
		ultimate_ready_in = Num.f(powers_cfg["ultimate_cooldown"])
		powers.ultimate()
	powers.step(dt, signature_held)
	brood.step(dt)
	collapse.step(dt)
	army_units.step(dt)
	air.step(dt)
	if chunks_destroyed >= chunks_total:
		end("city_fallen")
	elif hp <= 0.0:
		end("defeated")
	elif time_left <= 0.0:
		end("time")
	return _events


## Ends the rampage (also the pause menu's End Rampage, reason "ended"); earnings are kept.
func end(reason: String) -> void:
	over = true
	end_reason = reason
	hp = maxf(0.0, hp)
	_events.append({"type": "run_over", "reason": reason})


func clamp_to_arena(pos: Vector2) -> Vector2:
	return pos.clamp(Vector2(-arena_half, -arena_half), Vector2(arena_half, arena_half))


func _stomp() -> void:
	var radius := stomp_radius()
	var centre := kaiju_pos
	_events.append({"type": "stomp", "radius": radius, "lift": stand_y})
	hit_area(
		func(p: Vector2, r: float) -> float: return falloff(p.distance_to(centre) - r, radius),
		stat("stomp_damage") * powers.hit_mult(),
		maxi(0, floori(stand_y) - Num.i(powers_cfg["climb_dig"])),
		ceili(reach_top())
	)


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
			var half_angle := deg_to_rad(Num.f(city["cone_half_angle_deg"]))
			var origin := kaiju_pos
			var dir := facing
			_events.append({"type": "ability", "kind": "cone", "reach": reach})
			hit_air = true  # fire reaches up to the helicopters
			hit_area(
				func(p: Vector2, r: float) -> float:
					var to := p - origin
					if to.length() > reach + r:
						return 0.0
					return 1.0 if to.length() <= r or absf(dir.angle_to(to)) <= half_angle else 0.0,
				damage
			)
			hit_air = false
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
	for i: int in buildings.size():
		var b := buildings[i]
		var near: float = force.call(Vector2(b.x, b.z), Vector2(b.w, b.d).length() * 0.5)
		if near <= 0.0 or b.frame.alive_count == 0:
			continue
		var cells: Array[Vector3i] = []
		var amounts := PackedFloat32Array()
		for y: int in range(maxi(0, y_lo), mini(top, b.height)):
			for x: int in b.w:
				for z: int in b.d:
					var c := Vector3i(x, y, z)
					if b.frame.alive(c):
						var p := b.chunk_world(c)
						var k: float = force.call(Vector2(p.x, p.z), 0.5)
						if k > 0.0:
							cells.append(c)
							amounts.append(damage * k)
		if not hit_coat.is_empty():
			powers.coat(i, cells)
		_apply(i, cells, amounts)
	for tank: Tank in tanks:
		var k: float = force.call(tank.pos, TANK_RADIUS)
		tank.hp -= damage * k
		if k > 0.0 and not hit_coat.is_empty():
			tank.coat_t = Num.f(hit_coat["seconds"])
			tank.coat_dps = Num.f(hit_coat["dps"]) * Num.f(powers_cfg["ink_unit_mult"])
	army_units.splash(force, maxi(0, y_lo), top)  # then clears dead tanks and squads
	air.hit(force, damage, hit_air, reach_top())


## Nearest standing ground-floor chunk to `from` (what an attacker walks to), or INF if none.
func nearest_standing(from: Vector2) -> Vector2:
	var best := Vector2(INF, INF)
	var best_d := INF
	for b: Building in buildings:
		if b.frame.alive_count == 0:
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
	return _apply(index, cells, amounts)


## Damages chunks of one building, each by its own amount.
func damage_cells(index: int, cells: Array[Vector3i], amounts: PackedFloat32Array) -> int:
	return _apply(index, cells, amounts)


## A building above the kaiju's size tier is tougher. Broken chunks pay rubble; then whatever
## lost support starts to fall. Returns chunks broken.
func _apply(index: int, cells: Array[Vector3i], amounts: PackedFloat32Array) -> int:
	var b := buildings[index]
	var tough := b.tier > size_tier()
	var mult := Num.f(city["tough_mult"]) if tough else 1.0
	var broken: Array[Vector3i] = []
	for n: int in cells.size():
		if b.frame.damage(cells[n], amounts[n] * mult):
			broken.append(cells[n])
	if broken.is_empty():
		if tough and not cells.is_empty():
			_events.append({"type": "tough", "building": index})
		return 0
	pay(b, broken.size(), 1.0)
	_events.append({"type": "chunks_broken", "building": index, "cells": broken})
	collapse.settle(index)
	return broken.size()


func pay(b: Building, chunks: int, bonus: float) -> void:
	chunks_destroyed += chunks
	rubble += chunks * b.tier * Num.f(city["chunk_rubble"]) * bonus * stat("rubble_mult")


func clear_dead_tanks() -> void:
	army_units.clear_dead()
