extends RefCounted
## The sim play suite's claw windup check (D-166, D-185): powers.swipe_windup only says how long
## before its rake the sim cues the arm (presentation's cue, ClawSwipe). The same seeded rampage
## at each growth step (young, Behemoth, Colossus) with five levels of Claws, run once at the
## windup the code rake was timed to (OLD_WINDUP) and once at the tuning's (the keyed rake's), lands
## every rake on the same tick and does the same damage; only the cue moves.

## The windup the code rake was timed to (s), before the keyed rake (D-185) lengthened it.
const OLD_WINDUP := 0.3
const DT := 1.0 / 60.0
const STEPS := 1800  # 30 s of play
const CLAWS := 5

var _check: Callable


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var tune := Content.tuning()
	var old := tune.duplicate(true)
	var old_powers: Dictionary = old["powers"]
	old_powers["swipe_windup"] = OLD_WINDUP
	var windup := Num.f(tune["powers"]["swipe_windup"])
	for size: int in 3:
		var now := _play(size, tune)
		var was := _play(size, old)
		var rakes: Array = now["rakes"]
		var was_rakes: Array = was["rakes"]
		var same := now["rakes"] == was["rakes"] and now["damage"] == was["damage"]
		var says := "claw windup %.2f s vs %.2f s, size %d:" % [windup, OLD_WINDUP, size + 1]
		says += " the same %d rakes on the same ticks (%d)," % [rakes.size(), was_rakes.size()]
		_check.call(
			rakes.size() > 0 and same,
			says + " the same damage (%s vs %s)" % [now["damage"], was["damage"]]
		)
		_check.call(
			Num.f(now["lead"]) > Num.f(was["lead"]),
			(
				"claw windup, size %d: the cue comes earlier before its rake (%.2f s vs %.2f s)"
				% [size + 1, now["lead"], was["lead"]]
			)
		)


## One scripted rampage (the sim suite's player: walk to the nearest standing building, the
## signature when ready): {"rakes": the ticks of each "swipe", "damage": what it destroyed, "lead":
## the mean seconds from a cue to its rake}.
func _play(size: int, tune: Dictionary) -> Dictionary:
	var sim := _sim(size, tune)
	var rakes: Array[int] = []
	var cue := -1
	var leads := 0.0
	var target := Vector2(INF, INF)
	for step: int in STEPS:
		if sim.over:
			break
		if step % 15 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and not sim.body.stomp_reaches(target):
			move = (target - sim.kaiju_pos).normalized()
		for event: Dictionary in sim.step(DT, move, sim.ability_ready_in <= 0.0):
			if str(event["type"]) == "swipe_windup":
				cue = step
			elif str(event["type"]) == "swipe":
				rakes.append(step)
				leads += (step - cue) * DT if cue >= 0 else 0.0
	var swipe := sim.powers.swipe
	var damage := {
		"swipes": swipe.swipes,
		"cut": swipe.cut,
		"carved": swipe.carved,
		"chunks": sim.chunks_destroyed,
		"destruction": Num.f(sim.result()["destruction"]),
	}
	return {"rakes": rakes, "damage": damage, "lead": leads / maxf(1.0, rakes.size())}


## The reptilian at growth step `size` (0 young .. 2 Colossus) with CLAWS levels of Claws, in the
## suite's city 0, army seed 0, on `tune`.
func _sim(size: int, tune: Dictionary) -> RampageSim:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {"claws": CLAWS})
	)
	stats["size"] = float(size + 1)
	var city: Dictionary = tune["city"]
	var layout := CityGen.generate(Seeds.make("city", 0), city)
	var sim := RampageSim.new(stats, tune, layout, Seeds.make("army", 0))
	sim.ability_type = str(species["ability"]["type"])
	sim.body.use_species("reptilian")
	return sim
