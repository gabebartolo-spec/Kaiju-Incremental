class_name SkylineRampage
extends Node3D
## Prototype (director 2026-10-21, comments #16: "would be cool if our distant background city
## had a kaiju rampaging in it, and the skyline was on fire"): across the bay a far kaiju
## (FarBeast) walks through the skyline, the towers in its way drop, fires and smoke columns rise
## where they fell and on towers nearby, and faint booms arrive late, as from that far. Off unless
## data/tuning.json "skyline_rampage" "on". Presentation only: the scene is a pure function of
## the elapsed time and the run's seeded stream (jump_to), so a capture can show any moment.

const SKYLINE_SALT := 16  # the far rampage's stream, drawn from the run's fx seed
const FIRE_SHADER := preload("res://scenes/horizon_fire.gdshader")
const SMOKE_SHADER := preload("res://scenes/horizon_smoke.gdshader")
const BOOM := "res://assets/sfx/collapse.ogg"  # loaded when heard: a fresh import has no .ogg yet
const THUD := "res://assets/sfx/stomp_0.ogg"
const TILT := 0.5  # a falling tower's lean at the end of its fall (radians)
const TURN_SHARE := 0.35  # below this share of full speed the beast turns to face the bay
const VOICES := 4
const START_SPREAD := 0.35  # share of its swing the beast may be off centre at the start
const REF_DIST := 100.0  # sounds play at their dB this far away
const WASH := Vector2(5.0, 3.0)  # a fire's warm wash on the haze, in fire sizes
const FLAME_POWER := 1.6
const PUFF := 9.0  # a smoke puff's size at the foot of its column
const KIND_FLAME := 0.0
const KIND_WASH := 1.0
const KIND_SMOKE := 0.0
const KIND_DUST := 1.0

## Seconds into the far rampage (it began before the player's run did: cfg "start_s").
var elapsed := 0.0
var _cfg: Dictionary
var _skyline: CitySkyline
var _rng: RandomNumberGenerator
var _beast: FarBeast
var _boxes: Array[Dictionary] = []
var _far_mm: MultiMesh
## Tower falls by time: index, crowns, at (s), dir (+-1 along x), smash (the beast's own blow).
var _falls: Array[Dictionary] = []
var _fires: Array[Dictionary] = []  # pos, size, start, strength
var _fire_mm: MultiMesh
var _fire_mat: ShaderMaterial
var _smoke_mat: ShaderMaterial
var _phase0 := 0.0
var _omega := 0.0
var _path_z := 0.0
var _pending: Array[Dictionary] = []  # sounds on their way: at (s), stream, db, pitch
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _next_fall := 0


## Adds the far skyline to `parent`, and the far insectoid rampaging across it when tuning
## skyline_rampage.on says so (its stream is drawn from the run's fx seed `rng`).
static func attach(parent: Node, skyline: CitySkyline, rng: RandomNumberGenerator) -> void:
	parent.add_child(skyline)
	if Content.section("skyline_rampage").get("on", false):
		parent.add_child(SkylineRampage.new(skyline, Seeds.derive(rng, SKYLINE_SALT)))


func _init(skyline: CitySkyline, rng: RandomNumberGenerator) -> void:
	_skyline = skyline
	_rng = rng
	_cfg = Content.section("skyline_rampage")


func _ready() -> void:
	_boxes = _skyline.far_boxes()
	_far_mm = _skyline.far_view.multimesh
	_omega = _f("speed") / _f("swing")
	# At the run's start it is mid-skyline (within START_SPREAD of the centre), heading either way.
	var u := asin(_rng.randf_range(-START_SPREAD, START_SPREAD))
	_phase0 = (u if _rng.randf() < 0.5 else PI - u) - _omega * _f("start_s")
	_path_z = _skyline.ground.coast - Num.f(_skyline.cfg["bay_width"]) - _f("path_depth")
	var haze := Num.f(_skyline.cfg["far_haze"])
	_beast = FarBeast.new(_cfg, haze)
	add_child(_beast)
	_beast.foot_planted.connect(_footfall)
	var plan := SkylineRampagePlan.new(_cfg, _boxes, _rng)
	plan.build(_path_z, beast_x)
	_falls = plan.falls
	_fires = plan.fires
	_build_lights(haze)
	_build_smoke(haze)
	for _i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	jump_to(_f("start_s"))


func _process(delta: float) -> void:
	elapsed += delta
	_apply()
	_walk(delta)
	_hear()


## Shows the far rampage `seconds` in, silently (captures; the run's start).
func jump_to(seconds: float) -> void:
	elapsed = seconds
	_next_fall = 0
	while _next_fall < _falls.size() and Num.f(_falls[_next_fall]["at"]) <= elapsed:
		_next_fall += 1
	_pending.clear()
	_apply()
	_walk(0.0)


## The beast's x along its path at time t (it paces the skyline, slowing to turn at each end).
func beast_x(t: float) -> float:
	return _f("centre_x") + _f("swing") * sin(_omega * t + _phase0)


## Where the beast's feet are now.
func beast_at() -> Vector3:
	return Vector3(beast_x(elapsed), SkylineRampagePlan.GROUND_Y, _path_z)


## How many towers have dropped by now (captures and tests).
func fallen() -> int:
	var n := 0
	for fall: Dictionary in _falls:
		if Num.f(fall["at"]) + _f("fall_s") <= elapsed:
			n += 1
	return n


func _f(key: String) -> float:
	return Num.f(_cfg[key])


func _velocity(t: float) -> float:
	return _f("speed") * cos(_omega * t + _phase0)


func _build_lights(haze: float) -> void:
	_fire_mat = ShaderMaterial.new()
	_fire_mat.shader = FIRE_SHADER
	_fire_mat.set_shader_parameter("haze", haze)
	var fire := Color(str(_cfg["fire"]))
	_fire_mm = _billboards(_fire_mat, _fires.size() * 2)
	for n: int in _fires.size():
		var spot: Dictionary = _fires[n]
		var pos: Vector3 = spot["pos"]
		var w := Num.f(spot["size"])
		var start := Num.f(spot["start"])
		var seed := _rng.randf()
		_fire_mm.set_instance_transform(
			2 * n, Transform3D(Basis.from_scale(Vector3(w, w * 1.3, 1)), pos)
		)
		_fire_mm.set_instance_color(2 * n, fire)
		_fire_mm.set_instance_custom_data(2 * n, Color(seed, start, KIND_FLAME, FLAME_POWER))
		var wash := Transform3D(
			Basis.from_scale(Vector3(w * WASH.x, w * WASH.y, 1)), pos + Vector3(0, w, 0)
		)
		_fire_mm.set_instance_transform(2 * n + 1, wash)
		_fire_mm.set_instance_color(2 * n + 1, fire)
		_fire_mm.set_instance_custom_data(2 * n + 1, Color(seed, start, KIND_WASH, 0.5))


func _build_smoke(haze: float) -> void:
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = SMOKE_SHADER
	_smoke_mat.set_shader_parameter("haze", haze)
	_smoke_mat.set_shader_parameter("height", _f("smoke_height"))
	_smoke_mat.set_shader_parameter("haze_color", Look.color("fog_color"))
	_smoke_mat.set_shader_parameter("smoke_color", Color(str(_cfg["smoke"])))
	_smoke_mat.set_shader_parameter("ember_color", Color(str(_cfg["fire"])))
	var puffs := Num.i(_cfg["puffs"])
	var dusts := 0
	for spot: Dictionary in _fires:
		dusts += 1 if spot["dust"] else 0
	var mm := _billboards(_smoke_mat, (_fires.size() + dusts) * puffs)
	var slot := 0
	for spot: Dictionary in _fires:
		var pos: Vector3 = spot["pos"]
		var w := Num.f(spot["size"])
		for k: int in puffs:
			var custom := Color(float(k) / puffs, Num.f(spot["start"]), KIND_SMOKE, _rng.randf())
			mm.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ONE * PUFF), pos))
			mm.set_instance_custom_data(slot, custom)
			slot += 1
		if spot["dust"]:
			for k: int in puffs:
				var custom := Color(_rng.randf(), Num.f(spot["fall"]), KIND_DUST, _rng.randf())
				var base := Transform3D(Basis.from_scale(Vector3.ONE * w * 1.2), pos)
				mm.set_instance_transform(slot, base)
				mm.set_instance_custom_data(slot, custom)
				slot += 1


func _billboards(mat: ShaderMaterial, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-2000, -10, -2000), Vector3(4000, 400, 4000))  # moved in the shader
	add_child(mmi)
	return mm


func _apply() -> void:
	var t := elapsed
	for fall: Dictionary in _falls:
		_draw_tower(fall, t)
	_fire_mat.set_shader_parameter("now", t)
	_smoke_mat.set_shader_parameter("now", t)


## The beast walks its path; it turns to face the bay where it slows at each end.
func _walk(delta: float) -> void:
	var v := _velocity(elapsed)
	var yaw := PI + PI * 0.5 * clampf(v / (TURN_SHARE * _f("speed")), -1.0, 1.0)
	_beast.walk(delta, beast_at(), yaw, _ear())


func _ear() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return camera.global_position if camera != null else Vector3.ZERO


func _footfall(_side: String, _strength: float, at: Vector3) -> void:
	_send(load(THUD) as AudioStream, at, _ear(), _f("step_db"))


## A tower in its fall: it sinks into its own footprint, leaning away from the blow.
func _draw_tower(fall: Dictionary, t: float) -> void:
	var p := clampf((t - Num.f(fall["at"])) / _f("fall_s"), -1.0, 2.0)
	if p < 0.0:
		p = -1.0
	elif p >= 1.0:
		p = 2.0
	if p == Num.f(fall["drawn"]) and (p < 0.0 or p > 1.0):
		return  # standing or gone: nothing moves
	fall["drawn"] = p
	var index := Num.i(fall["index"])
	var size: Vector3 = _boxes[index]["size"]
	var at: Vector3 = _boxes[index]["at"]
	var base := Vector3(at.x, at.y - size.y * 0.5, at.z)
	var parts: Array[int] = [index]
	for crown: Variant in fall["crowns"]:
		parts.append(Num.i(crown))
	for part: int in parts:
		var box: Dictionary = _boxes[part]
		var box_size: Vector3 = box["size"]
		var box_at: Vector3 = box["at"]
		if p > 1.0:  # gone: folded away under the ground
			_far_mm.set_instance_transform(
				part, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), base - Vector3(0, 50, 0))
			)
			continue
		var q := maxf(p, 0.0)
		var lean := Basis(Vector3.BACK, -TILT * q * q * Num.f(fall["dir"]))
		var frame := Transform3D(lean, base - Vector3(0, size.y * q * q, 0))
		_far_mm.set_instance_transform(
			part, frame * Transform3D(Basis.from_scale(box_size), box_at - base)
		)


## Footfalls and collapses reach the camera at the speed of sound, faint with distance.
func _hear() -> void:
	var ear := _ear()
	while _next_fall < _falls.size() and Num.f(_falls[_next_fall]["at"]) <= elapsed:
		var at: Vector3 = _boxes[Num.i(_falls[_next_fall]["index"])]["at"]
		_send(load(BOOM) as AudioStream, at, ear, _f("boom_db"))
		if _falls[_next_fall]["smash"]:
			_beast.stomp()
		_next_fall += 1
	while not _pending.is_empty() and Num.f(_pending[0]["at"]) <= elapsed:
		var sound: Dictionary = _pending.pop_front()
		var player := _players[_next_voice]
		_next_voice = (_next_voice + 1) % _players.size()
		player.stream = sound["stream"]
		player.volume_db = Num.f(sound["db"])
		player.pitch_scale = _f("boom_pitch")
		player.play()


func _send(stream: AudioStream, from: Vector3, ear: Vector3, db: float) -> void:
	var dist := maxf(from.distance_to(ear), REF_DIST)
	var sound := {
		"at": elapsed + dist / _f("sound_speed"),
		"stream": stream,
		"db": db - 20.0 * log(dist / REF_DIST) / log(10.0)
	}
	_pending.append(sound)
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
