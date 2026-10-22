class_name StompLanding
extends RefCounted
## The scene's side of a standing stomp (ClipStomp is the body's): the crack a foot left last time
## is faded out as that foot lifts again (it was hidden under the foot, and lifting it would show
## the crack pop in), and the landing kicks the camera (CameraShake). Walking, the clip's own
## footfall delivers the stomp and neither applies. Presentation only. "clip_stomp" tuning:
## kick (trauma) and crack_fade_s.

var _shake: CameraShake
var _under: Dictionary = {}  # "left" / "right" -> the crack decal under that foot
var _lifted := ""  # the foot the latest stomp lifted ("" when none: walking)
var _cfg := Content.section("clip_stomp")


func _init(p_shake: CameraShake) -> void:
	_shake = p_shake


## A sim stomp reaches the kaiju: it stomps, and the foot that lifts lets go of its old crack.
func lift(kaiju: KaijuModel) -> void:
	kaiju.stomp()
	_lifted = kaiju.stomped_side()
	var old: Variant = _under.get(_lifted)
	if is_instance_valid(old):
		FxDecals.fade_out(old as Decal, Num.f(_cfg["crack_fade_s"]))
	_under.erase(_lifted)


## A stomp lands under `side`'s foot, leaving `crack` (null: none). The stomp's own foot kicks the
## camera.
func landed(side: String, crack: Decal) -> void:
	if crack != null:
		_under[side] = crack
	if side == _lifted:
		_lifted = ""
		_shake.add(Num.f(_cfg["kick"]), Vector3.INF, Vector3.ZERO, 1.0)
