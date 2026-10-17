class_name RooftopView
extends Node3D
## Rooftop defenders (D-063), presentation only: the sim's rooftop squads drawn as armed citizens
## and soldiers standing on their roofs, turned to the kaiju, rifles up. Each sim volley flashes
## at every muzzle of the squad, sends a bright tracer at the kaiju's hide and sparks where it
## strikes. Flashes, tracers and sparks are unshaded and additive and ignore the fog, so a volley
## reads at the game camera from across the city. Everything is a MultiMesh pool, so a volley
## creates no nodes. At most army.rooftop.max_drawn figures are drawn (street life already costs
## milliseconds a frame); they stand FIGURE_SCALE times a street person, to read as a group.

const MAX_FLASHES := 96
const MAX_TRACERS := 48
const FLASH_SECONDS := 0.08
const FLASH_SIZE := 0.35  # world units, a soft star facing the camera
const FLASH_AHEAD := 0.2  # the star burns this far out along the aim, clear of the shooter
const FLASH_STAGGER := 1.0 / 60.0  # each rifle of a squad fires this much after the one before
const SPARK_SIZE := 0.5
const STAR_PIXELS := 32
const SPARK_SECONDS := 0.1
const GLOW := Color(1.0, 0.82, 0.45)
## Over-range brightness per instance, past the city's glow threshold (1.1, AgX tonemap), so
## flashes, tracers and sparks bloom instead of reading as tan sticks.
const HOT := Color(4.0, 4.0, 4.0)
const TRACER_SPEED := 60.0  # world units a second, muzzle to hide
const TRACER_LENGTH := 1.75  # a tracer is a short streak this long, flying the whole way
const TRACER_WIDTH := 0.05
## A tracer burns less over-range than a flash: a thin core with a soft glow, not a white rod.
const TRACER_HOT := Color(2.0, 2.0, 2.0)
const FIGURE_SCALE := 1.5
const SPACING := 0.55  # figures of a squad stand this far apart across their line of fire
const AIM_SPREAD := 0.25  # rounds scatter this far round the body point they aim at (per scale)
const BODY_MIDDLE := 3.0  # an unrigged body is struck this high (per body scale)...
const FEET_CLEAR := 1.0  # ...and a rigged one at a bone at least this high (never the feet)
const HIDE_DEPTH := 0.35  # they strike this share of the body radius out from a bone
const STONE_STEP := 2  # a stone roof's lowest step, in building voxels, under their feet

## Running totals and the figures drawn this frame (tests and the capture tool read them).
var shots := 0
var drawn := 0
var most_drawn := 0
## The latest volley's squad and the flashes and tracers lit now (the capture tool reads them).
var last_squad := -1
var lit := Vector2i.ZERO
var sim: RampageSim
## The drawn kaiju: rounds strike the part of its rigged body nearest each shooter.
var body: Node3D
var _city: CityView
var _sfx: Sfx
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _voxel: float
var _figures: Array[MultiMesh] = []
var _counts := PackedInt32Array()
var _flash_mm: MultiMesh
var _tracer_mm: MultiMesh
var _flashes: Array[Dictionary] = []
var _tracers: Array[Dictionary] = []


## rng: the presentation's own seeded stream (where tracers strike the hide).
func _init(p_sim: RampageSim, city: CityView, sfx: Sfx, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_city = city
	_sfx = sfx
	_rng = rng
	_cfg = sim.army["rooftop"]
	_voxel = Num.f(Content.section("street")["person_voxel"])


func _ready() -> void:
	for outfit: int in VoxelPerson.ROOFTOP_OUTFITS.size():
		var mm := _pool(VoxelPerson.rifleman(outfit, _voxel), Num.i(_cfg["max_drawn"]))
		_figures.append(mm)
	_counts.resize(_figures.size())
	_flash_mm = _pool(_star(), MAX_FLASHES, true)
	_tracer_mm = _pool(_glow_box(), MAX_TRACERS, true)


## A unit quad that always faces the camera, painted with a soft four-point star: additive,
## unshaded, fog-free, tinted per instance (muzzle flashes and the sparks on the hide).
func _star() -> QuadMesh:
	var img := Image.create(STAR_PIXELS, STAR_PIXELS, false, Image.FORMAT_RGBA8)
	var half := (STAR_PIXELS - 1) * 0.5
	for y: int in STAR_PIXELS:
		for x: int in STAR_PIXELS:
			var u := absf(x - half) / half
			var v := absf(y - half) / half
			var core := exp(-(u * u + v * v) * 3.5)
			var arms := exp(-u * 1.6) * exp(-v * 12.0) + exp(-v * 1.6) * exp(-u * 12.0)
			var a := clampf(core + arms, 0.0, 1.0) * clampf((1.0 - maxf(u, v)) * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = GLOW
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	var quad := QuadMesh.new()
	quad.material = mat
	return quad


## A unit cube that glows whatever the light and fog: unshaded, additive, tinted per instance.
func _glow_box() -> BoxMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = GLOW
	var box := BoxMesh.new()
	box.material = mat
	return box


func _pool(mesh: Mesh, count: int, colored := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colored
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if colored:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


## Where figure k of a squad stands (feet) and which way it faces, toward the kaiju.
func stance(squad: Army.Squad, k: int) -> Transform3D:
	var b := sim.buildings[squad.building]
	var to := (sim.kaiju_pos - squad.pos).normalized()
	if to == Vector2.ZERO:
		to = Vector2(0, -1)
	var across := Vector2(-to.y, to.x)
	var n := Num.i(_cfg["squad_size"])
	var at := squad.pos + across * (k - (n - 1) * 0.5) * SPACING + to * 0.1 * (k % 2)
	var feet := squad.cell.y + 1.0
	if b.style % 4 == BuildingVoxels.STONE:
		feet += STONE_STEP * BuildingVoxels.VOXEL
	var basis := Basis(Vector3.UP, atan2(-to.x, -to.y)).scaled(Vector3.ONE * FIGURE_SCALE)
	return Transform3D(basis, Vector3(at.x, feet, at.y))


## Runs after Rampage stepped the sim this frame (a descendant processes after it).
func _physics_process(delta: float) -> void:
	_counts.fill(0)
	drawn = 0
	var cap := Num.i(_cfg["max_drawn"])
	for squad: Army.Squad in sim.army_units.squads:
		for k: int in Num.i(_cfg["squad_size"]):
			if drawn >= cap:
				break
			var outfit := (squad.id + k * 2) % _figures.size()
			_figures[outfit].set_instance_transform(_counts[outfit], stance(squad, k))
			_counts[outfit] += 1
			drawn += 1
	for i: int in _figures.size():
		_figures[i].visible_instance_count = _counts[i]
	most_drawn = maxi(most_drawn, drawn)
	_draw_flashes(delta)
	_draw_tracers(delta)
	lit = Vector2i(_flash_mm.visible_instance_count, _tracer_mm.visible_instance_count)


## The sim's rooftop events (true when it was one); the kaiju's drawn body stands with its feet
## at `kaiju_at`.
func on_event(event: Dictionary, kaiju_at: Vector3) -> bool:
	if str(event["type"]) == "rooftop_fired":
		fired(Num.i(event["squad"]), kaiju_at)
		_sfx.play("rifle")
		return true
	if str(event["type"]) != "rooftop_destroyed":
		return false
	# Gone with its roof or under a blow: a puff of dust there and its biomass.
	var at := Vector3(Num.f(event["x"]), Num.f(event["y"]), Num.f(event["z"]))
	_city.fx.dust(at, 0.5)
	var list: Array = _cfg["rooftop_rubble"]
	var paid := Num.f(list[clampi(sim.size_tier() - 1, 0, list.size() - 1)])
	var gained := paid * sim.stat("rubble_mult")
	_city.float_text("+%d" % Num.i(gained), at + Vector3(0, 2, 0), UiKit.WARN)
	return true


## A squad's volley (sim rooftop_fired): a flash at each muzzle and a tracer from each at the
## kaiju, whose drawn body stands at `kaiju_at` with its feet there.
func fired(squad_id: int, kaiju_at: Vector3) -> void:
	for squad: Army.Squad in sim.army_units.squads:
		if squad.id != squad_id:
			continue
		shots += 1
		last_squad = squad_id
		for k: int in Num.i(_cfg["squad_size"]):
			var t := stance(squad, k)
			var muzzle := t * (Vector3(0, 8.5, -7.5) * _voxel)
			if _flashes.size() < MAX_FLASHES:
				var ahead := -t.basis.z.normalized() * FLASH_AHEAD
				var lag := k * FLASH_STAGGER
				_flashes.append(
					{"at": muzzle + ahead, "t": FLASH_SECONDS + lag, "size": FLASH_SIZE, "lag": lag}
				)
			var spot := Vector3(
				_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)
			)
			if _tracers.size() < MAX_TRACERS:
				var to := _hide(kaiju_at, muzzle, spot)
				var flight := muzzle.distance_to(to) / TRACER_SPEED
				_tracers.append({"from": muzzle, "to": to, "t": 0.0, "flight": flight})
		return


## Where a round from `muzzle` strikes: the bone of the drawn body nearest the shooter (above
## the feet), pushed out toward the shooter onto the hide, `spot` scattering it. A body without a
## rig is struck at its middle.
func _hide(kaiju_at: Vector3, muzzle: Vector3, spot: Vector3) -> Vector3:
	var bs := sim.body_scale()
	var aim := kaiju_at + Vector3.UP * bs * BODY_MIDDLE
	var rig: KaijuRig = null
	if body != null:
		for node: Node in body.find_children("*", "KaijuRig", true, false):
			rig = node as KaijuRig
	if rig != null:
		var best := INF
		for bone_name: String in rig.bone_names():
			var p := rig.bone(bone_name).global_position
			var d := p.distance_squared_to(muzzle)
			if p.y > kaiju_at.y + bs * FEET_CLEAR and d < best:
				best = d
				aim = p
	var out := (muzzle - aim).normalized() * Num.f(sim.powers_cfg["body_radius"]) * bs * HIDE_DEPTH
	return aim + out + spot * bs * AIM_SPREAD


func _draw_flashes(delta: float) -> void:
	var shown := 0
	for f: Dictionary in _flashes.duplicate():
		f["t"] = Num.f(f["t"]) - delta
		f["lag"] = Num.f(f["lag"]) - delta
		if Num.f(f["t"]) <= 0.0:
			_flashes.erase(f)
			continue
		if Num.f(f["lag"]) > 0.0:  # this rifle has not fired yet
			continue
		var at: Vector3 = f["at"]
		var size := Num.f(f["size"])
		_flash_mm.set_instance_transform(shown, Transform3D(Basis().scaled(Vector3.ONE * size), at))
		_flash_mm.set_instance_color(shown, HOT)
		shown += 1
	_flash_mm.visible_instance_count = shown


## Each tracer is a short glowing streak flying muzzle to hide; on arrival it is gone and the
## hide sparks exactly at its tip.
func _draw_tracers(delta: float) -> void:
	var shown := 0
	for tr: Dictionary in _tracers.duplicate():
		var flight := maxf(Num.f(tr["flight"]), 0.001)
		tr["t"] = Num.f(tr["t"]) + delta / flight
		var t := Num.f(tr["t"])
		var to: Vector3 = tr["to"]
		if t >= 1.0:
			if _flashes.size() < MAX_FLASHES:
				_flashes.append({"at": to, "t": SPARK_SECONDS, "size": SPARK_SIZE, "lag": 0.0})
			_tracers.erase(tr)
			continue
		var from: Vector3 = tr["from"]
		var head := from.lerp(to, t)
		var z := (to - from).normalized()
		var tail := head - z * minf(TRACER_LENGTH, head.distance_to(from))
		var x := z.cross(Vector3.UP)
		if x.length() < 0.01:
			x = Vector3.RIGHT
		x = x.normalized()
		var length := maxf(0.01, head.distance_to(tail))
		var basis := Basis(x * TRACER_WIDTH, z.cross(x) * TRACER_WIDTH, z * length)
		_tracer_mm.set_instance_transform(shown, Transform3D(basis, (head + tail) * 0.5))
		_tracer_mm.set_instance_color(shown, TRACER_HOT)
		shown += 1
	_tracer_mm.visible_instance_count = shown
