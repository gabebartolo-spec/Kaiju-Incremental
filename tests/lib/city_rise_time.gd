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


## The keyed rise (D-270, D-199): at a stage whose body has the "rise_bay" clip (the adult), the
## kaiju crouches on the sea floor and nothing lifts it while the clip plays (at its own speed),
## the head breaks the surface once at "emerge" "keyed_surface_seconds", and it wades out on its
## feet after the clip, before the stall cap; a stage without the clip keeps the code rise.
static func check_keyed(tier: int, map_seed: int, check_fn: Callable) -> void:
	var sim: RampageSim = Harbour._fresh(tier, map_seed, tier, 0)
	var keyed := RampageRise.keyed(sim, "reptilian")
	if KaijuModel.stage_for(sim.size_tier()) != "adult":
		check_fn.call(keyed == 0.0, "stage %d: no keyed rise clip (%.2f s)" % [tier, keyed])
		return
	sim.emerge.start(sim, keyed)
	var cfg := Content.section("emerge")
	var floor_y := sim.stand_y
	var surface := roundi(Num.f(cfg["keyed_surface_seconds"]) / DT)
	var rise_ticks := floori(keyed / DT)
	var lifted := 0.0
	var ticks := 0
	var broke_at := -1
	var breaks := 0
	while sim.emerge.active and ticks < MAX_TICKS * 4:
		ticks += 1
		for e: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(e["type"]) == "surface_break":
				breaks += 1
				broke_at = ticks
		if ticks < rise_ticks:
			lifted = maxf(lifted, absf(sim.stand_y - floor_y))
	var most := ceili((keyed + Num.f(cfg["wade_seconds"])) / DT) + 1
	var cap := roundi((Num.f(cfg["max_seconds"]) + sim.emerge.late()) / DT)
	check_fn.call(
		(
			keyed > 3.0
			and lifted == 0.0
			and breaks == 1
			and absi(broke_at - surface) <= 1
			and not sim.emerge.active
			and sim.stand_y == 0.0
			and ticks <= most
			and ticks < cap
		),
		(
			(
				"stage %d, map_seed %d: the keyed rise (%.2f s) never lifts him (%.3f), the head"
				+ " broke the surface %d time(s) on tick %d (%d), out on his feet after %d ticks"
				+ " (<= %d, the cap %d)"
			)
			% [tier, map_seed, keyed, lifted, breaks, broke_at, surface, ticks, most, cap]
		)
	)
