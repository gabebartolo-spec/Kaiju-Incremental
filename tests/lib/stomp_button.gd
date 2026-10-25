extends RefCounted
## The croc standing suite's stomp-button check (director 2026-10-26: "Its own button", "Button
## replaces it"; keyboard and mouse and pad): no stomp falls on its own; a press stomps once, a
## second press before stomp_interval has run out does not, the button held stomps once per
## interval, and walking a press falls on the next footfall. The "stomp" action is bound on the
## keyboard, the mouse and the pad. The croc's stomp is slowed (director 2026-10-26: 0.80x, "it
## looks too fast ... weightless rather than titanic"), and Frenzy is its speed-up ("Frenzy becomes
## your speed-up": 0.825 .. 0.90x over 4 levels): 10 held stomps come the clip's length apart,
## 0.875 s at level 0 and 0.778 s at level 4 (+-1 frame), never faster; the other species' Frenzy
## still shortens the interval. The adult (Colossus), standing, fixed 60 Hz steps.

const DT := 1.0 / 60.0
const HERO_HP := 1.0e9

var _check: Callable


func _init(check: Callable) -> void:
	_check = check


func run() -> void:
	var idle := _stomps(_sim(), func(_f: int) -> bool: return false, 180)
	_check.call(idle.size() == 0, "no stomp without the button (%d in 3 s == 0)" % idle.size())
	var sim := _sim()
	var interval := sim.stomp.interval()
	var gap := roundi(interval * 0.5 / DT)
	var twice := _stomps(sim, func(f: int) -> bool: return f == 0 or f == gap, 180)
	_check.call(
		twice.size() == 1 and twice[0] == 0,
		"a press stomps at once, a second before stomp_interval does not (%s)" % [twice]
	)
	var held := _stomps(_sim(), func(_f: int) -> bool: return true, 180)
	var want := floori(3.0 / interval - 0.001) + 1
	_check.call(
		held.size() == want,
		"held, it stomps once per stomp_interval (%d in 3 s == %d)" % [held.size(), want]
	)
	_walking()
	_bindings()
	_frenzy()


## The player effect of the croc's Frenzy: level 0 and level 4 stomp at different paces, each the
## clip's length at its speed, and the speed never passes 0.90x.
func _frenzy() -> void:
	var gaps: Array[float] = []
	for lv: int in [0, 4]:
		var sim := sim_at("reptilian", lv)
		var held := _stomps(sim, func(_f: int) -> bool: return true, 600)
		var want := StompBeat.KEYED_INTERVAL / (0.8 + 0.025 * lv)
		var worst := 0.0
		for i: int in range(1, mini(held.size(), 10)):
			worst = maxf(worst, absf((held[i] - held[i - 1]) * DT - want))
		gaps.append(float(held[mini(9, held.size() - 1)] - held[0]) * DT / 9.0)
		(
			_check
			. call(
				held.size() >= 10 and worst <= DT * 1.01 and sim.stomp.speed() <= 0.9,
				(
					"Frenzy %d: 10 held stomps %.3f s apart (%.3f +- 1 frame, worst off %.3f), speed %.3f"
					% [lv, gaps[-1], want, worst, sim.stomp.speed()]
				)
			)
		)
	_check.call(gaps[0] > gaps[1], "Frenzy 4 stomps faster than none (%s)" % [gaps])
	var bug := sim_at("insectoid", 4)
	_check.call(
		bug.stomp.speed() == 1.0 and bug.stomp.interval() < sim_at("insectoid", 0).stomp.interval(),
		"the insectoid's Frenzy still shortens its stomp interval (%.2f s)" % bug.stomp.interval()
	)


## Walking, a press falls on the next footfall, on the foot that lands.
func _walking() -> void:
	var sim := _sim()
	for f: int in 120:
		sim.step(DT, Vector2(0.0, -1.0), false, 0)
	var at := -1
	for f: int in 120:
		var press := RampageSim.STOMP if f == 0 else 0
		for event: Dictionary in sim.step(DT, Vector2(0.0, -1.0), false, press):
			if str(event["type"]) == "stomp" and at < 0:
				at = f if event["on_foot"] and sim.body.footfall_now else 1000
	_check.call(
		at >= 0 and at < 60,
		"walking, a press stomps on the next footfall (frame %d, within a step)" % at
	)


func _bindings() -> void:
	var kinds := {}
	if InputMap.has_action("stomp"):
		for event: InputEvent in InputMap.action_get_events("stomp"):
			kinds[event.get_class()] = true
	_check.call(
		(
			kinds.has("InputEventKey")
			and kinds.has("InputEventMouseButton")
			and kinds.has("InputEventJoypadButton")
		),
		"the stomp is bound on keyboard, mouse and pad (%s)" % [kinds.keys()]
	)


## The frames (of n) a stomp event came on, pressing the button on the frames `press` says.
func _stomps(sim: RampageSim, press: Callable, n: int) -> Array[int]:
	var out: Array[int] = []
	for f: int in n:
		var buttons := RampageSim.STOMP if press.call(f) else 0
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, buttons):
			if str(event["type"]) == "stomp":
				out.append(f)
	return out


func _sim() -> RampageSim:
	return sim_at("reptilian", 0)


## A seeded rampage of `species` (the Colossus) with Frenzy at level `frenzy`.
static func sim_at(species_id: String, frenzy: int) -> RampageSim:
	var species := Content.species_def(species_id)
	var levels := {"frenzy": frenzy} if frenzy > 0 else {}
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels)
	)
	stats["size"] = 3.0
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species(species_id)
	sim.hp = HERO_HP
	sim.max_hp = HERO_HP
	return sim
