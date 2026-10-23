class_name KaijuModel
extends Node3D
## A species' kaiju of fine voxels (data colours, code shapes), facing -Z, in design units drawn at
## RES cells per unit so detail has room; ~10 units tall at body scale 1. Presentation only.

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
			_skin = VoxelSkin.attach(_rig, base)  # D-041; null when debugging rigid voxels
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
	KaijuCodeBody.new(_vox).shape(species_id)
	_body.add_child(_lit(_vox.build(_palette(), VOXEL, _glow(), Vector3.ZERO)))


## The life stage that matches an evolution tier (D-014): baby, then adolescent, then adult.
static func stage_for(size_tier: int) -> String:
	if size_tier <= 1:
		return "baby"
	return "adolescent" if size_tier == 2 else "adult"


## A cool rim light from behind, above, on the kaiju only (layer 2): a dark hide shows in the dark.
func _add_rim_light() -> void:
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("9fc4ff")
	rim.light_energy = 2.4
	rim.light_cull_mask = RIM_LAYER
	rim.rotation_degrees = Vector3(-35, 160, 0)
	add_child(rim)


## The sim's step clock for the legs (BodyContact.step_clock; INF: their own): they step on it,
## each step step_ratio of a full stride long. Call before animate().
func follow_steps(step_phase: float, step_ratio: float) -> void:
	if _rig != null:
		_rig.gait.step_phase = step_phase
		_rig.gait.step_ratio = step_ratio


## A heavy body's drawn body and tail as the sim has them (BodyContact.body_dir, TailSim.bends,
## D-208): the gait shows them instead of working out its own.
func follow_body(body: BodyContact) -> void:
	if _rig == null or body.tail == null:
		return
	_rig.gait.fed_yaw = atan2(-body.body_dir.x, -body.body_dir.y)
	_rig.gait.fed_tail = body.tail.bends


## moving: 0..1 how hard it walks; turn_ahead: yaw (rad) still to turn, the head leads by it.
func animate(delta: float, moving: float, turn_ahead: float = INF) -> void:
	_walk_phase += delta * (2.0 + 8.0 * moving)
	_squash = maxf(0.0, _squash - delta * 5.0)
	if _rig != null:
		_rig.gait.turn_ahead = turn_ahead
		_rig.animate(delta, moving)  # the rig carries its own weight: no bob, no squash
		VoxelSkin.sync_if(_skin)
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
## hold and dart, an octopus's surge); cameras follow this. The node's position when unrigged.
func focus() -> Vector3:
	if _rig == null:
		return global_position
	var p := _rig.bone(_rig.bone_names()[0]).global_position
	return Vector3(p.x, global_position.y, p.z)


## This kaiju's weight class (KaijuRig.body_class), or {} (none, or no rig).
func body_class() -> Dictionary:
	return _rig.body_class() if _rig != null else {}


## Hip height in world units (0 for unrigged bodies).
func hip_height() -> float:
	return _rig.gait.hip_height * _rig.gait.s if _rig != null else 0.0


## Lets a tentacled body grip buildings: finder(point, radius) -> nearest corner/edge or INF.
func set_grip_finder(finder: Callable) -> void:
	if _rig != null and _rig.gait is RadialGait:
		(_rig.gait as RadialGait).grip_finder = finder


## Species-power hooks (no-ops on a body without the limb):
## a fast tail whip to one side (-1 left, +1 right), or limb "claw_windup"/"claw": an arm's lift
## and rake - the reptilian; a rake returns the arm's sweep (BipedSwing.claw_arc), else {}.
func tail_sweep(side: float, limb: String = "tail") -> Dictionary:
	if _rig != null and _rig.gait is BipedGait:
		var swing := (_rig.gait as BipedGait).swing
		swing.strike(limb, side)
		return swing.claw_arc(side) if limb == "claw" else {}
	return {}


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


## The foot the latest stomp lifted ("left" / "right"), or "" when it lifted none: walking, the
## clip's own footfall delivers the stomp (ClipGait.stomped_side).
func stomped_side() -> String:
	if _rig != null and _rig.gait is ClipGait:
		return (_rig.gait as ClipGait).stomped_side()
	return ""


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
