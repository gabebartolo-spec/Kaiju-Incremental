extends RefCounted
## The sim suite's claw swipe checks (Claws, D-095), split out to keep the runner small: five
## levels of Claws make the young reptilian's swipe break clearly more, with the body on; the
## other species keep Claws as a stomp upgrade. Includes the player-effect fixture "kaiju.swipe":
## the same seeded rampage with the swipe off destroys less of the city.

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
	var base: RampageSim = _make.call("reptilian", {}, 0, {})
	var claws: RampageSim = _make.call("reptilian", {"claws": 5}, 0, {})
	var base_end: Dictionary = _autoplay.call(base)
	var claws_end: Dictionary = _autoplay.call(claws)
	(
		_check
		. call(
			(
				base.body.active()
				and claws.body.active()
				and claws.powers.swipe.cut > base.powers.swipe.cut * 1.15
			),
			(
				(
					"five levels of claws: the swipe breaks clearly more, with the body on (%d vs %d"
					+ " chunks; city destroyed %.3f vs %.3f)"
				)
				% [
					claws.powers.swipe.cut,
					base.powers.swipe.cut,
					Num.f(claws_end["destruction"]),
					Num.f(base_end["destruction"]),
				]
			)
		)
	)
	var off: RampageSim = _make.call("reptilian", {}, 0, {})
	off.stats["swipe_damage"] = 0.0
	var off_end: Dictionary = _autoplay.call(off)
	_check.call(
		(
			base.powers.swipe.swipes > 0
			and off.powers.swipe.swipes == 0
			and Num.f(base_end["destruction"]) > Num.f(off_end["destruction"])
		),
		(
			"the young croc's swipe destroys more of the city than the same run without it"
			+ (
				" (%.3f vs %.3f, %d swipes)"
				% [
					Num.f(base_end["destruction"]),
					Num.f(off_end["destruction"]),
					base.powers.swipe.swipes
				]
			)
		)
	)
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
