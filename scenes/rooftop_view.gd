class_name RooftopView
extends Node3D
## Rooftop defenders (D-063), presentation only: the sim's rooftop squads drawn as armed citizens
## and soldiers standing on their roofs, turned to the kaiju, rifles up. Each sim volley flashes
## at every muzzle of the squad, a frame apart, sends a short tracer flying at the kaiju's hide
## and sparks where it strikes (drawn over the body, which would hide it). Flashes, tracers and
## sparks are unshaded and additive and ignore the fog, so a volley reads at the game camera
## from across the city. Everything is a MultiMesh pool, so a volley
## creates no nodes. At most army.rooftop.max_drawn figures are drawn (street life already costs
## milliseconds a frame); they stand FIGURE_SCALE times a street person, to read as a group.

const MAX_FLASHES := 48
const MAX_SPARKS := 48
const MAX_TRACERS := 48
## Flashes and sparks are counted in physics frames (60 a second), so the stagger is exact.
const FLASH_FRAMES := 3
const FLASH_SIZE := 0.5  # world units (about 15 px at the Behemoth's game camera), a star
const FLASH_AHEAD := 0.45  # the star burns this far out along the aim, clear of the shooter
const RAGGED_FRAMES := 14  # each rifle after the first fires up to this late, seeded (no unison)
## A spark on the hide is drawn over everything (the body would hide it) for this long.
const SPARK_FRAMES := 6
const SPARK_SIZE := 1.35  # about 38 px at the Behemoth's game camera
const POINT_BLANK_FRAMES := 3  # a round arriving sooner than this draws no tracer...
const SHORT_PIXELS := 60.0  # ...nor does one whose path on screen is shorter than this
const STAR_PIXELS := 32
const GLOW := Color(1.0, 0.82, 0.45)
## Over-range brightness per instance, past the city's glow threshold (1.1, AgX tonemap), so
## flashes, tracers and sparks bloom instead of reading as tan sticks.
const HOT := Color(4.0, 4.0, 4.0)
const TRACER_SPEED := 60.0  # world units a second, muzzle to hide
const TRACER_LENGTH := 1.75  # a tracer is a short streak this long, flying the whole way
## Its streak is drawn in pieces, brightest at the head, fading along the trail behind it.
const TRAIL: Array[float] = [1.0, 0.55, 0.25]
const TRACER_WIDTH := 0.05
## A tracer burns less over-range than a flash: a thin core with a soft glow, not a white rod.
const TRACER_HOT := Color(2.0, 2.0, 2.0)
const FIGURE_SCALE := 1.5
const MUZZLE_HEIGHT := 8.5  # a figure's rifle is this many person voxels over its feet
## A figure taller than this share of the screen (a roof under the camera; usually ~1%) is hidden.
const MAX_SCREEN_SHARE := 0.04
const SPACING := 0.55  # figures of a squad stand this far apart across their line of fire
const STONE_STEP := 2  # a stone roof's lowest step, in building voxels, under their feet
const PARAPET_IN := 2  # figures stand this many building voxels in from a roof's edge

## Running totals and the figures drawn this frame (tests and the capture tool read them).
var shots := 0
var drawn := 0
var most_drawn := 0
## The latest volley's squad and the flashes and tracers lit now (the capture tool reads them).
var last_squad := -1
var lit := Vector2i.ZERO
## The worst time one volley's hit search took, in microseconds (the gate tool reads it).
var worst_aim_usec := 0
## Every spark drawn: {"at": world point, "frame": physics frame} (the capture tool measures them).
var spark_log: Array[Dictionary] = []
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
var _spark_mm: MultiMesh
var _sparks: Array[Dictionary] = []
var _frame := 0
var _tracer_mm: MultiMesh
var _flashes: Array[Dictionary] = []
var _tracers: Array[Dictionary] = []
var _shown := {}  # squad id -> true for the squads drawn this frame


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
	_flash_mm = _pool(_star(false), MAX_FLASHES, true)
	_spark_mm = _pool(_star(true), MAX_SPARKS, true)
	_tracer_mm = _pool(_glow_box(), MAX_TRACERS * TRAIL.size(), true)


## A unit quad that always faces the camera, painted with a soft four-point star: additive,
## unshaded, fog-free, tinted per instance; on_top: drawn over everything (sparks on the hide).
func _star(on_top: bool) -> QuadMesh:
	var img := Image.create(STAR_PIXELS, STAR_PIXELS, false, Image.FORMAT_RGBA8)
	var half := (STAR_PIXELS - 1) * 0.5
	for y: int in STAR_PIXELS:
		for x: int in STAR_PIXELS:
			var u := absf(x - half) / half
			var v := absf(y - half) / half
			var core := exp(-(u * u + v * v) * 14.0)
			var arms := exp(-u * 2.5) * exp(-v * 30.0) + exp(-v * 2.5) * exp(-u * 30.0)
			var a := clampf(core + arms, 0.0, 1.0) * clampf((1.0 - maxf(u, v)) * 4.0, 0.0, 1.0)
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
	mat.no_depth_test = on_top
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
	var inset := Vector2(b.w, b.d) * 0.5 - Vector2.ONE * PARAPET_IN * BuildingVoxels.VOXEL
	at = at.clamp(Vector2(b.x, b.z) - inset, Vector2(b.x, b.z) + inset)  # in from the parapet
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
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	_shown.clear()
	for squad: Army.Squad in _nearest_first():
		if drawn >= cap:
			break
		if _looms(stance(squad, 0), camera):
			continue
		_shown[squad.id] = true
		for k: int in mini(Num.i(_cfg["squad_size"]), cap - drawn):
			var outfit := (squad.id + k * 2) % _figures.size()
			_figures[outfit].set_instance_transform(_counts[outfit], stance(squad, k))
			_counts[outfit] += 1
			drawn += 1
	for i: int in _figures.size():
		_figures[i].visible_instance_count = _counts[i]
	most_drawn = maxi(most_drawn, drawn)
	_frame += 1
	_draw_flashes()
	_draw_tracers(delta)
	_draw_sparks()
	lit = Vector2i(_flash_mm.visible_instance_count, _tracer_mm.visible_instance_count)


## The squads nearest the kaiju first: past max_drawn the far ones go undrawn (D-076).
func _nearest_first() -> Array[Army.Squad]:
	var order := sim.army_units.squads.duplicate()
	var at := sim.kaiju_pos
	order.sort_custom(
		func(a: Army.Squad, b: Army.Squad) -> bool:
			return a.pos.distance_squared_to(at) < b.pos.distance_squared_to(at)
	)
	return order


## Whether a figure at `t` looms: on a roof so near the camera that it stands taller than
## MAX_SCREEN_SHARE of the screen (D-076). It is not drawn; its volleys show only the spark.
func _looms(t: Transform3D, camera: Camera3D) -> bool:
	if camera == null or camera.is_position_behind(t.origin):
		return false
	var top := t * (Vector3.UP * MUZZLE_HEIGHT * _voxel)
	var tall := camera.unproject_position(t.origin).distance_to(camera.unproject_position(top))
	return tall > get_viewport().get_visible_rect().size.y * MAX_SCREEN_SHARE


## The sim's rooftop events (true when it was one); the kaiju's drawn body stands with its feet
## at `kaiju_at`.
func on_event(event: Dictionary, kaiju_at: Vector3) -> bool:
	if str(event["type"]) == "rooftop_fired":
		var squad_id := Num.i(event["squad"])
		fired(squad_id, kaiju_at)
		_sfx.play_at("rifle", _squad_at(squad_id))
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


## Where a squad stands (its first soldier), for the volley's sound to come from.
func _squad_at(squad_id: int) -> Vector3:
	for squad: Army.Squad in sim.army_units.squads:
		if squad.id == squad_id:
			return stance(squad, 0).origin
	return Vector3.ZERO


## A squad's volley (sim rooftop_fired): a flash at each muzzle and a tracer from each at the
## kaiju, whose drawn body stands at `kaiju_at` with its feet there.
func fired(squad_id: int, kaiju_at: Vector3) -> void:
	for squad: Army.Squad in sim.army_units.squads:
		if squad.id != squad_id:
			continue
		var seen := _shown.has(squad_id)  # undrawn (looming, past max_drawn): only the hide spark
		shots += 1
		last_squad = squad_id
		var t0 := Time.get_ticks_usec()
		var rig := RooftopAim.rig_of(body)
		var middle := kaiju_at + Vector3.UP * sim.body_scale() * RooftopAim.BODY_MIDDLE
		for k: int in Num.i(_cfg["squad_size"]):
			var t := stance(squad, k)
			var muzzle := t * (Vector3(0, MUZZLE_HEIGHT, -7.5) * _voxel)
			var wait := 0 if k == 0 else _rng.randi_range(2, RAGGED_FRAMES)
			if seen and _flashes.size() < MAX_FLASHES:
				var ahead := -t.basis.z.normalized() * FLASH_AHEAD
				_flashes.append({"hit": {"at": muzzle + ahead}, "wait": wait, "left": FLASH_FRAMES})
			var hit := RooftopAim.strike(rig, middle, muzzle, _rng)
			var to := RooftopAim.at(hit)
			var flight := muzzle.distance_to(to) / TRACER_SPEED
			var frames := roundi(flight * Engine.physics_ticks_per_second)
			if not seen or frames < POINT_BLANK_FRAMES or _on_screen(muzzle, to) < SHORT_PIXELS:
				_spark(hit, wait + frames)  # flash and spark only: a stub of a tracer reads as noise
			elif _tracers.size() < MAX_TRACERS:
				_tracers.append(
					{"from": muzzle, "hit": hit, "t": 0.0, "flight": flight, "wait": wait}
				)
		worst_aim_usec = maxi(worst_aim_usec, Time.get_ticks_usec() - t0)
		return


## How long the line from `a` to `b` is on screen, in pixels (INF without a camera).
func _on_screen(a: Vector3, b: Vector3) -> float:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or camera.is_position_behind(a) or camera.is_position_behind(b):
		return INF
	return camera.unproject_position(a).distance_to(camera.unproject_position(b))


func _draw_flashes() -> void:
	_flash_mm.visible_instance_count = _draw_stars(_flashes, _flash_mm, FLASH_SIZE)


func _draw_sparks() -> void:
	_spark_mm.visible_instance_count = _draw_stars(_sparks, _spark_mm, SPARK_SIZE)


## A spark at strike `hit` on the hide, after `wait` frames; it rides the body while it burns.
func _spark(hit: Dictionary, wait: int) -> void:
	if _sparks.size() < MAX_SPARKS:
		_sparks.append({"hit": hit, "wait": wait, "left": SPARK_FRAMES})


## Draws each star whose wait is over, for its frames left; returns how many it drew.
func _draw_stars(stars: Array[Dictionary], mm: MultiMesh, size: float) -> int:
	var shown := 0
	for f: Dictionary in stars.duplicate():
		if Num.i(f["wait"]) > 0:  # this rifle has not fired yet (or the round not arrived)
			f["wait"] = Num.i(f["wait"]) - 1
			continue
		if Num.i(f["left"]) <= 0:
			stars.erase(f)
			continue
		var struck: Dictionary = f["hit"]
		var at := RooftopAim.at(struck)
		if at == Vector3.INF:  # the bone it struck is gone (a stage change)
			stars.erase(f)
			continue
		if mm == _spark_mm and Num.i(f["left"]) == SPARK_FRAMES:
			spark_log.append({"at": at, "frame": _frame})
		var total := float(SPARK_FRAMES if mm == _spark_mm else FLASH_FRAMES)
		var fade := Num.f(f["left"]) / total  # full on the first frame, fading out
		f["left"] = Num.i(f["left"]) - 1
		mm.set_instance_transform(shown, Transform3D(Basis().scaled(Vector3.ONE * size), at))
		mm.set_instance_color(shown, HOT * fade)
		shown += 1
	return shown


## Each tracer is a short glowing streak flying muzzle to hide; on arrival it is gone and the
## hide sparks exactly at its tip.
func _draw_tracers(delta: float) -> void:
	var shown := 0
	for tr: Dictionary in _tracers.duplicate():
		if Num.i(tr["wait"]) > 0:  # fired with its rifle, a frame or two after the first
			tr["wait"] = Num.i(tr["wait"]) - 1
			continue
		var flight := maxf(Num.f(tr["flight"]), 0.001)
		tr["t"] = Num.f(tr["t"]) + delta / flight
		var t := Num.f(tr["t"])
		var hit: Dictionary = tr["hit"]
		var to := RooftopAim.at(hit)
		if t >= 1.0 or to == Vector3.INF:
			if to != Vector3.INF:
				_spark(hit, 0)
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
		var piece := maxf(0.01, head.distance_to(tail)) / TRAIL.size()
		var basis := Basis(x * TRACER_WIDTH, z.cross(x) * TRACER_WIDTH, z * piece)
		for i: int in TRAIL.size():  # head first, each piece behind the last and dimmer
			var mid := head - z * piece * (i + 0.5)
			_tracer_mm.set_instance_transform(shown, Transform3D(basis, mid))
			_tracer_mm.set_instance_color(shown, TRACER_HOT * TRAIL[i])
			shown += 1
	_tracer_mm.visible_instance_count = shown
