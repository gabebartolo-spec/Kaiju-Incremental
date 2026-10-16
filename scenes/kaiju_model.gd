class_name KaijuModel
extends Node3D
## A species' kaiju built from fine voxels (data colours, code shapes). Faces -Z. Shapes are
## written in design units and drawn at RES cells per unit, so detail (teeth, claws, scales,
## suckers, compound eyes) has room. About 10 units tall at body scale 1. Animation is
## presentation only: bob while walking, squash on stomp.

## Re-emits KaijuRig.foot_planted (see there) so the scene connects in one place.
signal foot_planted(side: String, strength: float, at: Vector3)

const RES := 5
const DESIGN_UNIT := 0.6
const VOXEL := DESIGN_UNIT / RES
## Height in world units of a voxelized model at body scale 1.
const MODEL_HEIGHT := 10.0
## Render layer bit lit by the kaiju-only rim light (layer 1 stays on for the world lights).
const RIM_LAYER := 2
## The kaiju's voxels sit on their own layer instead of the city's, so ground decals skip them.
const BODY_LAYER := 4
const IVORY := Color("e8e0c8")
const PUPIL := Color("15130f")

## Debug (D-041): rigid voxels per bone instead of a VoxelSkin. "--kaiju-rigid" after "--".
static var show_rigid_voxels := "--kaiju-rigid" in OS.get_cmdline_user_args()

var species_id: String
var _colors: Dictionary = {}
var _vox := VoxelBuilder.new()
## Walk-cycle flipbook poses of a voxelized model (empty for code-built bodies).
var _poses: Array[MultiMeshInstance3D] = []
var _body: Node3D
var _rig: KaijuRig
var _skin: VoxelSkin
var _walk_phase := 0.0
var _squash := 0.0


## stage: "baby", "adolescent" or "adult" (D-014); a missing stage falls back to the next one up.
func _init(p_species_id: String, colors: Dictionary, stage: String = "adult") -> void:
	species_id = p_species_id
	for key: String in colors:
		_colors[key] = Color(str(colors[key]))
	_body = Node3D.new()
	add_child(_body)
	_vox.salt = 7
	# A voxelized sculpt (tools/blender/voxelize.py, D-012) replaces the code-built body.
	_add_rim_light()
	# A rigged sculpt (tools/blender/rig_voxel.py, D-015) with walk and physics comes first.
	var stages: Array[String] = ["baby", "adolescent", "adult"]
	for i: int in range(stages.find(stage), stages.size()):
		var base := "res://assets/kaiju/%s_%s" % [species_id, stages[i]]
		_rig = KaijuRig.load_from(base, MODEL_HEIGHT, _glow())
		if _rig != null:
			if not show_rigid_voxels:
				_skin = VoxelSkin.load_for(_rig, base)
				if _skin != null:
					_rig.add_child(_skin)
			_body.add_child(_rig)
			_rig.foot_planted.connect(foot_planted.emit)
			return
	if species_id == "cephalopod":  # no sculpt yet: a code-built octopus on the radial rig
		_rig = CephalopodStandIn.build(colors, MODEL_HEIGHT, _glow())
		_body.add_child(_rig)
		return
	var model := Kvox.read("res://assets/kaiju/%s.kvox" % species_id)
	if model.height > 0:
		for pose: VoxelBuilder in model.frames:
			pose.salt = 7
			var mmi := _lit(pose.build({}, MODEL_HEIGHT / model.height, _glow(), Vector3.ZERO))
			mmi.visible = _poses.is_empty()
			_body.add_child(mmi)
			_poses.append(mmi)
		return
	match species_id:
		"insectoid":
			_insectoid()
		"cephalopod":
			_cephalopod()
		_:
			_reptilian()
	_body.add_child(_lit(_vox.build(_palette(), VOXEL, _glow(), Vector3.ZERO)))


## The life stage that matches an evolution tier (D-014): baby, then adolescent, then adult.
static func stage_for(size_tier: int) -> String:
	if size_tier <= 1:
		return "baby"
	return "adolescent" if size_tier == 2 else "adult"


## A cool rim light from behind and above that only lights the kaiju (render layer 2), so a dark
## hide still shows its shape against a dark city.
func _add_rim_light() -> void:
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("9fc4ff")
	rim.light_energy = 2.4
	rim.light_cull_mask = RIM_LAYER
	rim.rotation_degrees = Vector3(-35, 160, 0)
	add_child(rim)


## moving: 0..1 how hard the kaiju is walking this frame.
func animate(delta: float, moving: float) -> void:
	_walk_phase += delta * (2.0 + 8.0 * moving)
	_squash = maxf(0.0, _squash - delta * 5.0)
	if _rig != null:
		_rig.animate(delta, moving)  # the rig carries its own weight: no bob, no squash
		if _skin != null:
			_skin.sync()
		return
	_body.position.y = absf(sin(_walk_phase)) * 0.25 * moving
	_body.rotation.z = sin(_walk_phase) * 0.06 * moving
	_body.scale = Vector3(1.0 + _squash * 0.12, 1.0 - _squash * 0.15, 1.0 + _squash * 0.12)
	if _poses.size() > 1:
		var shown := posmod(floori(_walk_phase / PI * _poses.size() * 0.5), _poses.size())
		for i: int in _poses.size():
			_poses[i].visible = i == shown


## Worst drift of a planted foot so far (world units; 0 unrigged), for captures and tests.
func foot_drift() -> float:
	return _rig.gait.max_drift if _rig != null else 0.0


## Where the body is drawn now (world): its root bone, which can lag or lead the node (an insect's
## hold and dart, an octopus's drag and surge). Cameras follow this, not the node, so a hold is
## still on screen and a dart bursts. The node's position for unrigged bodies.
func focus() -> Vector3:
	if _rig == null:
		return global_position
	var p := _rig.bone(_rig.bone_names()[0]).global_position
	return Vector3(p.x, global_position.y, p.z)


## Hip height in world units (0 for unrigged bodies).
func hip_height() -> float:
	return _rig.gait.hip_height * _rig.gait.s if _rig != null else 0.0


## Lets a tentacled body grip buildings: finder(point: Vector3, radius: float) -> Vector3 gives the
## nearest building corner or edge (Vector3.INF if none).
func set_grip_finder(finder: Callable) -> void:
	if _rig != null and _rig.gait is RadialGait:
		(_rig.gait as RadialGait).grip_finder = finder


## Species-power hooks (no-ops on a body without the limb):
## a fast tail whip to one side (-1 left, +1 right) - the reptilian.
func tail_sweep(side: float) -> void:
	if _rig != null and _rig.gait is BipedGait:
		(_rig.gait as BipedGait).swing.whip(side)


## The maw held open (the beam) or shut again - the reptilian.
func jaw_open(open: bool) -> void:
	if _rig != null and _rig.gait is BipedGait:
		(_rig.gait as BipedGait).head.held_open = open


## Perched on a roof: a low, coiled climbing stance (or back to the ground) - the insectoid.
func climbing(on: bool) -> void:
	if _rig != null and _rig.gait is HexapodGait:
		(_rig.gait as HexapodGait).climbing = on


## A tentacle reaches to `at` and holds on (limb_hint < 0: the nearest) - the cephalopod.
func grab(limb_hint: int, at: Vector3) -> void:
	if _rig != null and _rig.gait is RadialGait:
		(_rig.gait as RadialGait).grab(limb_hint, at)


## The holding tentacle hurls toward a point.
func throw(toward: Vector3) -> void:
	if _rig != null and _rig.gait is RadialGait:
		(_rig.gait as RadialGait).throw(toward)


## Where a tentacle's tip is (to carry a grabbed thing); the model's origin for other bodies.
func limb_tip(limb_hint: int) -> Vector3:
	if _rig != null and _rig.gait is RadialGait:
		return (_rig.gait as RadialGait).limb_tip(limb_hint)
	return global_position


func stomp() -> void:
	if _rig != null:
		_rig.stomp()
	else:
		_squash = 1.0


func roar() -> void:
	if _rig != null:
		_rig.roar()


func _lit(mmi: MultiMeshInstance3D) -> MultiMeshInstance3D:
	mmi.layers = BODY_LAYER | RIM_LAYER
	return mmi


func _glow() -> float:
	return maxf(1.5, Look.value("accent_glow"))


## Species colours plus the detail shades derived from them. Alpha 0 marks a glowing cell.
func _palette() -> Dictionary:
	var lift := Look.value("kaiju_lift")
	var body: Color = _colors.get("body", Color.MAGENTA)
	var belly: Color = _colors.get("belly", Color.MAGENTA)
	if lift > 0.0:
		body = body.lightened(lift)
		belly = belly.lightened(lift)
	var accent: Color = _colors.get("accent", Color.MAGENTA)
	var eye: Color = _colors.get("eye", Color.MAGENTA)
	eye.a = 0.0
	var glowing_accent := accent
	if Look.value("accent_glow") > 0.0:
		glowing_accent.a = 0.0
	return {
		"body": body,
		"scale": body.darkened(0.18),
		"belly": belly,
		"belly_dark": belly.darkened(0.15),
		"accent": glowing_accent,
		"accent_edge": accent.lightened(0.3),
		"eye": eye,
		"pupil": PUPIL,
		"ivory": IVORY,
		"joint": accent.lightened(0.2),
	}


## Design units -> cells.
func _u(v: Vector3) -> Vector3:
	return v * RES


func _blob(c: Vector3, r: Vector3, key: String) -> void:
	_vox.blob(_u(c), r * RES, key)


func _tube(a: Vector3, b: Vector3, r: Vector2, key: String) -> void:
	_vox.tube(_u(a), _u(b), r * RES, key)


## Pseudo-random 0..99 per cell, for scale and speckle patterns.
func _roll(cell: Vector3i) -> int:
	return absi(hash(cell)) % 100


func _reptilian() -> void:
	for side: int in [-1, 1]:
		_blob(Vector3(side * 2.8, 3.2, 0.2), Vector3(1.8, 3.0, 2.0), "body")  # thighs
		_tube(
			Vector3(side * 2.9, 1.8, 0.4), Vector3(side * 3.0, 0.4, -0.8), Vector2(1.0, 0.8), "body"
		)
		for toe: int in 3:  # three clawed toes
			var x := side * (2.3 + toe * 0.6)
			_tube(Vector3(x, 0.3, -1.2), Vector3(x, 0.15, -2.3), Vector2(0.35, 0.25), "ivory")
		_tube(
			Vector3(side * 3.0, 11.0, -0.8),
			Vector3(side * 4.0, 9.4, -2.8),
			Vector2(0.85, 0.7),
			"body"
		)
		_tube(
			Vector3(side * 4.0, 9.4, -2.8),
			Vector3(side * 4.1, 8.3, -4.5),
			Vector2(0.7, 0.55),
			"body"
		)
		for claw: int in 3:
			var cx := side * (3.7 + claw * 0.35)
			_tube(Vector3(cx, 8.1, -4.7), Vector3(cx, 7.4, -5.4), Vector2(0.25, 0.2), "ivory")
	_blob(Vector3(0, 8.5, 0.5), Vector3(3.4, 5.0, 3.2), "body")  # torso
	_blob(Vector3(0, 8.0, -2.3), Vector3(2.3, 3.8, 1.0), "belly")
	_tube(Vector3(0, 12.0, -0.6), Vector3(0, 14.6, -3.0), Vector2(1.9, 1.6), "body")  # neck
	_blob(Vector3(0, 15.6, -4.3), Vector3(1.9, 1.5, 2.2), "body")  # skull
	_blob(Vector3(0, 15.0, -6.6), Vector3(1.4, 1.0, 1.7), "body")  # snout
	_blob(Vector3(0, 13.9, -5.6), Vector3(1.3, 0.6, 2.0), "belly")  # lower jaw
	_chain_tail()
	_reptile_details()


func _chain_tail() -> void:
	var points: Array[Vector3] = [
		_u(Vector3(0, 6.5, 3.0)),
		_u(Vector3(0, 4.6, 6.8)),
		_u(Vector3(0, 2.6, 10.2)),
		_u(Vector3(0.6, 1.0, 13.4)),
	]
	var radii: Array[float] = [2.5 * RES, 1.8 * RES, 1.1 * RES, 0.35 * RES]
	_vox.chain(points, radii, "body")


func _reptile_details() -> void:
	# Teeth along the mouth line, eyes with pupils, nostrils.
	var mouth_y := roundi(14.45 * RES)
	var z_front := roundi(-8.1 * RES)
	var z_back := roundi(-4.4 * RES)
	for z: int in range(z_front, z_back, 2):  # a row of teeth, the mouth narrowing to the front
		var t := float(z - z_front) / (z_back - z_front)
		for side: int in [-1, 1]:
			var x := side * roundi(RES * lerpf(0.55, 1.2, t))
			_vox.box(Vector3i(x, mouth_y - 1, z), Vector3i(x, mouth_y, z), "ivory")
	for side: int in [-1, 1]:
		var eye := Vector3i(side * roundi(1.75 * RES), roundi(16.0 * RES), roundi(-5.3 * RES))
		_vox.box(eye, eye + Vector3i(0, 2, 2), "eye")
		_vox.box(eye + Vector3i(side, 1, 1), eye + Vector3i(side, 1, 1), "pupil")
		_vox.put(Vector3i(side * 2, roundi(15.6 * RES), roundi(-7.7 * RES)), "pupil")
	# Scales on the hide, bands across the belly.
	_vox.repaint(
		func(cell: Vector3i, key: String) -> String:
			if key == "body" and _roll(cell) < 22:
				return "scale"
			if key == "belly" and cell.y % 3 == 0:
				return "belly_dark"
			return key
	)
	# Dorsal plates: flat triangles rooted on the spine, biggest over the shoulders.
	for i: int in 10:
		var z := roundi((-1.0 + i * 1.4) * RES)
		var root := _vox.top(0, z, ["accent", "accent_edge"])
		if root < -999:
			continue
		var height := roundi((1.0 + 1.8 * sin(PI * clampf((i + 1) / 8.0, 0.0, 1.0))) * RES)
		for h: int in height:
			var half := maxi(0, roundi((height - h) * 0.45))
			for dz: int in range(-half, half + 1):
				var key := "accent_edge" if h == height - 1 or absi(dz) == half else "accent"
				_vox.put(Vector3i(0, root + 1 + h, z + dz), key)


func _insectoid() -> void:
	_blob(Vector3(0, 4.6, 6.0), Vector3(2.8, 2.4, 3.8), "body")  # abdomen
	_blob(Vector3(0, 5.2, 0.6), Vector3(1.6, 1.6, 2.0), "body")  # thorax
	_tube(Vector3(0, 5.6, -1.2), Vector3(0, 5.9, -2.4), Vector2(1.0, 0.9), "body")  # neck
	_blob(Vector3(0, 6.0, -4.2), Vector3(2.2, 1.9, 2.0), "belly")  # head
	for side: int in [-1, 1]:
		_blob(Vector3(side * 1.8, 6.6, -4.8), Vector3(0.8, 0.9, 0.9), "eye")  # compound eyes
		_tube(
			Vector3(side * 1.3, 5.0, -5.8),
			Vector3(side * 0.5, 4.8, -8.0),
			Vector2(0.45, 0.25),
			"accent"
		)
		_tube(
			Vector3(side * 0.6, 4.8, -7.9),
			Vector3(side * 0.1, 4.8, -8.4),
			Vector2(0.2, 0.2),
			"ivory"
		)
		var antenna: Array[Vector3] = [
			_u(Vector3(side * 0.8, 7.6, -5.0)),
			_u(Vector3(side * 2.4, 10.6, -7.0)),
			_u(Vector3(side * 3.4, 11.6, -6.0)),
		]
		var thin: Array[float] = [0.4, 0.3, 0.3]
		_vox.chain(antenna, thin, "accent")
		for leg: int in 3:  # six legs: up to a high knee, splayed out and down to the ground
			var hip := Vector3(side * 1.2, 5.0, -0.4 + leg)
			var knee := Vector3(side * 5.0, 8.0, -2.0 + leg * 2.5)
			var foot := Vector3(side * 8.0, 0.0, -4.0 + leg * 4.0)
			_tube(hip, knee, Vector2(0.5, 0.45), "accent")
			_tube(knee, foot, Vector2(0.45, 0.3), "accent")
			_blob(knee, Vector3.ONE * 0.6, "joint")
	_vox.repaint(
		func(cell: Vector3i, key: String) -> String:
			if key == "body" and cell.z > roundi(3.0 * RES) and cell.z % 4 == 0:
				return "scale"  # abdomen segments
			if key == "eye" and posmod(cell.x * 3 + cell.y * 5 + cell.z * 7, 6) == 0:
				return "pupil"  # compound-eye facets
			return key
	)


func _cephalopod() -> void:
	_blob(Vector3(0, 10.0, 1.0), Vector3(3.6, 5.5, 3.6), "body")  # mantle
	_blob(Vector3(0, 5.5, 0.0), Vector3(2.8, 1.8, 2.8), "body")  # head under the mantle
	_tube(Vector3(0, 4.6, -2.4), Vector3(0, 4.0, -3.2), Vector2(0.6, 0.5), "belly")  # siphon
	for side: int in [-1, 1]:
		var eye := Vector3i(side * roundi(2.75 * RES), roundi(6.1 * RES), roundi(-0.6 * RES))
		_vox.blob(Vector3(eye), Vector3(1.0, 0.75, 0.75) * RES, "eye")
		_vox.box(eye + Vector3i(side * 2, 0, -2), eye + Vector3i(side * 2, 0, 2), "pupil")
	for i: int in 8:  # tentacles: thick at the head, tapering over the ground
		var angle := TAU * i / 8.0 + 0.2
		var dir := Vector3(sin(angle), 0, -cos(angle))
		var side := dir.cross(Vector3.UP)
		var points: Array[Vector3] = [
			_u(dir * 2.0 + Vector3(0, 4.2, 0)),
			_u(dir * 4.5 + Vector3(0, 1.6, 0)),
			_u(dir * 7.5 + Vector3(0, 0.6, 0) + side * 0.6),
			_u(dir * 10.0 + side * 1.6),
		]
		var radii: Array[float] = [1.0 * RES, 0.8 * RES, 0.55 * RES, 0.2 * RES]
		_vox.chain(points, radii, "body")
	_vox.repaint(
		func(cell: Vector3i, key: String) -> String:
			if key != "body":
				return key
			if cell.y > roundi(6.0 * RES) and _roll(cell) < 12:
				return "accent"  # mantle speckles
			if cell.y <= 1 and (cell.x + cell.z) % 2 == 0:
				return "belly"  # suckers on the undersides
			return key
	)
