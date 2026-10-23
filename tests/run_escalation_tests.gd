extends "res://tests/lib/runner.gd"
## Rampage escalation suite (D-154, EscalationView): the sky, fog and sun follow how much of the
## city is destroyed and never step; at destruction 0 the look is exactly the time's own; fog and
## warmth rise with destruction at all four times; the targets are warm (no blue); blackouts are
## dusk and night only, spread from damaged buildings, and cut floor by floor.
## Seeded by design: the city layout and army are seeded; no clock, no randomness in the view.
##   godot --headless --path . --script tests/run_escalation_tests.gd

const TIMES: Array[String] = ["dusk", "night", "morning", "noon"]
const STEPS := 20
const FRAME := 1.0 / 60.0


## The scene a live check builds: the pieces EscalationView eases and a sim to ruin.
class Stage:
	var parent: Node3D
	var sim: RampageSim
	var view: EscalationView
	var env: Environment
	var sun: DirectionalLight3D


func suite_name() -> String:
	return "Escalation"


func run_checks() -> void:
	await _t("_check_curve")
	await _t("_check_zero_is_base")
	await _t("_check_rises_with_ruin")
	await _t("_check_targets_warm")
	await _t("_check_blackout_times")
	await _t("_check_eased_not_stepped")
	await _t("_check_blackout_spreads")


## The base values a time's look gives (what CityEnvironment sets), without building a scene.
func _base_for(time: String) -> Dictionary:
	Content.set_time(time)
	return {
		"fog_density": Look.value("fog_density"),
		"fog_color": Look.color("fog_color"),
		"ambient_color": Look.color("ambient_color"),
		"sky_top": Look.color("sky_top"),
		"sky_horizon": Look.color("sky_horizon"),
		"sun_energy": Look.value("sun_energy"),
		"sun_color": Look.color("sun_color"),
	}


func _check_curve() -> void:
	check(EscalationView.amount_of(0.0) == 0.0, "no escalation at destruction 0")
	check(EscalationView.amount_of(0.09) == 0.0, "nothing visible below 10% destroyed")
	check(EscalationView.amount_of(0.7) == 1.0, "full escalation by 70% destroyed")
	var last := 0.0
	var rising := true
	for n: int in STEPS + 1:
		var a := EscalationView.amount_of(float(n) / STEPS)
		rising = rising and a >= last
		last = a
	check(rising, "the escalation never falls as destruction rises")


func _check_zero_is_base() -> void:
	for time: String in TIMES:
		var base := _base_for(time)
		var got := EscalationView.eased(base, time, 0.0)
		var same := true
		for key: String in base:
			same = same and got[key] == base[key]
		check(same, "%s at destruction 0 equals the time's own look exactly" % time)


func _warmth(c: Color) -> float:
	return c.r - c.b


func _check_rises_with_ruin() -> void:
	for time: String in TIMES:
		var base := _base_for(time)
		var fog := -1.0
		var sky := -INF
		var haze := -INF
		var ok_fog := true
		var ok_sky := true
		var ok_haze := true
		for n: int in STEPS + 1:
			var v := EscalationView.eased(base, time, float(n) / STEPS)
			var f := Num.f(v["fog_density"])
			ok_fog = ok_fog and f >= fog
			fog = f
			var sh: Color = v["sky_horizon"]
			var h := _warmth(sh)
			ok_sky = ok_sky and h >= sky - 0.0001
			sky = h
			var fc: Color = v["fog_color"]
			var w := _warmth(fc)
			ok_haze = ok_haze and w >= haze - 0.0001
			haze = w
		check(ok_fog, "%s: the fog only thickens as the ruin grows" % time)
		check(ok_sky, "%s: the sky horizon only warms as the ruin grows" % time)
		check(ok_haze, "%s: the haze only warms as the ruin grows" % time)
		var full := EscalationView.eased(base, time, 1.0)
		check(Num.f(full["fog_density"]) > Num.f(base["fog_density"]) * 1.5, "%s: fog clearly thicker at full" % time)
		check(Num.f(full["sun_energy"]) <= Num.f(base["sun_energy"]) * 1.001, "%s: the sun never brightens" % time)


func _check_targets_warm() -> void:
	var times: Dictionary = Content.section("escalation")["times"]
	for time: String in TIMES:
		var cfg: Dictionary = times[time]
		var warm := true
		for key: String in ["sky_top", "sky_horizon", "fog_color", "sun_color", "ambient_color"]:
			var c := Color(str(cfg[key]))
			warm = warm and c.r >= c.g and c.g >= c.b  # orange, amber, brown: never blue
		check(warm, "%s: every escalation colour is warm (red over green over blue)" % time)
	var day := Color(str(times["noon"]["sky_horizon"]))
	var dusk := Color(str(times["dusk"]["sky_horizon"]))
	check(dusk.s > day.s, "the dusk sky glows more orange than the smoky day sky")


func _check_blackout_times() -> void:
	check(EscalationView.blacks_out("dusk"), "dusk has blackouts")
	check(EscalationView.blacks_out("night"), "night has blackouts")
	check(not EscalationView.blacks_out("morning"), "morning has no blackouts")
	check(not EscalationView.blacks_out("noon"), "noon has no blackouts")


## A scene with the pieces EscalationView eases and a sim whose destruction the test sets.
func _stage(time: String) -> Stage:
	Content.set_time(time)
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var sim := RampageSim.new({}, Content.tuning(), layout, Seeds.make("army", 0))
	var parent := Node3D.new()
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Look.color("sky_top")
	mat.sky_horizon_color = Look.color("sky_horizon")
	sky.sky_material = mat
	env.sky = sky
	env.fog_density = Look.value("fog_density")
	env.fog_light_color = Look.color("fog_color")
	world.environment = env
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = Look.value("sun_energy")
	parent.add_child(sun)
	var view := EscalationView.new(sim, func(_i: int) -> BuildingView: return null)
	parent.add_child(view)
	root.add_child(parent)
	var out := Stage.new()
	out.parent = parent
	out.sim = sim
	out.view = view
	out.env = env
	out.sun = sun
	return out


func _check_eased_not_stepped() -> void:
	var s := _stage("night")
	var sim := s.sim
	var env := s.env
	var sun := s.sun
	var base_fog := env.fog_density
	var base_sun := sun.light_energy
	await process_frame
	check(env.fog_density == base_fog and sun.light_energy == base_sun, "destruction 0: the frame's light is untouched")
	sim.chunks_total = 1000
	sim.chunks_destroyed = 800  # a sudden jump in destruction
	var last := env.fog_density
	var biggest := 0.0
	for _f: int in 600:
		s.view._process(FRAME)
		biggest = maxf(biggest, absf(env.fog_density - last))
		last = env.fog_density
	var span := base_fog * (Num.f(Content.section("escalation")["times"]["night"]["fog_mult"]) - 1.0)
	check(biggest < span * 0.05, "a sudden jump in ruin eases the fog (largest frame step %.5f of %.5f)" % [biggest, span])
	check(absf(env.fog_density - base_fog * 2.2) < base_fog * 0.02, "the fog settles at the night target")
	check(sun.light_energy >= base_sun * 0.99, "night keeps its moonlight")
	s.parent.queue_free()
	await process_frame


func _check_blackout_spreads() -> void:
	var near_dark := {}
	for time: String in ["night", "morning"]:
		var s := _stage(time)
		var sim := s.sim
		var view := s.view
		await process_frame
		# Flatten the building nearest the kaiju: its neighbours lose power, far blocks do not.
		var order: Array[int] = []
		for i: int in sim.buildings.size():
			order.append(i)
		order.sort_custom(
			func(a: int, b: int) -> bool:
				return Vector2(sim.buildings[a].x, sim.buildings[a].z).length() < Vector2(sim.buildings[b].x, sim.buildings[b].z).length()
		)
		var hit := order[0]
		var cells: Array[Vector3i] = []
		var hb := sim.buildings[hit]
		for y: int in hb.height:
			for x: int in hb.w:
				for z: int in hb.d:
					cells.append(Vector3i(x, y, z))
		sim.damage_chunks(hit, cells, 9999.0)
		var nearby := -1
		var far := order[order.size() - 1]
		for i: int in order:
			if i != hit and sim.buildings[i].frame.alive_count > 0:
				nearby = i
				break
		for _f: int in 240:
			view._process(0.5)
		var dark_near := view._dark[nearby]
		near_dark[time] = dark_near
		if time == "night":
			check(dark_near > 0.0, "night: a block next to a flattened building has lost its power")
			check(view._dark[far] == 0.0, "night: a block far from the damage keeps its lights")
			var step := Num.f(Content.section("escalation")["blackout"]["floors_per_second"]) * 0.5
			var before: float = view._dark[nearby]
			view._target[nearby] = before + 100.0
			view._active[nearby] = true
			view._spread(0.5)
			check(view._dark[nearby] - before <= step + 0.001, "windows go dark floor by floor at the set speed, never all at once")
		else:
			check(dark_near == 0.0, "morning: nothing goes dark by day")
		s.parent.queue_free()
		await process_frame
	Content.set_time("dusk")
