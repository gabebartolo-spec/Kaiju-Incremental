class_name RooftopView
extends Node3D
## Rooftop defenders (D-063), presentation only: the sim's rooftop squads drawn as armed citizens
## and soldiers standing on their roofs, turned to the kaiju, rifles up. Each sim volley flashes
## at every muzzle of the squad and sends a thin tracer at the kaiju's hide; flashes, tracers and
## figures are MultiMesh pools, so a volley creates no nodes. At most army.rooftop.max_drawn
## figures are drawn (street life already costs milliseconds a frame).

const MAX_FLASHES := 48
const MAX_TRACERS := 48
const FLASH_SECONDS := 0.07
const FLASH_COLOR := Color(1.0, 0.85, 0.5, 0.0)
const TRACER_SECONDS := 0.16
const TRACER_SHARE := 0.3  # a tracer is this share of its flight long
const TRACER_WIDTH := 0.05
const SPACING := 0.3  # figures of a squad stand this far apart across their line of fire
const AIM_HEIGHT := 3.5  # tracers end this high on the kaiju (per body scale)...
const AIM_SPREAD := 1.2  # ...scattered this far either way
const STONE_STEP := 2  # a stone roof's lowest step, in building voxels, under their feet

## Running totals and the figures drawn this frame (tests and the capture tool read them).
var shots := 0
var drawn := 0
var most_drawn := 0
var sim: RampageSim
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
	_flash_mm = _pool(Look.voxel_mesh(_voxel * 2.0, 6.0), MAX_FLASHES, true)
	_tracer_mm = _pool(Look.voxel_mesh(1.0, 5.0), MAX_TRACERS, true)


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
	return Transform3D(Basis(Vector3.UP, atan2(-to.x, -to.y)), Vector3(at.x, feet, at.y))


## Runs after Rampage stepped the sim this frame (a child processes after its parent).
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


## The sim's rooftop events; the kaiju's drawn body stands with its feet at `kaiju_at`.
func on_event(event: Dictionary, kaiju_at: Vector3) -> void:
	if str(event["type"]) == "rooftop_fired":
		fired(Num.i(event["squad"]), kaiju_at)
		_sfx.play("rifle")
		return
	# Gone with its roof or under a blow: a puff of dust there and its biomass.
	var at := Vector3(Num.f(event["x"]), Num.f(event["y"]), Num.f(event["z"]))
	_city.fx.dust(at, 0.5)
	var list: Array = _cfg["rooftop_rubble"]
	var paid := Num.f(list[clampi(sim.size_tier() - 1, 0, list.size() - 1)])
	var gained := paid * sim.stat("rubble_mult")
	_city.float_text("+%d" % Num.i(gained), at + Vector3(0, 2, 0), UiKit.WARN)


## A squad's volley (sim rooftop_fired): a flash at each muzzle and a tracer from each at the
## kaiju, whose drawn body stands at `kaiju_at` with its feet there.
func fired(squad_id: int, kaiju_at: Vector3) -> void:
	for squad: Army.Squad in sim.army_units.squads:
		if squad.id != squad_id:
			continue
		shots += 1
		for k: int in Num.i(_cfg["squad_size"]):
			var t := stance(squad, k)
			var muzzle := t * (Vector3(0, 8.5, -7.5) * _voxel)
			if _flashes.size() < MAX_FLASHES:
				_flashes.append({"at": muzzle, "t": FLASH_SECONDS})
			var spot := Vector3(
				_rng.randf_range(-AIM_SPREAD, AIM_SPREAD),
				AIM_HEIGHT + _rng.randf_range(-AIM_SPREAD, AIM_SPREAD),
				_rng.randf_range(-AIM_SPREAD, AIM_SPREAD)
			)
			if _tracers.size() < MAX_TRACERS:
				var hit := kaiju_at + spot * sim.body_scale()
				_tracers.append({"from": muzzle, "to": hit, "t": 0.0})
		return


func _draw_flashes(delta: float) -> void:
	var shown := 0
	for f: Dictionary in _flashes.duplicate():
		f["t"] = Num.f(f["t"]) - delta
		if Num.f(f["t"]) <= 0.0:
			_flashes.erase(f)
			continue
		var at: Vector3 = f["at"]
		_flash_mm.set_instance_transform(shown, Transform3D(Basis(), at))
		_flash_mm.set_instance_color(shown, FLASH_COLOR)
		shown += 1
	_flash_mm.visible_instance_count = shown


## Each tracer is a thin glowing bar a share of its flight long, running muzzle to hide.
func _draw_tracers(delta: float) -> void:
	var shown := 0
	for tr: Dictionary in _tracers.duplicate():
		tr["t"] = Num.f(tr["t"]) + delta / TRACER_SECONDS
		var t := Num.f(tr["t"])
		if t >= 1.0:
			_tracers.erase(tr)
			continue
		var from: Vector3 = tr["from"]
		var to: Vector3 = tr["to"]
		var span := to - from
		var head := from + span * minf(1.0, t + TRACER_SHARE)
		var tail := from + span * t
		var z := (head - tail).normalized()
		var x := z.cross(Vector3.UP)
		if x.length() < 0.01:
			x = Vector3.RIGHT
		x = x.normalized()
		var basis := Basis(x * TRACER_WIDTH, z.cross(x) * TRACER_WIDTH, z * head.distance_to(tail))
		_tracer_mm.set_instance_transform(shown, Transform3D(basis, (head + tail) * 0.5))
		_tracer_mm.set_instance_color(shown, FLASH_COLOR)
		shown += 1
	_tracer_mm.visible_instance_count = shown
