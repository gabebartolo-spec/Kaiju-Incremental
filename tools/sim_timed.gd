extends RefCounted
## RampageSim and its sub-systems with a stopwatch round the calls worth timing
## (tools/sim_prof.gd), for tools/sim_profile.gd: each class below is its sim class with the same
## constructor, whose timed methods wrap `super` and change nothing else. TimedSim swaps the
## sub-systems for these after the normal constructor, built from the same arguments and seeded
## streams, so a timed rampage plays out exactly as a plain one (the probe checks the two
## fingerprints agree). No clock reaches sim/.

const Prof := preload("res://tools/sim_prof.gd")
const Convoys := preload("res://tools/sim_timed_convoy.gd")


## The sim: a step's total, the stomp and signature, the area hits, the player's lookup.
class TimedSim:
	extends RampageSim

	func _init(
		p_stats: Dictionary,
		tuning: Dictionary,
		layout: Array[Dictionary],
		rng: RandomNumberGenerator
	) -> void:
		super(p_stats, tuning, layout, rng)
		var air_cfg: Dictionary = tuning["air"]
		collapse = TCollapse.new(self)
		carving = TCarving.new(self, tuning)
		army_units = TArmy.new(self, rng)
		powers = TPowers.new(self, Seeds.derive(rng, 0x5EED))
		air = TAir.new(self, air_cfg, Seeds.derive(rng, 0xA1))
		brood = TBrood.new(self, Seeds.derive(rng, 0xB0))
		body = TBody.new(self, tuning)

	func step(
		dt: float, move: Vector2, signature_pressed: bool, buttons: int = 0
	) -> Array[Dictionary]:
		Prof.begin("sim.step (own code)")
		var events := super.step(dt, move, signature_pressed, buttons)
		Prof.end()
		return events

	func _stomp() -> void:
		Prof.begin("sim.stomp")
		super._stomp()
		Prof.end()

	func _signature() -> void:
		Prof.begin("sim.signature")
		super._signature()
		Prof.end()

	func hit_area(force: Callable, damage: float, y_lo: int = 0, y_hi: int = -1) -> void:
		Prof.begin("sim.hit_area")
		super.hit_area(force, damage, y_lo, y_hi)
		Prof.end()

	func damage_cells(index: int, cells: Array[Vector3i], amounts: PackedFloat32Array) -> int:
		Prof.begin("sim.damage_cells")
		var broken := super.damage_cells(index, cells, amounts)
		Prof.end()
		return broken

	func nearest_standing(from: Vector2) -> Vector2:
		Prof.begin("player.nearest_standing")
		var at := super.nearest_standing(from)
		Prof.end()
		return at


class TBody:
	extends BodyContact

	func _init(p_sim: RampageSim, tuning: Dictionary) -> void:
		super(p_sim, tuning)
		if Prof.drill:
			_volume = TVolume.new(p_sim, cfg)

	func steer(dt: float, want: Vector2) -> float:
		Prof.begin("body.steer")
		var stride := super.steer(dt, want)
		Prof.end()
		return stride

	func step(dt: float, dash_pressed: bool = false) -> void:
		Prof.begin("body.step")
		super.step(dt, dash_pressed)
		Prof.end()

	func _sweep(from: Vector2, from_heading: Vector2, to: Vector2, to_heading: Vector2) -> void:
		Prof.begin("body.sweep")
		super._sweep(from, from_heading, to, to_heading)
		Prof.end()

	func inside(pos: Vector2, facing: Vector2) -> Dictionary:
		Prof.begin("body.inside")
		var out := super.inside(pos, facing)
		Prof.end()
		return out


class TVolume:
	extends BodyVolume

	func near(from: Vector2, to: Vector2, reach: float) -> Array[int]:
		Prof.begin("volume.near")
		var out := super.near(from, to, reach)
		Prof.end()
		return out

	func collect(pos: Vector2, facing: Vector2, into: Dictionary, near_list: Array[int]) -> void:
		Prof.begin("volume.collect")
		super.collect(pos, facing, into, near_list)
		Prof.end()


class TCollapse:
	extends Collapse

	func step(dt: float) -> void:
		Prof.begin("collapse.step")
		super.step(dt)
		Prof.end()

	func settle(index: int) -> void:
		Prof.begin("collapse.settle")
		super.settle(index)
		Prof.end()

	func _land(f: RampageSim.Fall) -> void:
		Prof.begin("collapse.land")
		super._land(f)
		Prof.end()


class TCarving:
	extends Carving

	func warm(emerging: bool = false) -> void:
		Prof.begin("carving.warm")
		super.warm(emerging)
		Prof.end()

	func hit(n: int, force: Callable, damage: float, floors: Vector2i) -> void:
		Prof.begin("carving.hit")
		super.hit(n, force, damage, floors)
		Prof.end()

	func apply(n: int, cells: Array[Vector3i], amounts: PackedFloat32Array) -> int:
		Prof.begin("carving.apply")
		var broke := super.apply(n, cells, amounts)
		Prof.end()
		return broke

	func settle(n: int) -> Array[Dictionary]:
		Prof.begin("carving.settle")
		var parts := super.settle(n)
		Prof.end()
		return parts


class TArmy:
	extends Army

	func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
		super(p_sim, rng)
		var convoy_cfg: Dictionary = cfg["convoy"]
		convoy = (
			Convoys.TConvoyDeep.new(sim, convoy_cfg)
			if Prof.drill
			else Convoys.TConvoy.new(sim, convoy_cfg)
		)
		taskforce = TTaskforce.new(sim, Seeds.derive(rng, 0x7F))

	func step(dt: float) -> void:
		Prof.begin("army.step")
		super.step(dt)
		Prof.end()

	func _step_squads(dt: float) -> bool:
		Prof.begin("army.squads")
		var lost := super._step_squads(dt)
		Prof.end()
		return lost

	func _land_strays(dt: float) -> void:
		Prof.begin("army.strays")
		super._land_strays(dt)
		Prof.end()


class TTaskforce:
	extends Taskforce

	func step(dt: float) -> void:
		Prof.begin("taskforce.step")
		super.step(dt)
		Prof.end()


class TPowers:
	extends SpeciesPowers

	func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
		super(p_sim, rng)
		tentacles = TTentacles.new(sim, rng)
		swipe = TSwipe.new(sim, cfg)
		var fire_cfg: Dictionary = cfg["fire"]
		fire = TFire.new(sim, fire_cfg, Seeds.derive(rng, 0xF12E))

	func speed_mult() -> float:
		Prof.begin("powers.speed_mult")
		var mult := super.speed_mult()
		Prof.end()
		return mult

	func blocked(pos: Vector2, radius: float) -> bool:
		Prof.begin("powers.blocked")
		var stuck := super.blocked(pos, radius)
		Prof.end()
		return stuck

	func after_move(dt: float, old_facing: Vector2, moving: bool) -> void:
		Prof.begin("powers.after_move")
		super.after_move(dt, old_facing, moving)
		Prof.end()

	func step(dt: float, held: bool) -> void:
		Prof.begin("powers.step")
		super.step(dt, held)
		Prof.end()


class TTentacles:
	extends Tentacles

	func step(dt: float) -> void:
		Prof.begin("tentacles.step")
		super.step(dt)
		Prof.end()


class TSwipe:
	extends ClawSwipe

	func step(dt: float) -> void:
		Prof.begin("swipe.step")
		super.step(dt)
		Prof.end()


class TFire:
	extends FireSpread

	func step(dt: float) -> void:
		Prof.begin("fire.step")
		super.step(dt)
		Prof.end()


class TAir:
	extends AirWing

	func step(dt: float) -> void:
		Prof.begin("air.step")
		super.step(dt)
		Prof.end()


class TBrood:
	extends Brood

	func step(dt: float) -> void:
		Prof.begin("brood.step")
		super.step(dt)
		Prof.end()


## A timed rampage: the factory tools/sim_probe.gd's new_sim takes.
static func make(
	stats: Dictionary, tuning: Dictionary, layout: Array[Dictionary], rng: RandomNumberGenerator
) -> RampageSim:
	return TimedSim.new(stats, tuning, layout, rng)
