class_name BlastFx
extends Node3D
## How the city's red barrels go off (director comments #19, #20: "really good sfx and vfx for
## the explosions including shockwaves and sonicboom"). Rampage hands it the sim's explosives
## events; it never decides an outcome. hazard_armed: the site's warning lamp blinks, sparks spit
## off the roof and gas hisses while the fuse burns. explosion: a white core, a fireball of
## glowing voxels, a dust shock racing out over the street, a shell of bent air, a flash of real
## light, debris in the site's colours, smoke and a fire left burning; the camera shakes by
## distance (trauma squared, capped) and the blast is heard as crack + body + rumble, with the
## sonic boom arriving later the further the camera is (speed of sound scaled to the map).
## firework_burst: a coloured shell bursting over the point it hits. toxic_cloud: a green cloud
## for as long as the sim keeps it. Looks and timings: data/tuning.json "blast_fx".

## Blasts drawn so far, by kind (read by the flow suite and the capture).
var drawn: Dictionary = {}
## The sonic booms waiting for their sound to arrive: [seconds left, where].
var booms: Array[Array] = []
var _cfg: Dictionary
var _city: CityView
var _sfx: Sfx
var _sim: RampageSim
var _rng: RandomNumberGenerator
var _trauma := 0.0
var _flashes := 0
## Armed sites' blinking lamps: building index -> [node, seconds left].
var _fuses: Dictionary = {}
var _spark_clock := 0.0


func _init(sim: RampageSim, city: CityView, sfx: Sfx, rng: RandomNumberGenerator) -> void:
	_sim = sim
	_city = city
	_sfx = sfx
	_rng = rng
	_cfg = Content.section("blast_fx")


func _ready() -> void:
	# Prewarm: one of each, out of sight, so the first real blast does not stall a frame.
	var under := Vector3(0, -60, 0)
	BlastParts.fireball(self, under, 1.0, _c("fireball"))
	BlastParts.core(self, under, 1.0, _c("core"))
	BlastParts.smoke(self, under, 1.0, _c("smoke"))
	BlastParts.ground_shock(self, under, 1.0, _c("shock"))
	BlastParts.haze(self, under, 1.0, _c("haze"))
	BlastParts.firework(self, under, Color.WHITE, _c("fireworks"))
	BlastParts.toxic_cloud(self, under, 1.0, 0.2, _c("cloud"))


## Camera shake now, in units of aim jitter: trauma squared, so small blasts barely nudge and big
## ones slam, capped at shake.max.
func shake() -> float:
	var s: Dictionary = _c("shake")
	return minf(Num.f(s["max"]), _trauma * _trauma) * Num.f(s["amplitude"])


## Takes the explosives' events; false for any other event.
func on_event(event: Dictionary, focus: Vector3) -> bool:
	match str(event["type"]):
		"hazard_armed":
			_arm(Num.i(event["building"]), Num.f(event["fuse"]))
		"explosion":
			_explode(str(event["kind"]), _at(event), Num.f(event["radius"]), focus)
		"firework_burst":
			_burst(_at(event), focus)
		"toxic_cloud":
			var at := _at(event)
			BlastParts.toxic_cloud(
				self, at, Num.f(event["radius"]), Num.f(event["seconds"]), _c("cloud")
			)
			_sfx.play_at("chem_hiss", at)
		_:
			return false
	return true


func _process(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * Num.f(_c("shake")["decay_per_s"]))
	var left: Array[Array] = []
	for boom: Array in booms:
		boom[0] = Num.f(boom[0]) - delta
		if Num.f(boom[0]) > 0.0:
			left.append(boom)
		else:
			var where: Vector3 = boom[1]
			_sfx.play_at("sonic_boom", where)
	booms = left
	_blink(delta)


func _c(key: String) -> Dictionary:
	var section: Dictionary = _cfg[key]
	return section


func _at(event: Dictionary) -> Vector3:
	return Vector3(Num.f(event["x"]), 0.0, Num.f(event["z"]))


## The fuse burns: the site's lamp blinks fast and its roof spits sparks until it blows.
func _arm(index: int, fuse: float) -> void:
	var b := _sim.buildings[index]
	var lamp := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * Num.f(_c("fuse")["lamp_size"])
	cube.material = CityView.glow(Color(str(_c("fuse")["color"])), 6.0)
	lamp.mesh = cube
	lamp.position = Vector3(b.x, b.height + 0.8, b.z)
	add_child(lamp)
	_fuses[index] = [lamp, fuse]
	_sfx.play_at("chem_hiss", lamp.position)


func _blink(delta: float) -> void:
	if _fuses.is_empty():
		return
	var hz := Num.f(_c("fuse")["blink_hz"])
	_spark_clock -= delta
	var spark := _spark_clock <= 0.0
	if spark:
		_spark_clock = Num.f(_c("fuse")["spark_every_s"])
	for index: int in _fuses.keys():
		var fuse: Array = _fuses[index]
		var lamp: MeshInstance3D = fuse[0]
		fuse[1] = Num.f(fuse[1]) - delta
		if Num.f(fuse[1]) <= 0.0:
			lamp.queue_free()
			_fuses.erase(index)
			continue
		lamp.visible = fmod(Num.f(fuse[1]) * hz, 1.0) < 0.5
		if spark:
			_city.fx.sparks(lamp.position)


## One site going up (the sim's explosion event): everything at once, sized by its radius.
func _explode(kind: String, at: Vector3, radius: float, focus: Vector3) -> void:
	drawn[kind] = Num.i(drawn.get(kind, 0)) + 1
	var high := at + Vector3(0, radius * 0.5, 0)
	BlastParts.core(self, high, radius, _c("core"))
	BlastParts.fireball(self, high, radius, _c("fireball"))
	BlastParts.ground_shock(self, at, radius, _c("shock"))
	BlastParts.haze(self, high, radius, _c("haze"))
	BlastParts.smoke(self, high, radius, _c("smoke"))
	var tint := Color(str(_c("flash")["chem_color" if kind == "chem_lab" else "color"]))
	_flash(high, tint, Num.f(_c("flash")["energy"]) * radius / 5.0)
	var colours: Array = _c("debris_colors")[kind]
	for n: int in Num.i(_cfg["debris"]):
		var away := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(0.6, 1.4), _rng.randf_range(-1, 1)
		)
		_city.debris(high, Color(str(colours[n % colours.size()])), away)
	_city.fire(at, Num.f(_cfg["fire_size"]) * radius / 5.0)
	var trauma: Dictionary = _c("shake")["trauma"]
	_add_trauma(Num.f(trauma[kind]), at, focus)
	_sound(kind, at)


## Crack (only near), body and rumble now; the sonic boom when the air carries it to the camera.
func _sound(kind: String, at: Vector3) -> void:
	var s: Dictionary = _c("sound")
	var ear := _sfx.listener.global_position if is_instance_valid(_sfx.listener) else at
	var far := ear.distance_to(at)
	var small := 0.0 if kind == "fuel_silo" else Num.f(s["small_db"])
	if far <= Num.f(s["crack_within"]):
		_sfx.play_at("blast_crack", at, small)
	_sfx.play_at("blast_body", at, small)
	_sfx.play_at("blast_rumble", at, small)
	if far >= Num.f(s["boom_from"]):
		booms.append([minf(Num.f(s["boom_max_delay"]), far / Num.f(s["speed"])), at])


func _burst(at: Vector3, focus: Vector3) -> void:
	drawn["firework_burst"] = Num.i(drawn.get("firework_burst", 0)) + 1
	var cfg: Dictionary = _c("fireworks")
	var colours: Array = cfg["colors"]
	var colour := Color(str(colours[_rng.randi_range(0, colours.size() - 1)]))
	var up := Vector3(0, Num.f(cfg["height"]) * _rng.randf_range(0.7, 1.2), 0)
	BlastParts.firework(self, at + up, colour, cfg)
	_flash(at + up, colour, Num.f(cfg["flash_energy"]))
	_city.fire(at, Num.f(cfg["fire_size"]))
	_add_trauma(Num.f(cfg["trauma"]), at, focus)
	_sfx.play_at("fireworks_crackle", at)


## The one place a blast shakes the camera: `amount` of trauma, less the further `at` is from the
## kaiju (`focus`), none past shake.reach.
func _add_trauma(amount: float, at: Vector3, focus: Vector3) -> void:
	var near := 1.0 - clampf(at.distance_to(focus) / Num.f(_c("shake")["reach"]), 0.0, 1.0)
	_trauma = minf(1.0, _trauma + amount * near)


## A burst of real light, at most flash.max_live at once: the city's lamps and fires already take
## lights.pool_size of the renderer's lights (LightPool), and this keeps the rest in budget.
func _flash(at: Vector3, color: Color, energy: float) -> void:
	if _flashes >= Num.i(_c("flash")["max_live"]):
		return
	_flashes += 1
	var seconds := Num.f(_c("flash")["seconds"])
	_city.flash(at, color, energy, seconds)
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _flashes -= 1)
