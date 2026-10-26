extends RefCounted
## The whole start fits the run intro (director 2026-10-20 #11: "the entire scene should run for
## no longer than 3 seconds"; R 20.1): at stages 1-3, for the base body and the biggest it can
## grow to there, the kaiju holds under, breaks the surface once ("surface_break", after the
## hold and the rise's first tick: wholly under the water until then), and is out on its feet
## ("kaiju_emerged") within MAX_TICKS ticks at 60 a second, on its own, before the stall cap.
## Seeded by design: the rise uses no RNG; the map seeds are pinned.

const Harbour := preload("res://tests/lib/city_harbour.gd")
const MAX_TICKS := 180
const DT := 1.0 / 60.0


## `emerge`: tuning "emerge" values to override (the fail-first fixture), {} for the shipped ones.
static func check(tier: int, map_seed: int, emerge: Dictionary, check_fn: Callable) -> void:
	var grown := EmergeReach.max_growth(Content.upgrades(), "reptilian", tier)
	for growth: int in [0, grown]:
		var sim: RampageSim = Harbour._fresh(tier, map_seed, tier, growth)
		var tuning: Dictionary = Content.tuning().duplicate(true)
		var cfg: Dictionary = tuning["emerge"]
		cfg.merge(emerge, true)
		sim.emerge = Emergence.new(sim.city, tuning)
		sim.emerge.start(sim)
		var cap := roundi(Num.f(tuning["emerge"]["max_seconds"]) / DT)
		var hold := roundi(Num.f(tuning["emerge"]["hold_seconds"]) / DT)
		var ticks := 0
		var broke_at := -1
		var breaks := 0
		while sim.emerge.active and ticks < MAX_TICKS * 2:
			ticks += 1
			for e: Dictionary in sim.step(DT, Vector2.ZERO, false):
				if str(e["type"]) == "surface_break":
					breaks += 1
					broke_at = ticks
		var out := not sim.emerge.active and sim.stand_y == 0.0
		check_fn.call(
			out and ticks <= MAX_TICKS and ticks < cap and breaks == 1 and broke_at > hold + 1,
			(
				(
					"stage %d, map_seed %d, growth %d: out on its feet after %d ticks (<= %d, the"
					+ " cap %d), the head broke the surface %d time(s), on tick %d (after the"
					+ " %d-tick hold)"
				)
				% [tier, map_seed, growth, ticks, MAX_TICKS, cap, breaks, broke_at, hold]
			)
		)
