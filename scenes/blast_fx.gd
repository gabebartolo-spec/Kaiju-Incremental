class_name BlastFx
extends Node3D
## How the city's red barrels go off (director comments #19, #20: "really good sfx and vfx for
## the explosions including shockwaves and sonicboom"). Rampage hands it the sim's explosives
## events; it never decides an outcome. hazard_armed: the site's warning lamp blinks, sparks spit
## off the roof and gas hisses while the fuse burns. explosion: a white core, a fireball of
## glowing voxels, both out of the site's own box; a ring of voxel chunks and dust racing out
## along the street (BlastShock); the site blowing apart top first, its pieces thrown out and up
## (BlastBreak); a flash of real light and lit smoke cubes (no city fire: its soft smoke column
## sheeted over the facades, motion critic round 5). The camera kicks on the
## flash and shakes by distance (trauma squared, capped), the sim holds still a moment
## (hit_stop: a few steps skipped, never Engine.time_scale), and the blast is heard as crack +
## body + rumble, with the sonic boom arriving later the further the camera is (speed of sound
## scaled to the map) and the screen rippling out from the blast as it does.
## firework_burst: a coloured shell bursting over the point it hits. toxic_cloud: a billow of
## green voxels, then a thin haze for as long as the sim keeps the cloud. Looks and timings:
## data/tuning.json "blast_fx" (motion critic fix round 2026-10-21).

## Blasts drawn so far, by kind (read by the flow suite and the capture).
var drawn: Dictionary = {}
## The sonic booms on their way to the camera: [seconds left, where, heard (a sound as well)].
var booms: Array[Array] = []
## Hit-stops so far (captures).
var holds := 0
var _cfg: Dictionary
var _city: CityView
var _sfx: Sfx
var _sim: RampageSim
var _rng: RandomNumberGenerator
var _trauma := 0.0
var _kick := 0.0  # the flash's own shake, in trauma-squared units, gone over kick.seconds
var _hold := 0.0  # seconds of sim still to skip
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
	_city.blast_break = BlastBreak.new(city, rng, _c("break"))
	add_child(_city.blast_break)


func _ready() -> void:
	# Prewarm: one of each, out of sight, so the first real blast does not stall a frame.
	var under := Vector3(0, -60, 0)
	BlastParts.fireball(self, under, Vector3.ONE, 1.0, _c("fireball"))
	BlastParts.core(self, under, Vector3.ONE, 1.0, _c("core"))
	BlastParts.smoke(self, under, 1.0, _c("smoke"))
	BlastShock.ground(self, under, 1.0, _c("shock"))
	BlastParts.firework(self, under, Color.WHITE, _c("fireworks"))
	BlastParts.toxic_cloud(self, under, Vector3.ONE, 1.0, 0.2, _c("cloud"))


## Camera shake now, in units of aim jitter: trauma squared, so small blasts barely nudge and big
## ones slam, capped at shake.max; the flash's kick on top of it for its first instant.
func shake() -> float:
	var s: Dictionary = _c("shake")
	return maxf(minf(Num.f(s["max"]), _trauma * _trauma), _kick) * Num.f(s["amplitude"])


## Hit-stop: true while a blast holds the sim still (Rampage skips that step); counts down by
## the step it skipped.
func hold(delta: float) -> bool:
	if _hold <= 0.0:
		return false
	_hold -= delta
	return true


## Takes the explosives' events; false for any other event.
func on_event(event: Dictionary, focus: Vector3) -> bool:
	match str(event["type"]):
		"hazard_armed":
			_arm(Num.i(event["building"]), Num.f(event["fuse"]))
		"explosion":
			_explode(str(event["kind"]), event, focus)
		"firework_burst":
			_burst(_at(event), focus)
		"toxic_cloud":
			var box := _site(event)
			var at: Vector3 = box[0]
			var half: Vector3 = box[1]
			var radius := Num.f(event["radius"])
			var seconds := Num.f(event["seconds"])
			BlastParts.toxic_cloud(self, at, half, radius, seconds, _c("cloud"))
			_sfx.play_at("chem_hiss", at)
		_:
			return false
	return true


func _process(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * Num.f(_c("shake")["decay_per_s"]))
	var kick: Dictionary = _c("kick")
	_kick = maxf(0.0, _kick - delta * Num.f(kick["amount"]) / Num.f(kick["seconds"]))
	var left: Array[Array] = []
	for boom: Array in booms:
		boom[0] = Num.f(boom[0]) - delta
		if Num.f(boom[0]) > 0.0:
			left.append(boom)
			continue
		var where: Vector3 = boom[1]
		BlastShock.ripple(self, where, _c("ripple"))
		if boom[2]:
			_sfx.play_at("sonic_boom", where)
	booms = left
	_blink(delta)


func _c(key: String) -> Dictionary:
	var section: Dictionary = _cfg[key]
	return section


func _at(event: Dictionary) -> Vector3:
	return Vector3(Num.f(event["x"]), 0.0, Num.f(event["z"]))


## The site's box as it stands now: [centre, half extents]. A site already knocked flat blows
## out of its rubble (site_rubble high), never out of thin air.
func _site(event: Dictionary) -> Array:
	var b := _sim.buildings[Num.i(event["building"])]
	var high := float(b.height) if b.frame.alive_count > 0 else Num.f(_cfg["site_rubble"])
	var half := Vector3(b.w, high, b.d) * 0.5
	return [Vector3(b.x, half.y, b.z), half]


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


## One site going up (the sim's explosion event): everything at once, out of the site's box,
## sized by the blast's radius.
func _explode(kind: String, event: Dictionary, focus: Vector3) -> void:
	drawn[kind] = Num.i(drawn.get(kind, 0)) + 1
	var radius := Num.f(event["radius"])
	var at := _at(event)
	var box := _site(event)
	var high: Vector3 = box[0]
	var half: Vector3 = box[1]
	BlastParts.core(self, high, half, radius, _c("core"))
	BlastParts.fireball(self, high, half, radius, _c("fireball"))
	var reach := BlastShock.reach(maxf(half.x, half.z) * 2.0, radius, _c("shock"))
	BlastShock.ground(self, at, reach, _c("shock"))
	_city.blast_break.blew(at, reach)
	BlastParts.smoke(self, high, radius, _c("smoke"))
	var tint := Color(str(_c("flash")["chem_color" if kind == "chem_lab" else "color"]))
	_flash(high, tint, Num.f(_c("flash")["energy"]) * radius / 5.0)
	_throw(kind, high, half)
	var trauma: Dictionary = _c("shake")["trauma"]
	var near := _add_trauma(Num.f(trauma[kind]), at, focus)
	_kick = maxf(_kick, Num.f(_c("kick")["amount"]) * near)
	if near > 0.0:
		_hold = maxf(_hold, Num.f(_cfg["hit_stop"]))
		holds += 1
	_sound(kind, at)


## The site's skin thrown out of its whole box, outward and up, in its own colours: the first
## pieces off, before its broken floors (BlastBreak) follow.
func _throw(kind: String, centre: Vector3, half: Vector3) -> void:
	var colours: Array = _c("debris_colors")[kind]
	var push := Num.f(_c("break")["push"])
	var up := Num.f(_c("break")["up"])
	for n: int in Num.i(_cfg["debris"]):
		var spot := Vector3(_rng.randf_range(-1, 1), _rng.randf(), _rng.randf_range(-1, 1))
		var p := centre + half * spot
		var out := Vector3(spot.x, 0.0, spot.z).normalized()
		var away := out * push + Vector3.UP * up * _rng.randf_range(0.8, 1.4)
		_city.debris(p, Color(str(colours[n % colours.size()])), away)


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
	var heard := far >= Num.f(s["boom_from"])
	booms.append([minf(Num.f(s["boom_max_delay"]), far / Num.f(s["speed"])), at, heard])


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
## kaiju (`focus`), none past shake.reach. Returns that nearness (0..1).
func _add_trauma(amount: float, at: Vector3, focus: Vector3) -> float:
	var near := 1.0 - clampf(at.distance_to(focus) / Num.f(_c("shake")["reach"]), 0.0, 1.0)
	_trauma = minf(1.0, _trauma + amount * near)
	return near


## A burst of real light, at most flash.max_live at once: the city's lamps and fires already take
## lights.pool_size of the renderer's lights (LightPool), and this keeps the rest in budget.
func _flash(at: Vector3, color: Color, energy: float) -> void:
	if _flashes >= Num.i(_c("flash")["max_live"]):
		return
	_flashes += 1
	var seconds := Num.f(_c("flash")["seconds"])
	_city.flash(at, color, energy, seconds)
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _flashes -= 1)
