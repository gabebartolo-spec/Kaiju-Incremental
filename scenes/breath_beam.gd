class_name BreathBeam
extends Node3D
## The Lightning Breath (D-108, VFX_STYLE family 6): hot forked lightning from the croc's jaw, a
## dim feeler and then two or three bright strokes down one channel to what it strikes, with a fan
## of branches across the sim's hit cone (never past it). It is a BoltRig (the game's one bolt)
## kept on the jaw while the head moves; the old plasma cylinder and flame curtain are gone.
## Presentation only; all additive, so nothing hides the kaiju (D-025).

## How far along the jaw bone (hinge 0, chin 1) the breath leaves the mouth.
const MOUTH_ALONG_JAW := 0.7

## Signature Power's brightness for the next fire (1..fx.power_max).
var power := 1.0
## Where the sim's hit cone starts (the snout) for the next fire.
var cone_origin := Vector3.ZERO
## The body breathing: while the bolt is lit its root stays on the jaw as the head moves.
var follow: Node3D
## This breath's presentation stream (AbilityFx seeds one per breath).
var rng: RandomNumberGenerator
## The bolt itself (AbilityFx gives it the city's sparks and the first-hit test).
var rig: BoltRig
var _jaw: Node3D
var _hit := Vector3.ZERO
var _seconds: float


func _init(tint: Color, body_scale: float, tune: Dictionary) -> void:
	_seconds = Num.f(tune["beam_seconds"])
	var cfg: Dictionary = tune["bolt"]
	rig = BoltRig.new("breath", tint, body_scale, cfg)
	add_child(rig)


## Lights the breath from `mouth`: the bolt to `hit`, its branches across the cone that ends at
## `span` (mouth to the street at full reach), half_angle either side, for fx.beam_seconds.
func fire(mouth: Vector3, hit: Vector3, span: Vector3, half_angle: float) -> void:
	_hit = hit
	_jaw = jaw_of(follow)
	# The branches stay inside exactly the sim's hit cone: centred on the snout (`cone_origin`),
	# at full reach, half_angle either side; the bolt never promises more reach.
	var target := mouth + span
	var flat := Vector3(target.x - cone_origin.x, 0.0, target.z - cone_origin.z)
	rig.cone = {
		"origin": cone_origin,
		"dir": flat.normalized(),
		"reach": flat.length(),
		"half": half_angle,
		"y": target.y,
	}
	rig.power = power
	rig.aim(mouth, hit)
	rig.play(_seconds, rng)


## Where the breath leaves `model`: most of the way along its jaw bone, between the jaws, so the
## bolt starts at the snout rather than inside the body. `fallback` for bodies with no jaw.
static func mouth_of(model: Node3D, fallback: Vector3) -> Vector3:
	var jaw := jaw_of(model)
	return along_jaw(jaw) if jaw != null else fallback


## The model's "jaw" bone, when it hangs under a KaijuRig.
static func jaw_of(model: Node3D) -> Node3D:
	if model == null:
		return null
	var jaw := model.find_child("jaw", true, false) as Node3D
	var rig_node := jaw.get_parent() if jaw != null else null
	while rig_node != null and not rig_node is KaijuRig:
		rig_node = rig_node.get_parent()
	return jaw if rig_node != null else null


## The mouth point on `jaw` (from jaw_of) now.
static func along_jaw(jaw: Node3D) -> Vector3:
	var rig_node := jaw.get_parent()
	while not rig_node is KaijuRig:
		rig_node = rig_node.get_parent()
	return jaw.global_transform * ((rig_node as KaijuRig).dir_of("jaw") * MOUTH_ALONG_JAW)


func _process(_delta: float) -> void:
	if rig.live and is_instance_valid(_jaw):
		rig.aim(along_jaw(_jaw), _hit)
