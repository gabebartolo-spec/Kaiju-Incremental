class_name BlastFx
extends Node3D
## How the city's red barrels go off (director comments #19, #20: "really good sfx and vfx for
## the explosions including shockwaves and sonicboom"). Rampage hands it the sim's explosives
## events; it never decides an outcome. hazard_armed: the site's warning lamp blinks, sparks spit
## off the roof and gas hisses while the fuse burns. explosion: a white core and a sudden tall
## burst of the game's own flames out of the site's own box (director 2026-10-22, D-151:
## "consistency is absolutely key"; BlastParts.fireball is Fire's flame exactly), the game's dust
## shockwave and
## puffs along the street (BlastShock), the site blowing apart top first, its pieces thrown out and
## up (BlastBreak), a flash of real light, and then the game's own Fire left burning at the site
## with its light and smoke. The screen never flashes white (director 2026-10-27, "Cut") and the
## camera takes one kick, away from the blast and decaying over a few frames (jitter), no shaking
## back and forth and no hit-stop (clip critic round 6); the blast is heard as one crack (at any
## distance) with a body and rumble under it, and the sonic boom arriving later the further the
## camera is (speed of sound scaled to the map).
## firework_burst: a coloured shell bursting over the point it hits. toxic_cloud: a billow of
## the game's soft smoke tinted green, then a thin haze for as long as the sim keeps the
## cloud. Looks and timings: data/tuning.json "blast_fx" (motion critic fix round 2026-10-21).

## Blasts drawn so far, by kind (read by the flow suite and the capture).
var drawn: Dictionary = {}
## The sonic booms on their way to the camera: [seconds left, where].
var booms: Array[Array] = []
## Frames the camera was kicked and the biggest kick (aim units), for captures.
var kicked := 0
var kick_peak := 0.0
var _cfg: Dictionary
var _city: CityView
var _sfx: Sfx
var _sim: RampageSim
var _rng: RandomNumberGenerator
var _kick := Vector3.ZERO  # the camera's aim offset at the start of the kick (world units)
var _kick_left := 0.0  # seconds of the kick left; it fades as the square of that share
var _flashes := 0
## Armed sites' blinking lamps: building index -> [node, seconds left].
var _fuses: Dictionary = {}
var _spark_clock := 0.0


## A BlastFx built and added under `parent` (Rampage).
static func attach(
	parent: Node, sim: RampageSim, city: CityView, sfx: Sfx, rng: RandomNumberGenerator
) -> BlastFx:
	var fx := BlastFx.new(sim, city, sfx, rng)
	parent.add_child(fx)
	return fx


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
	BlastParts.firework(self, under, Color.WHITE, _c("fireworks"))
	BlastParts.toxic_cloud(self, under, Vector3.ONE, 1.0, 0.2, _c("cloud"))


## The camera's aim offset this frame (world units): one kick, away from the blast, easing out
## over kick.seconds, zero when nothing kicks it.
func jitter() -> Vector3:
	var now := _kick_offset()
	if now != Vector3.ZERO:
		kicked += 1
		kick_peak = maxf(kick_peak, now.length())
	return now


func _kick_offset() -> Vector3:
	if _kick_left <= 0.0:
		return Vector3.ZERO
	var share := _kick_left / Num.f(_c("kick")["seconds"])
	return _kick * share * share


## Takes the explosives' events; false for any other event.
func on_event(event: Dictionary, focus: Vector3) -> bool:
	match str(event["type"]):
		"hazard_armed":
			_arm(Num.i(event["building"]), Num.f(event["fuse"]))
		"explosion":
			_explode(str(event["kind"]), event, focus)
		"airstrike_bomb":
			_bomb(event, focus)
		"firework_burst":
			_burst(_at(event))
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
	_kick_left = maxf(0.0, _kick_left - delta)
	var left: Array[Array] = []
	for boom: Array in booms:
		boom[0] = Num.f(boom[0]) - delta
		if Num.f(boom[0]) > 0.0:
			left.append(boom)
			continue
		var where: Vector3 = boom[1]
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
	BlastShock.ground(_city.fx, at, reach, _c("shock"))
	_city.blast_break.blew(at, reach)
	var burn: Dictionary = _c("fire")  # what is left burning is the game's own Fire, with its smoke
	_city.fire(Vector3(at.x, 0.0, at.z), Num.f(burn["size"]) * radius / 5.0, Num.f(burn["seconds"]))
	var tint := Color(str(_c("flash")["chem_color" if kind == "chem_lab" else "color"]))
	_flash(high, tint, Num.f(_c("flash")["energy"]) * radius / 5.0)
	_throw(kind, high, half)
	var trauma: Dictionary = _c("shake")["trauma"]
	_add_kick(Num.f(trauma[kind]), at, focus)
	_sound(kind, at)


## A bomb from the time's-up jet run (FinalStrike): the barrels' blast on open ground, no site of
## its own, so the burst is a radius-wide box on the street; trauma kind "airstrike".
func _bomb(event: Dictionary, focus: Vector3) -> void:
	drawn["airstrike"] = Num.i(drawn.get("airstrike", 0)) + 1
	var radius := Num.f(event["radius"])
	var at := _at(event)
	var half := Vector3(radius, radius, radius) * 0.5
	var high := at + Vector3(0, half.y, 0)
	BlastParts.core(self, high, half, radius, _c("core"))
	BlastParts.fireball(self, high, half, radius, _c("fireball"))
	var reach := BlastShock.reach(radius * 2.0, radius, _c("shock"))
	BlastShock.ground(_city.fx, at, reach, _c("shock"))
	_city.blast_break.blew(at, reach)
	var fire: Dictionary = _c("fire")
	# In the bay the fire fizzles out at once (director 2026-10-31: no fire survives the water).
	var wet := _sim.emerge.wet(Vector2(at.x, at.z))
	var burn := Num.f(fire["water_seconds"]) if wet else Num.f(fire["seconds"])
	_city.fire(at, Num.f(fire["size"]) * radius / 5.0, burn)
	_flash(high, Color(str(_c("flash")["color"])), Num.f(_c("flash")["energy"]) * radius / 5.0)
	_add_kick(Num.f(_c("shake")["trauma"]["airstrike"]), at, focus)
	_sound("fuel_silo", at)


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
	_sfx.play("blast_crack", Num.f(s["crack_db"]))  # each blast's one hit, loud at any distance
	_sfx.play_at("blast_body", at, small + Num.f(s["tail_db"]))
	_sfx.play_at("blast_rumble", at, small + Num.f(s["tail_db"]))
	if far >= Num.f(s["boom_from"]):
		booms.append([minf(Num.f(s["boom_max_delay"]), far / Num.f(s["speed"])), at])


func _burst(at: Vector3) -> void:
	drawn["firework_burst"] = Num.i(drawn.get("firework_burst", 0)) + 1
	var cfg: Dictionary = _c("fireworks")
	var colours: Array = cfg["colors"]
	var colour := Color(str(colours[_rng.randi_range(0, colours.size() - 1)]))
	var up := Vector3(0, Num.f(cfg["height"]) * _rng.randf_range(0.7, 1.2), 0)
	BlastParts.firework(self, at + up, colour, cfg)
	_flash(at + up, colour, Num.f(cfg["flash_energy"]))
	_city.fire(at, Num.f(cfg["fire_size"]))
	_sfx.play_at("fireworks_crackle", at)


## The one place a blast kicks the camera: `amount` of kick (kick.units each), less the further
## `at` is from the kaiju (`focus`), none past shake.reach; the aim is thrown up and away from the
## blast. A second blast inside a kick adds to what is left of it.
func _add_kick(amount: float, at: Vector3, focus: Vector3) -> void:
	var near := 1.0 - clampf(at.distance_to(focus) / Num.f(_c("shake")["reach"]), 0.0, 1.0)
	var away := Vector3(focus.x - at.x, 0.0, focus.z - at.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	var dir := (Vector3.UP * 0.9 + away * 0.4).normalized()
	var kick: Dictionary = _c("kick")
	_kick = _kick_offset() + dir * Num.f(kick["units"]) * amount * near
	_kick_left = Num.f(kick["seconds"]) if near > 0.0 else _kick_left


## A burst of real light, at most flash.max_live at once: the city's lamps and fires already take
## lights.pool_size of the renderer's lights (LightPool), and this keeps the rest in budget.
func _flash(at: Vector3, color: Color, energy: float) -> void:
	if _flashes >= Num.i(_c("flash")["max_live"]):
		return
	_flashes += 1
	var seconds := Num.f(_c("flash")["seconds"])
	_city.flash(at, color, energy, seconds)
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _flashes -= 1)
