class_name HexapodUpper
extends RefCounted
## The mantis's upper body for HexapodGait: the head, the raptorial scythes, the mandibles, the
## antennae, and the twitches. Nothing here eases: every move is a snap to a new pose (a stiff,
## fast spring) that is then held, so the insect reads as a machine of joints, never a floppy
## puppet. At rest it is never still: every 0.12-0.5 s something twitches (a head snap, a
## feeler flick, a claw flexing, the mandibles chattering, the body jerking to a new stance,
## a leg tapping). The roar rears the body and flares the scythes and mandibles wide.

## Twitches: seconds between them, and how many parts twitch at once (at most).
const TWITCH_EVERY := Vector2(0.12, 0.5)
const TWITCH_PARTS := 3
## The values that snap and hold.
const SNAPS: Array[String] = [
	"head_yaw",
	"head_pitch",
	"head_cock",
	"jerk_yaw",
	"jerk_pitch",
	"jerk_roll",
	"abdomen",
	"flex_l",
	"flex_r",
	"mandibles",
]
## Snap spring (1/s) and damping for every twitched value; a twitch holds this long (s).
const SNAP_OMEGA := 46.0
const SNAP_ZETA := 0.75
const TWITCH_HOLD := Vector2(0.1, 0.45)
## Head: seconds between hunting snaps, how far it turns, pitches and cocks sideways (rad).
const HEAD_HOLD := Vector2(0.15, 0.6)
const HEAD_YAW := 0.9
const HEAD_PITCH := 0.3
const HEAD_COCK := 0.5
## Body jerks (yaw, pitch, roll in rad) and an abdomen jerk (rad).
const BODY_JERK := Vector3(0.3, 0.16, 0.22)
const ABDOMEN_JERK := 0.35
## Scythes, in the body's frame (x out, y up, z forward): folded against the chest at rest
## (femur forward-up, tibia folded back down along it, claw tucked under).
const FOLD_FEMUR := Vector3(0.18, 0.75, 0.65)
const FOLD_TIBIA := Vector3(0.05, -0.8, -0.45)
const FOLD_CLAW := Vector3(0.0, -0.55, 0.7)
## Strike: thrown out ahead.
const STRIKE_FEMUR := Vector3(0.1, 0.25, 1.0)
const STRIKE_TIBIA := Vector3(0.0, -0.15, 1.0)
## Flare (the roar's threat display): spread wide and high, claws opened out.
const FLARE_FEMUR := Vector3(0.9, 0.9, 0.3)
const FLARE_TIBIA := Vector3(1.0, 0.6, 0.15)
const FLARE_CLAW := Vector3(0.5, -0.9, 0.2)
## A claw flex opens the tibia off the femur by up to this (share of the way to a strike).
const FLEX := 0.9
## Mandibles: how far they spread (rad) in a chatter and in the roar.
const CHATTER := 0.5
const MANDIBLE_FLARE := 0.7
## Roar: how long the display holds (s), its tremble (rad, Hz), how far the body rears (rad).
const ROAR_SECONDS := 1.3
const TREMBLE := 0.05
const TREMBLE_HZ := 23.0
const REAR := 0.45
## A strike's speed out (1/s) and a feeler flick's kick (rig units/s at scale 1).
const STRIKE_DECAY := 3.2
const FLICK := 16.0

## Outputs read by the gait: body jerk (yaw, pitch, roll), abdomen jerk, how far the body rears
## (0..1), and a leg to tap (-1: none; the gait clears it).
var body_jerk := Vector3.ZERO
var abdomen_jerk := 0.0
var rear := 0.0
var tap_leg := -1
## 0..1 how high the scythes are held on a perch.
var perch := 0.0
var _gait: KaijuGait
var _rig: KaijuRig
## Each twitched value (by its index in SNAPS): now, velocity, target, seconds left on hold.
var _val := PackedFloat32Array()
var _vel := PackedFloat32Array()
var _target := PackedFloat32Array()
var _hold := PackedFloat32Array()
var _twitch_in := 0.3
var _head_hold := 0.3
var _head_target := Vector3.ZERO
var _strike := 0.0
var _roar := 0.0


func _init(gait: KaijuGait) -> void:
	_gait = gait
	_rig = gait.rig
	_val.resize(SNAPS.size())
	_vel.resize(SNAPS.size())
	_target.resize(SNAPS.size())
	_hold.resize(SNAPS.size())


func strike() -> void:
	_strike = 1.0


func roar() -> void:
	_roar = 1.0


## A twitch at rest, a hunting head and the scythes posed. calm: 0 walking, 1 standing.
func update(dt: float, calm: float) -> void:
	var rng := _gait.rng
	_twitch_in -= dt
	if _twitch_in <= 0.0:
		_twitch_in = rng.randf_range(TWITCH_EVERY.x, TWITCH_EVERY.y)
		for _i: int in rng.randi_range(1, TWITCH_PARTS):
			_twitch(rng.randi() % 6, calm)
	_head_hold -= dt
	if _head_hold <= 0.0:
		_head_hold = rng.randf_range(HEAD_HOLD.x, HEAD_HOLD.y)
		var lead := clampf(_gait.yaw_rate * 0.25, -0.5, 0.5)
		_snap_to(
			"head_yaw", rng.randf_range(-HEAD_YAW, HEAD_YAW) * lerpf(0.4, 1.0, calm) + lead, 9.0
		)
		_snap_to("head_pitch", rng.randf_range(-HEAD_PITCH, HEAD_PITCH * 0.5), 9.0)
		var cock := rng.randf_range(-HEAD_COCK, HEAD_COCK) if rng.randf() < 0.45 else 0.0
		_snap_to("head_cock", cock, 9.0)
	for i: int in SNAPS.size():
		_step_snap(i, dt)
	_strike = maxf(0.0, _strike - dt * STRIKE_DECAY)
	_roar = maxf(0.0, _roar - dt / ROAR_SECONDS)
	# The display: up fast, held, dropped at the end.
	var display := clampf(minf(_roar * 6.0, (1.0 - _roar) * 12.0), 0.0, 1.0) if _roar > 0.0 else 0.0
	rear = display
	var tremble := sin(_gait.time * TAU * TREMBLE_HZ) * TREMBLE * display
	body_jerk = Vector3(_v("jerk_yaw"), _v("jerk_pitch"), _v("jerk_roll") + tremble)
	abdomen_jerk = _v("abdomen")
	_pose_head(display)
	var lash := sin(PI * pow(1.0 - _strike, 0.5)) if _strike > 0.0 else 0.0
	for arm: String in ["arm_l", "arm_r"]:
		var flex := _v("flex_" + arm.right(1))
		_pose_arm(arm, maxf(lash, perch * 0.35), flex, display)
	_pose_mandibles(maxf(_v("mandibles"), display * MANDIBLE_FLARE))


## One random part twitches to a new pose and holds it.
func _twitch(part: int, calm: float) -> void:
	var rng := _gait.rng
	match part:
		0:
			_snap_to("jerk_yaw", rng.randf_range(-1, 1) * BODY_JERK.x * calm)
			_snap_to("jerk_pitch", rng.randf_range(-1, 1) * BODY_JERK.y * calm)
			_snap_to("jerk_roll", rng.randf_range(-1, 1) * BODY_JERK.z * calm)
		1:
			_snap_to("abdomen", rng.randf_range(-1, 1) * ABDOMEN_JERK)
		2:
			_snap_to("flex_l" if rng.randf() < 0.5 else "flex_r", rng.randf_range(0.4, 1.0) * FLEX)
		3:
			_snap_to("mandibles", rng.randf_range(0.5, 1.0) * CHATTER)
		4:
			if calm > 0.5:
				tap_leg = rng.randi() % 4
			else:
				_snap_to(
					"flex_l" if rng.randf() < 0.5 else "flex_r", rng.randf_range(0.3, 0.7) * FLEX
				)
		_:
			_head_hold = 0.0  # snap the head now
	# The feelers flick with every twitch.
	for chain: KaijuRig.SpringChain in _rig.chains:
		if rng.randf() < 0.7:
			var kick := Vector3(
				rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), rng.randf_range(-1, 1)
			)
			chain.kick(_rig.global_transform.basis * kick * FLICK, 1.0 / 60.0)


## Snap a value to a target and hold it there for a while (hold <= 0: a random hold).
func _snap_to(key: String, target: float, hold: float = 0.0) -> void:
	var i := SNAPS.find(key)
	_target[i] = target
	_hold[i] = hold if hold > 0.0 else _gait.rng.randf_range(TWITCH_HOLD.x, TWITCH_HOLD.y)


func _step_snap(i: int, dt: float) -> void:
	_hold[i] -= dt
	if _hold[i] <= 0.0:
		_target[i] = 0.0  # the hold is over: snap back
	var p := KaijuGait.spring(_val[i], _vel[i], _target[i], SNAP_OMEGA, SNAP_ZETA, dt)
	_val[i] = p.x
	_vel[i] = p.y


func _v(key: String) -> float:
	return _val[SNAPS.find(key)]


func _pose_head(display: float) -> void:
	if not _rig.has_bone("head0"):
		return
	var yaw := _v("head_yaw") * (1.0 - display)
	var pitch := _v("head_pitch") - 0.4 * _strike + 0.35 * display
	var world := Basis(Vector3.UP, _gait.body_yaw + yaw)
	world = world * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, _v("head_cock"))
	_rig.set_world_basis("head0", world)


## One scythe by aiming its three bones in the body's frame: folded, struck out (lash 0..1),
## flexed open (flex 0..1) or flared in a display (0..1). Aimed from the thorax every frame, so
## it holds its pose rigidly through any turn.
func _pose_arm(arm: String, lash: float, flex: float, display: float) -> void:
	if not _rig.has_bone(arm + "2"):
		return
	var b := _rig.global_transform.basis.orthonormalized()
	var side := -1.0 if arm.ends_with("_l") else 1.0
	var out := b.x * side
	var up := b.y
	var fwd := -b.z
	var dir := func(v: Vector3) -> Vector3: return (out * v.x + up * v.y + fwd * v.z).normalized()
	var femur_v := FOLD_FEMUR.lerp(STRIKE_FEMUR, maxf(lash, flex * 0.5)).lerp(FLARE_FEMUR, display)
	var tibia_v := FOLD_TIBIA.lerp(STRIKE_TIBIA, maxf(lash, flex)).lerp(FLARE_TIBIA, display)
	var claw_v := FOLD_CLAW.lerp(STRIKE_TIBIA, lash).lerp(FLARE_CLAW, display)
	var s := _gait.s
	var shoulder := _rig.bone(arm + "0").global_position
	var femur: Vector3 = dir.call(femur_v)
	var tibia: Vector3 = dir.call(tibia_v)
	var claw: Vector3 = dir.call(claw_v)
	var elbow := shoulder + femur * _rig.dir_of(arm + "0").length() * s
	var wrist := elbow + tibia * _rig.dir_of(arm + "1").length() * s
	var tip := wrist + claw * _rig.dir_of(arm + "2").length() * s
	_rig.aim(arm + "0", shoulder, elbow)
	_rig.aim(arm + "1", elbow, wrist)
	_rig.aim(arm + "2", wrist, tip)


## Mandibles swing apart about the head's up axis (rig.json bones mandible_l/_r, if any).
func _pose_mandibles(spread: float) -> void:
	for m: String in ["mandible_l", "mandible_r"]:
		if _rig.has_bone(m):
			var side := -1.0 if m.ends_with("_l") else 1.0
			_rig.pose(m, Vector3(spread * 0.3, spread * side, 0))
