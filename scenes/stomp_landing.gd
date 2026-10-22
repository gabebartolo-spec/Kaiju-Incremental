class_name StompLanding
extends RefCounted
## The scene's side of a standing stomp (ClipStomp is the body's): the crack a foot left last time
## is faded out as that foot lifts again (it was hidden under the foot, and lifting it would show
## the crack pop in), and the landing kicks the camera (CameraShake). Walking, the clip's own
## footfall delivers the stomp and neither applies. Presentation only. "clip_stomp" tuning:
## kick (trauma) and crack_fade_s.

var _shake: CameraShake
var _under: Dictionary = {}  # "left" / "right" -> the instance id of the crack decal there
var _lifted := ""  # the foot the latest stomp lifted ("" when none: walking)
var _cfg := Content.section("clip_stomp")


func _init(p_shake: CameraShake) -> void:
	_shake = p_shake


## A sim stomp reaches the kaiju: it stomps, and the foot that lifts lets go of its old crack.
func lift(kaiju: KaijuModel) -> void:
	kaiju.stomp()
	_lifted = kaiju.stomped_side()
	var old := instance_from_id(Num.i(_under.get(_lifted, 0))) as Decal  # null once it has faded
	if old != null:
		FxDecals.fade_out(old, Num.f(_cfg["crack_fade_s"]))
	_under.erase(_lifted)


## A stomp lands under `side`'s foot, leaving `crack` (null: none). The stomp's own foot kicks the
## camera.
func landed(side: String, crack: Decal) -> void:
	if crack != null:
		_under[side] = crack.get_instance_id()
	if side == _lifted:
		_lifted = ""
		_shake.trauma = maxf(_shake.trauma, Num.f(_cfg["kick"]))  # a kick, never stacked past it
