extends RefCounted
## The croc standing suite's stomp-button check (director 2026-10-26: "Its own button", "Button
## replaces it"; keyboard and mouse and pad): no stomp falls on its own; a press stomps once, a
## second press before stomp_interval has run out does not, the button held stomps once per
## interval, and walking a press falls on the next footfall. The "stomp" action is bound on the
## keyboard, the mouse and the pad. The adult (Colossus), standing, fixed 60 Hz steps.

const DT := 1.0 / 60.0
const HERO_HP := 1.0e9

var _check: Callable


func _init(check: Callable) -> void:
	_check = check


func run() -> void:
	var idle := _stomps(_sim(), func(_f: int) -> bool: return false, 180)
	_check.call(idle.size() == 0, "no stomp without the button (%d in 3 s == 0)" % idle.size())
	var sim := _sim()
	var interval := sim.stat("stomp_interval")
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
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	stats["size"] = 3.0
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.hp = HERO_HP
	sim.max_hp = HERO_HP
	return sim
