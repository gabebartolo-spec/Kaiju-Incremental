extends RefCounted
## The sim suite's claw swipe checks (Claws, D-095), split out to keep the runner small: five
## levels of Claws make the young reptilian's swipe break clearly more, with the body on; the
## other species keep Claws as a stomp upgrade (each run in its own city, _fixture_sim).
## Includes the player-effect fixture "kaiju.swipe":
## the same seeded rampages with the swipe off destroy less of the city. Both swipe comparisons
## average FIXTURE_RUNS seeded run indices: one seed alone flips with chaos (PR #89: towers the
## body undermines fall by their own physics, D-099).

## The player-effect fixture's seeded run indices, averaged.
const FIXTURE_RUNS := 5

var _check: Callable
var _make: Callable
var _autoplay: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim;
## autoplay(sim) -> result, the runner's scripted player.
func _init(p_check: Callable, make: Callable, autoplay: Callable) -> void:
	_check = p_check
	_make = make
	_autoplay = autoplay


func run() -> void:
	var cut := 0
	var base_cut := 0
	var carved := 0
	var base_carved := 0
	var pairs: Array[String] = []
	var active := true
	for run: int in FIXTURE_RUNS:
		var base := _fixture_sim(run)
		var claws := _fixture_sim(run, {"claws": 5})
		_autoplay.call(base)
		_autoplay.call(claws)
		active = active and base.body.active() and claws.body.active()
		cut += claws.powers.swipe.cut
		base_cut += base.powers.swipe.cut
		carved += claws.powers.swipe.carved
		base_carved += base.powers.swipe.carved
		pairs.append("%d/%d" % [claws.powers.swipe.carved, base.powers.swipe.carved])
	(
		_check
		. call(
			active and (cut > base_cut * 1.15 or carved > base_carved * 1.15),
			(
				(
					"five levels of claws: the swipe breaks clearly more, with the body on: chunks %.1f vs %.1f,"
					% [float(cut) / FIXTURE_RUNS, float(base_cut) / FIXTURE_RUNS]
				)
				+ " carved cells over %d seeds (%s)" % [FIXTURE_RUNS, ", ".join(pairs)]
			)
		)
	)
	_check_fixture()
	var bug: RampageSim = _make.call("insectoid", {"claws": 2}, 0, {})
	var bug_base: RampageSim = _make.call("insectoid", {}, 0, {})
	(
		_check
		. call(
			(
				bug.stat("swipe_damage") == 0.0
				and is_equal_approx(bug.stat("stomp_damage") - bug_base.stat("stomp_damage"), 6.0)
			),
			(
				"for the other species Claws stays a stomp upgrade: two levels add %s stomp power, %s swipe"
				% [
					bug.stat("stomp_damage") - bug_base.stat("stomp_damage"),
					bug.stat("swipe_damage")
				]
			)
		)
	)


## "kaiju.swipe": the swipe on vs off over FIXTURE_RUNS seeded rampages, each in its own city
## (city and army seed = the run index); the mean destroyed share must be higher with it (the same
## bar as the single-seed check it replaces). Its own cities because the army seed alone changes
## nothing in the 40 s scripted run: five army seeds on city 0 gave five identical pairs, one
## sample, and that one flipped to 0.160/0.161 when the body turned on arcs (turn-weight), while
## cities 1-11 kept the swipe ahead (probe, lead 10, 2026-10-21).
func _check_fixture() -> void:
	var on_sum := 0.0
	var off_sum := 0.0
	var swipes := 0
	var off_swipes := 0
	var pairs: Array[String] = []
	for run: int in FIXTURE_RUNS:
		var on := _fixture_sim(run)
		var off := _fixture_sim(run)
		off.stats["swipe_damage"] = 0.0
		var on_end: Dictionary = _autoplay.call(on)
		var off_end: Dictionary = _autoplay.call(off)
		on_sum += Num.f(on_end["destruction"])
		off_sum += Num.f(off_end["destruction"])
		swipes += on.powers.swipe.swipes
		off_swipes += off.powers.swipe.swipes
		pairs.append("%.3f/%.3f" % [Num.f(on_end["destruction"]), Num.f(off_end["destruction"])])
	_check.call(
		swipes > 0 and off_swipes == 0 and on_sum > off_sum,
		(
			(
				"the young croc's swipe destroys more of the city than the same runs without it:"
				+ " mean %.3f vs %.3f over %d seeds (%s), %d swipes"
			)
			% [
				on_sum / FIXTURE_RUNS,
				off_sum / FIXTURE_RUNS,
				FIXTURE_RUNS,
				", ".join(pairs),
				swipes
			]
		)
	)


## The young reptilian (with `levels`) in city `run` with army seed `run`: the runner's _sim, but
## in its own city (the runner's always builds city 0, so its run indices were one sample: the
## claws pairs came out five times the same, and flipped when the turn slowed, turn-step).
func _fixture_sim(run: int, levels: Dictionary = {}) -> RampageSim:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	var tune := Content.tuning()
	var city: Dictionary = tune["city"]
	var layout := CityGen.generate(Seeds.make("city", run), city)
	var sim := RampageSim.new(stats, tune, layout, Seeds.make("army", run))
	sim.ability_type = str(species["ability"]["type"])
	sim.body.use_species("reptilian")
	return sim
