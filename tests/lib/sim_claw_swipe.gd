extends RefCounted
## The sim suite's claw swipe checks (Claws, D-095), split out to keep the runner small: five
## levels of Claws make the young reptilian's swipe break clearly more, with the body on; the
## other species keep Claws as a stomp upgrade. Includes the player-effect fixture "kaiju.swipe":
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
	var pairs: Array[String] = []
	var active := true
	for run: int in FIXTURE_RUNS:
		var base: RampageSim = _make.call("reptilian", {}, run, {})
		var claws: RampageSim = _make.call("reptilian", {"claws": 5}, run, {})
		_autoplay.call(base)
		_autoplay.call(claws)
		active = active and base.body.active() and claws.body.active()
		cut += claws.powers.swipe.cut
		base_cut += base.powers.swipe.cut
		pairs.append("%d/%d" % [claws.powers.swipe.cut, base.powers.swipe.cut])
	(
		_check
		. call(
			active and cut > base_cut * 1.15,
			(
				(
					"five levels of claws: the swipe breaks clearly more, with the body on: mean %.1f vs %.1f"
					% [float(cut) / FIXTURE_RUNS, float(base_cut) / FIXTURE_RUNS]
				)
				+ " chunks over %d seeds (%s)" % [FIXTURE_RUNS, ", ".join(pairs)]
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


## "kaiju.swipe": the swipe on vs off over FIXTURE_RUNS seeded rampages; the mean destroyed share
## must be higher with it (the same bar as the single-seed check it replaces).
func _check_fixture() -> void:
	var on_sum := 0.0
	var off_sum := 0.0
	var swipes := 0
	var off_swipes := 0
	var pairs: Array[String] = []
	for run: int in FIXTURE_RUNS:
		var on: RampageSim = _make.call("reptilian", {}, run, {})
		var off: RampageSim = _make.call("reptilian", {}, run, {})
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
