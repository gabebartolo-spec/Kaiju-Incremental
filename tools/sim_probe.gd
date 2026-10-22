extends RefCounted
## What the sim-speed probes share (tools/sim_profile.gd times a step, tools/sim_checksum.gd proves
## a speed-up changed nothing): one growth step's stats, grown city and scripted player. The
## player is tools/pacing.gd's (walk to the nearest standing building, signature when ready, glide
## half the time, ultimate and dash always), at its step, so a time measured here is a pacing-run
## time. Probes only: nothing in sim/ reads a clock.

const DT := 1.0 / 15.0
## The player picks its next building every this many steps.
const RETARGET := 8
## The player holds the glide button this many steps out of GLIDE_CYCLE.
const GLIDE_HELD := 15
const GLIDE_CYCLE := 30
## Upgrades owned in each growth step (index: size tier - 1): a tree about half bought.
const LEVELS: Array[Dictionary] = [
	{"claws": 2, "hide": 1},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "r_tail": 2, "r_momentum": 2, "r_ablaze": 1},
	{
		"claws": 5,
		"hide": 5,
		"rage": 3,
		"evolve1": 1,
		"evolve2": 1,
		"r_tail": 4,
		"r_momentum": 4,
		"r_shear": 2,
		"r_ablaze": 1,
		"r_alarm": 2,
	},
	{
		"claws": 5,
		"hide": 5,
		"rage": 3,
		"evolve1": 1,
		"evolve2": 1,
		"evolve3": 1,
		"r_tail": 4,
		"r_momentum": 4,
		"r_shear": 3,
		"r_beam": 1,
		"r_ablaze": 1,
		"r_alarm": 3,
		"r_front": 2,
	},
]

## tier -> the grown city's layout, made once.
static var _layouts: Dictionary = {}


## The run stats of a growth step (1..4) for a species.
static func stats_for(tier: int, species_id: String) -> Dictionary:
	var species := Content.species_def(species_id)
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS[clampi(tier, 1, 4) - 1], species_id)
	return UpgradeTree.run_stats(Content.section("kaiju"), species, tree)


## The tuning a rampage at `stats` runs on: the stage's grown city and its hardened defences.
static func tuning_for(stats: Dictionary) -> Dictionary:
	var tier := Num.i(stats["size"])
	var stage := CityGrowth.tuning_for(Content.tuning(), tier)
	return CityGrowth.hardened(stage, Content.tuning(), tier, Num.f(stats.get("stage_growth", 0.0)))


## The grown city of a growth step, seed 0 as pacing.gd's.
static func layout_for(tier: int) -> Array[Dictionary]:
	if not _layouts.has(tier):
		var cfg: Dictionary = CityGrowth.tuning_for(Content.tuning(), tier)["city"]
		_layouts[tier] = CityGen.generate(Seeds.make("city", 0), cfg)
	return _layouts[tier]


## The plain constructor, as a factory for new_sim.
static func plain(
	stats: Dictionary, tuning: Dictionary, layout: Array[Dictionary], rng: RandomNumberGenerator
) -> RampageSim:
	return RampageSim.new(stats, tuning, layout, rng)


## A rampage for one growth step, army stream `run`; `factory` makes the sim (Probe.plain, or a
## timed subclass's constructor with the same arguments).
static func new_sim(tier: int, species_id: String, run: int, factory: Callable) -> RampageSim:
	var stats := stats_for(tier, species_id)
	var sim: RampageSim = factory.call(
		stats, tuning_for(stats), layout_for(tier), Seeds.make("army", run)
	)
	sim.ability_type = str(Content.species_def(species_id)["ability"]["type"])
	sim.body.use_species(species_id)
	return sim


## Plays the scripted player until the rampage ends or `max_steps` pass; returns the steps taken.
static func play(sim: RampageSim, max_steps: int = 1 << 30) -> int:
	var steps := 0
	var target := Vector2(INF, INF)
	while not sim.over and steps < max_steps:
		if steps % RETARGET == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
			move = (target - sim.kaiju_pos).normalized()
		var held := RampageSim.HELD if steps % GLIDE_CYCLE < GLIDE_HELD else 0
		sim.step(DT, move, sim.ability_ready_in <= 0.0, held | RampageSim.ULTIMATE | Dash.BUTTON)
		steps += 1
	return steps


## A short exact fingerprint of where a played rampage ended: result(), chunks_destroyed, the steps
## taken and the kaiju's final state, as bytes (floats keep every bit), hashed.
static func digest(sim: RampageSim, steps: int) -> String:
	var state: Array = [
		sim.result(),
		sim.chunks_destroyed,
		steps,
		sim.kaiju_pos,
		sim.hp,
		sim.rubble,
		sim.tanks.size(),
		sim.falls.size(),
	]
	return var_to_bytes(state).hex_encode().sha256_text().substr(0, 16)


## The growth steps named on the command line (--tiers=1,2), else all four.
static func tiers_from(args: PackedStringArray) -> Array[int]:
	var out: Array[int] = []
	for arg: String in args:
		if arg.begins_with("--tiers="):
			for part: String in arg.substr(8).split(","):
				out.append(part.to_int())
	return out if not out.is_empty() else [1, 2, 3, 4]


## The value of --name=value on the command line, else `fallback`.
static func option(args: PackedStringArray, name: String, fallback: String) -> String:
	for arg: String in args:
		if arg.begins_with("--%s=" % name):
			return arg.substr(name.length() + 3)
	return fallback
