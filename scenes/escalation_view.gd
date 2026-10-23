class_name EscalationView
extends Node
## Rampage escalation (D-154: "as a rampage escalates the haze thickens and the sky turns orange";
## "night blackouts spread as the city falls"). A final layer over whatever the time's look set:
## each frame it eases the fog, the sky, the sun and the ambient light from the time's base values
## toward that time's "inferno" targets (data/tuning.json "escalation") as sim.destruction() rises,
## and at dusk and night it cuts the lit windows around damaged buildings, floor by floor. It only
## reads the sim; a later weather layer sits under it by calling rebase() with its own values.

## One view per CityView, added after the buildings stream exists; `view_of` is BuildingStream.built.
var sim: RampageSim
var view_of: Callable
## The Environment pieces eased (found under the CityView at _ready) and the base values they had.
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _base := {}
var _time := ""
var _amount := 0.0  # the eased escalation, 0..1
var _since_scan := 0.0
var _target: PackedFloat32Array  # per building: floors that should be dark
var _dark: PackedFloat32Array  # per building: floors dark now
var _active: Dictionary = {}  # building index -> true, while its dark height is not settled


func _init(p_sim: RampageSim, p_view_of: Callable) -> void:
	sim = p_sim
	view_of = p_view_of


func _ready() -> void:
	_time = Content.time_id()
	for node: Node in get_parent().get_children():
		if node is WorldEnvironment and _env == null:
			_env = (node as WorldEnvironment).environment
		elif node is DirectionalLight3D and _sun == null:
			_sun = node
	if _env != null and _env.sky != null:
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	rebase()
	_target.resize(sim.buildings.size())
	_dark.resize(sim.buildings.size())


## Takes the Environment's present values as the base the escalation eases away from (a weather
## layer calls this after it changes the look).
func rebase() -> void:
	_base = base_of(_env, _sky, _sun)


## The eased values for `amount` (0..1) over `base`, at `time`: fog_density, fog_color, sky_top,
## sky_horizon, ambient_color, sun_energy, sun_color. At amount 0 they are `base` exactly.
static func eased(base: Dictionary, time: String, amount: float) -> Dictionary:
	var times: Dictionary = Content.section("escalation").get("times", {})
	var cfg: Dictionary = times.get(time, {})
	if cfg.is_empty() or amount <= 0.0:
		return base.duplicate()
	var out := base.duplicate()
	out["fog_density"] = Num.f(base["fog_density"]) * lerpf(1.0, Num.f(cfg["fog_mult"]), amount)
	out["sun_energy"] = Num.f(base["sun_energy"]) * lerpf(1.0, Num.f(cfg["sun_scale"]), amount)
	for key: String in ["fog_color", "sky_top", "sky_horizon", "sun_color", "ambient_color"]:
		var from: Color = base[key]
		out[key] = from.lerp(Color(str(cfg[key])), amount)
	return out


## 0..1 escalation for a destruction share: nothing under "start", full at "full", curved.
static func amount_of(destruction: float) -> float:
	var cfg := Content.section("escalation")
	var start := Num.f(cfg["start"])
	var span := maxf(0.0001, Num.f(cfg["full"]) - start)
	var t := clampf((destruction - start) / span, 0.0, 1.0)
	return pow(t * t * (3.0 - 2.0 * t), Num.f(cfg["curve"]))


## Whether this time of day has blackouts.
static func blacks_out(time: String) -> bool:
	var cfg: Dictionary = Content.section("escalation")["blackout"]
	var times: Array = cfg["times"]
	return times.has(time)


## The base values of an Environment, sky and sun (empty keys for a missing piece).
static func base_of(env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D) -> Dictionary:
	var out := {}
	if env != null:
		out["fog_density"] = env.fog_density
		out["fog_color"] = env.fog_light_color
		out["ambient_color"] = env.ambient_light_color
	if sky != null:
		out["sky_top"] = sky.sky_top_color
		out["sky_horizon"] = sky.sky_horizon_color
	if sun != null:
		out["sun_energy"] = sun.light_energy
		out["sun_color"] = sun.light_color
	return out


func _process(delta: float) -> void:
	_ease(sim.destruction(), delta)
	if blacks_out(_time):
		_since_scan += delta
		var every := Num.f(Content.section("escalation")["blackout"]["scan_seconds"])
		if _since_scan >= every:
			_since_scan = 0.0
			_scan()
		_spread(delta)


func _ease(destruction: float, delta: float) -> void:
	var goal := amount_of(destruction)
	var before := _amount
	var tau := maxf(0.0001, Num.f(Content.section("escalation")["ease_seconds"]))
	_amount += (goal - _amount) * (1.0 - exp(-delta / tau))
	if absf(goal - _amount) < 0.0005:
		_amount = goal
	if _amount != before:
		_apply(eased(_base, _time, _amount))


func _apply(v: Dictionary) -> void:
	if _env != null and v.has("fog_density"):
		_env.fog_density = Num.f(v["fog_density"])
		_env.fog_light_color = v["fog_color"]
		if _env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR:
			_env.ambient_light_color = v["ambient_color"]
	if _sky != null and v.has("sky_top"):
		_sky.sky_top_color = v["sky_top"]
		_sky.sky_horizon_color = v["sky_horizon"]
		_sky.ground_horizon_color = v["sky_horizon"]
		_sky.ground_bottom_color = v["sky_horizon"]
	if _sun != null and v.has("sun_energy"):
		_sun.light_energy = Num.f(v["sun_energy"])
		_sun.light_color = v["sun_color"]


## The share of a building's chunks gone (0..1).
func damage_of(b: RampageSim.Building) -> float:
	return 1.0 - Num.f(b.frame.alive_count) / Num.f(maxi(1, b.w * b.d * b.height))


## Recomputes how many floors of each building should be dark: the strongest power cut near it.
func _scan() -> void:
	var cfg: Dictionary = Content.section("escalation")["blackout"]
	var reach := Num.f(cfg["radius"]) + Num.f(cfg["radius_per_destruction"]) * sim.destruction()
	var floor_damage := Num.f(cfg["min_damage"])
	var gain := maxf(0.0001, Num.f(cfg["gain"]))
	var hits := PackedVector3Array()  # x, z, damage of every building that cuts power
	for b: RampageSim.Building in sim.buildings:
		var dmg := damage_of(b)
		if dmg >= floor_damage:
			hits.append(Vector3(b.x, b.z, dmg))
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var dark := 0.0
		if b.frame.alive_count > 0 and not hits.is_empty():
			var strength := 0.0
			for h: Vector3 in hits:
				var d := Vector2(b.x - h.x, b.z - h.y).length()
				if d < reach:
					strength = maxf(strength, h.z * (1.0 - d / reach))
			dark = clampf(strength / gain, 0.0, 1.0) * Num.f(b.height)
		if dark != _target[i]:
			_target[i] = dark
			_active[i] = true
		elif _dark[i] > 0.0 and not _active.has(i):  # a view the stream rebuilt gets the dark again
			var v: BuildingView = view_of.call(i)
			if v != null and v.dark_to != _dark[i]:
				v.set_dark_to(_dark[i])


## Moves each active building's dark height toward its target and hands it to the view.
func _spread(delta: float) -> void:
	var step := Num.f(Content.section("escalation")["blackout"]["floors_per_second"]) * delta
	for i: int in _active.keys():
		var now := _dark[i]
		now = move_toward(now, _target[i], step)
		_dark[i] = now
		var v: BuildingView = view_of.call(i)
		if v != null:
			v.set_dark_to(now)
		if now == _target[i] and (v != null or now == 0.0):
			_active.erase(i)
