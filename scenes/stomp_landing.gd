class_name StompLanding
extends RefCounted
## The scene's side of a standing stomp (ClipStomp is the body's): the crack a foot left last time
## is faded out as that foot lifts again (it was hidden under the foot, and lifting it would show
## the crack pop in), and the landing kicks the camera down (CameraShake.kick). Walking, the clip's
## own footfall delivers the stomp and neither applies. It also holds the sim stomp that waits for
## the foot to deliver it, and each footfall's dust, ring and sound (moved out of Rampage at its
## 400-line cap). Presentation only. "clip_stomp" tuning: kick_deg and crack_fade_s.

## The waiting stomp's ring radius, and the seconds it waits for its foot (past that it is
## heard but not seen).
var radius := 0.0
var wait := 0.0

var _shake: CameraShake
var _r: Rampage
var _city: CityView
## The foot a walking stomp falls on (the sim names it); "" when any will do.
var _side := ""
var _under: Dictionary = {}  # "left" / "right" -> the instance id of the crack decal there
var _lifted := ""  # the foot the latest stomp lifted ("" when none: walking)
var _cfg := Content.section("clip_stomp")


func _init(p_shake: CameraShake) -> void:
	_shake = p_shake


## For the run `r` and its `city`, once both are built.
func bind(r: Rampage, city: CityView) -> void:
	_r = r
	_city = city


## A sim stomp: its ring, cracks and crush wait for the foot that delivers it (footfall).
func on_stomp(kaiju: KaijuModel, event: Dictionary) -> void:
	lift(kaiju, str(event.get("side", "")))
	radius = Num.f(event["radius"])
	_r.stomp_sim_at.append(event["at"])
	_side = str(event["side"]) if event["on_foot"] else ""
	wait = Rampage.STOMP_WAIT
	_r.add_trauma(_shake.source("stomp"))


## A sim stomp reaches the kaiju: it stomps, and the foot that lifts lets go of its old crack.
func lift(kaiju: KaijuModel, side: String = "") -> void:
	kaiju.prefer_foot(side)
	kaiju.stomp()
	_lifted = kaiju.stomped_side()
	var old := instance_from_id(Num.i(_under.get(_lifted, 0))) as Decal  # null once it has faded
	if old != null:
		FxDecals.fade_out(old, Num.f(_cfg["crack_fade_s"]))
	_under.erase(_lifted)


## A stomp lands under `side`'s foot, leaving `crack` (null: none); whether it left one. The
## stomp's own foot kicks the camera.
func landed(side: String, crack: Decal) -> bool:
	if crack != null:
		_under[side] = crack.get_instance_id()
	if side == _lifted:
		_lifted = ""
		_shake.kick(deg_to_rad(Num.f(_cfg["kick_deg"])))  # straight down, every time
	return crack != null


## Counts the wait down by `delta`; true on the frame it runs out unanswered (no foot came down).
func wait_out(delta: float) -> bool:
	if wait <= 0.0:
		return false
	wait -= delta
	return wait <= 0.0


## Every footfall kicks a little dust and sounds a step (or the stomp that was waiting for this
## foot), so what you hear lands with what you see. Returns the camera dip the foot earns.
func footfall(side: String, strength: float, at: Vector3) -> float:
	var body := _r.sim.body_scale()
	var stomped := wait > 0.0 and side != "tail" and _side in ["", side]
	if stomped:
		land_under(side, at)
	_r.sfx.footstep(strength)
	var size := body * (0.2 + strength)
	if side != "tail":  # a tail slam throws its own puffs (Fx.shockwave)
		_city.fx.footfall(at + Vector3(0, 0.2, 0), Rampage.FOOTFALL_DUST * size)
	var ring := radius * 1.3 * Fx.STOMP_RING if stomped else Rampage.FOOTFALL_RING * size
	_city.fx.shockwave(at, ring, side == "tail", stomped)
	return Rampage.FOOTFALL_DIP * maxf(Rampage.FOOTFALL_DIP_FLOOR, body) * strength


## The waiting stomp lands under the foot that delivers it: cracks (if heavy enough), the street
## crushed around that foot, one dust ripple. Sound is released by the same footfall (Sfx.footstep).
func land_under(side: String, at: Vector3) -> void:
	wait = 0.0
	_r.rumble.stomp()
	var heavy := _r._power("stomp_damage")
	_r.sfx.stomp(heavy, landed(side, _r.ability_fx.stomp_cracks(at, radius, heavy)))
	var street := _city.street  # the foot lands wider than its ring (stomp_catch)
	var catch := street.tune("stomp_catch") * _r.sim.body_scale() if street != null else 0.0
	_city.crush(at, radius + catch)
	_r.stomp_ring_at.append(at)
