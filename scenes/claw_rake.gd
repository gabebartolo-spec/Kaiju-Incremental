class_name ClawRake
extends RefCounted
## The reptilian's heavy claw rake (D-177, director 2026-10-23: "like a bear's or Godzilla's
## swat"): the whole body throws it. On the sim's swipe_windup the chest turns away and the arm
## loads back (slow in), then the chest whips through, the hips follow a beat behind, the head
## comes late, and the hand sweeps low and wide across the front, crossing the snout line as the
## sim's swipe lands; it carries on well past the midline and settles slowly, heavier the bigger
## the stage. The arm is never scaled: the hand's path is authored about the shoulder (azimuth,
## elevation, reach as a share of the arm's length, "claw_fx") and solved with a two-bone reach, so
## it cannot stretch; the shoulder and elbow are kept inside a crocodilian forelimb's range
## ("claw_fx" rom). Timeline (s from the cue, one value, powers.swipe_windup): load -> strike (a
## smooth bell of speed, the hit a little past its peak) -> settle. Every leg starts and ends at
## rest in speed, so nothing ticks. Presentation only; BipedSwing calls tick() then pose() each
## frame, after the clip's pose.

var rig: KaijuRig
var side := 1.0  ## the raking arm's side (-1 left, +1 right)
var t := -1.0  ## seconds since the windup cue; negative when no rake runs
## Times the shoulder or elbow had to be held to its range (the path should keep clear of it).
var clamp_hits := 0
## The furthest the claw ended from where the path put it, as a share of the arm's length (a check).
var miss := 0.0
var _cfg: Dictionary = Content.section("claw_fx")
var _windup := Num.f(Content.section("powers")["swipe_windup"])
var _warp := 0.0  ## seconds still to add to t to meet the sim's hit


func _init(p_rig: KaijuRig) -> void:
	rig = p_rig


## Smooth 0..1 with no speed at either end (minimum jerk).
static func ease_in_out(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return k * k * k * (10.0 - 15.0 * k + 6.0 * k * k)


## Smooth 0..1 with no speed at either end whose speed peaks 60% of the way: a strike that gathers.
static func gather(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return k * k * k * k * (15.0 - 24.0 * k + 10.0 * k * k)


func active() -> bool:
	return t >= 0.0


## The windup cue: the arm on `p_side` begins the rake.
func start(p_side: float) -> void:
	side = p_side
	t = 0.0
	_warp = 0.0
	clamp_hits = 0
	miss = 0.0


## The sim's swipe lands now: the rake must be at its hit. A rake that began on the cue and is a
## frame or two off is eased onto the hit over a few frames; one with no cue starts at its hit.
func on_hit(p_side: float) -> void:
	if t < 0.0:
		start(p_side)
		t = hit_time()
		return
	side = p_side
	var gap := hit_time() - t
	_warp = 0.0 if absf(gap) < 2.0 / 60.0 else gap


## A "claw_fx" number that is one per growth step ({"baby", "adolescent", "adult"}) or a plain
## number.
func _by_stage(key: String) -> float:
	var v: Variant = _cfg[key]
	if v is Dictionary:
		var by_stage: Dictionary = v
		return Num.f(by_stage.get(rig.stage, by_stage["adult"]))
	return Num.f(v)


## How far through the strike's bell the hit comes (0..1).
func hit_at() -> float:
	return _by_stage("hit_at")


func load_s() -> float:
	return maxf(0.05, _windup - strike_s() * hit_at())


func strike_s() -> float:
	return _by_stage("strike_s")


## When (s from the cue) the hand crosses the snout line: the sim's swipe.
func hit_time() -> float:
	return load_s() + strike_s() * hit_at()


## The settle after the strike: heavier with the growth step (rig.stage).
func recover_s() -> float:
	return _by_stage("recover_s")


func total() -> float:
	return load_s() + strike_s() + recover_s()


## True while the claw lays its streak: around the hit, the fast part of the strike.
func drawing() -> bool:
	return (
		t >= hit_time() + Num.f(_cfg["trail_from_s"])
		and t <= hit_time() + Num.f(_cfg["trail_to_s"])
	)


func tick(dt: float) -> void:
	if t < 0.0:
		return
	var catch_up := _warp * minf(1.0, dt * 15.0)  # meet the hit over about four frames
	_warp -= catch_up
	t += dt + catch_up
	if t > total():
		t = -1.0


## The arm's bones as the rig has them: arm_<side>0..2, or empty when no arm on that side.
func names() -> Array[String]:
	var out: Array[String] = []
	for s: String in ["l", "r"]:
		if rig.has_bone("arm_%s2" % s) and signf(rig.dir_of("arm_%s0" % s).x) == side:
			for i: int in 3:
				out.append("arm_%s%d" % [s, i])
	return out


## value(at) along rest -> load -> over -> rest at `at` seconds from the cue.
func mix(rest: Vector3, loaded: Vector3, over: Vector3, at: float) -> Vector3:
	var lo := load_s()
	var st := strike_s()
	if at <= 0.0:
		return rest
	if at < lo:
		var slow := ease_in_out(pow(at / lo, _by_stage("load_ease")))
		var flare := ease_in_out(at / _by_stage("load_flare_s"))  # the hand swings out at once
		var share := _by_stage("load_flare")
		return rest.lerp(loaded, share * flare + (1.0 - share) * slow)
	if at < lo + st:
		return loaded.lerp(over, gather((at - lo) / st))
	return over.lerp(rest, ease_in_out((at - lo - st) / recover_s()))


func _scalar(rest: float, loaded: float, over: float, at: float) -> float:
	return mix(Vector3(rest, 0, 0), Vector3(loaded, 0, 0), Vector3(over, 0, 0), at).x


## The chest's frame in the rig: x across the shoulders (left to right), y dorsal, z = x cross y.
func chest(to_local: Transform3D) -> Basis:
	var l := (
		to_local * rig.bone("arm_r0").global_position
		- to_local * rig.bone("arm_l0").global_position
	)
	var f := to_local * rig.tail_world("spine2") - to_local * rig.bone("spine2").global_position
	l = l.normalized()
	f = (f - l * f.dot(l)).normalized()
	var u := l.cross(f).normalized()
	return Basis(l, u, l.cross(u))


## The arm as the gait holds it before the rake moves anything, and the rake's frame (rig space).
class Grip:
	var arm: Array[String] = []
	var to_local := Transform3D.IDENTITY
	var l0 := 0.0  # bone lengths, and their sum
	var l1 := 0.0
	var l2 := 0.0
	var reach := 0.0
	var s0 := Vector3.ZERO  # shoulder, elbow, wrist and claw as the gait holds them
	var e0 := Vector3.ZERO
	var w0 := Vector3.ZERO
	var tip0 := Vector3.ZERO
	var s := Vector3.ZERO  # the shoulder once the torso has turned
	var rest_dir := Vector3.ZERO  # the upper arm's standing hang, in the chest's frame


func _grip(arm: Array[String]) -> Grip:
	var g := Grip.new()
	g.arm = arm
	g.to_local = rig.global_transform.affine_inverse()
	g.l0 = rig.dir_of(arm[0]).length()
	g.l1 = rig.dir_of(arm[1]).length()
	g.l2 = rig.dir_of(arm[2]).length()
	g.reach = g.l0 + g.l1 + g.l2
	g.s0 = g.to_local * rig.bone(arm[0]).global_position
	g.e0 = g.to_local * rig.bone(arm[1]).global_position
	g.w0 = g.to_local * rig.bone(arm[2]).global_position
	g.tip0 = g.to_local * rig.tail_world(arm[2])
	# The upper arm's range is measured from the standing hang (BipedSwing.ARM_UPPER).
	var hang := (BipedSwing.ARM_UPPER * Vector3(side, 1.0, 1.0)).normalized()
	g.rest_dir = chest(g.to_local).inverse() * hang
	return g


## Lays the rake over the pose the gait has just put on the bones: first the torso, then the arm.
func pose() -> void:
	var arm := names()
	if t < 0.0 or arm.is_empty() or not rig.has_bone("spine2"):
		return
	var g := _grip(arm)
	var s_hit := _shoulder_at_hit(g.s0, g.to_local)
	_torso()
	g.s = g.to_local * rig.bone(arm[0]).global_position
	var key := _path_key(g, s_hit)
	var v := (
		Vector3(-side * cos(key.y) * sin(key.x), sin(key.y), -cos(key.y) * cos(key.x))
		* key.z
		* g.reach
	)
	_place(g, v, _scalar(0.0, 1.0, 1.0, t))


## The claw's (azimuth, elevation, reach share) about the shoulder now.
func _path_key(g: Grip, s_hit: Vector3) -> Vector3:
	var v0 := g.tip0 - g.s0
	var rest := Vector3(
		atan2(-side * v0.x, -v0.z),
		asin(clampf(v0.y / v0.length(), -1.0, 1.0)),
		v0.length() / g.reach
	)
	# The load draws the hand back and a little up from where the gait holds it (never over the
	# shoulder).
	var loaded := Vector3(
		0.0,
		minf(rest.y + deg_to_rad(Num.f(_cfg["load_lift_deg"])), -0.05),
		rest.z + Num.f(_cfg["load_reach"])
	)
	# The hit lands on the arm's side of the sim's band, hit_off_deg off the snout line (seen from
	# the body's axis at the shoulders): solve the azimuth there from where the shoulder will be,
	# and carry the overshoot on from it.
	var u_hit := gather(hit_at())
	var over := Vector3(0.0, deg_to_rad(Num.f(_cfg["elev_over_deg"])), Num.f(_cfg["reach_over"]))
	var at_hit := loaded.lerp(over, u_hit)
	var off := deg_to_rad(Num.f(_cfg["hit_off_deg"]))
	var across := absf(s_hit.x) * cos(off) / (at_hit.z * g.reach * cos(at_hit.y))
	var phi_hit := asin(clampf(across, -0.98, 0.98)) - off
	# The load is a fixed way behind the hit; the overshoot carries on from it by the share of the
	# strike left after the hit.
	loaded.x = phi_hit - deg_to_rad(_by_stage("load_back_deg"))
	over.x = loaded.x + (phi_hit - loaded.x) / u_hit
	return mix(rest, loaded, over, t)


## Puts the claw at shoulder + v: the wrist and elbow follow it (two-bone reach, bending toward the
## pole), the hand keeping the bend to the shoulder-to-claw line the gait gave it and easing to a
## slight droop (weight w) so it leads the claw through the strike.
func _place(g: Grip, v: Vector3, w: float) -> void:
	var p: Array = _cfg["pole"]
	var pole_rake := Vector3(side * Num.f(p[0]), Num.f(p[1]), Num.f(p[2])).normalized()
	var pole := (g.e0 - g.s0).normalized().lerp(pole_rake, w)
	var rest_bend := (g.tip0 - g.w0).normalized() - (g.tip0 - g.s0).normalized()
	var bend := rest_bend.lerp(Vector3.DOWN * Num.f(_cfg["hand_droop"]), w)
	var hand_dir := (v.normalized() + bend).normalized()
	var cap := (g.l0 + g.l1) * Num.f(_cfg["reach_cap"])
	var tip := g.s + v
	var wrist := tip - hand_dir * g.l2
	wrist = g.s + (wrist - g.s).normalized() * minf((wrist - g.s).length(), cap)
	var elbow := _hold_range(g, _reach(g, wrist, pole))
	wrist = elbow + (wrist - elbow).normalized() * g.l1
	var fore := (wrist - elbow).normalized()
	var most := deg_to_rad(Num.f(_cfg["rom"]["wrist_max"]) - 5.0)
	if fore.angle_to(hand_dir) > most:  # a folded elbow: the wrist never bends past its range
		hand_dir = fore.slerp(hand_dir, most / fore.angle_to(hand_dir))
	miss = maxf(miss, (wrist + hand_dir * g.l2 - tip).length() / g.reach)
	var to_world := rig.global_transform
	rig.aim(g.arm[0], to_world * g.s, to_world * elbow)
	rig.aim(g.arm[1], to_world * elbow, to_world * wrist)
	rig.aim(g.arm[2], to_world * wrist, to_world * (wrist + hand_dir * g.l2))


## The elbow for the shoulder and a wrist, bending toward `pole`.
func _reach(g: Grip, wrist: Vector3, pole: Vector3) -> Vector3:
	var far := (g.l0 + g.l1) * Num.f(_cfg["reach_cap"])
	var d := clampf((wrist - g.s).length(), absf(g.l0 - g.l1) * 1.02, far)
	var u := (wrist - g.s).normalized()
	var a := (g.l0 * g.l0 - g.l1 * g.l1 + d * d) / (2.0 * d)
	var h := sqrt(maxf(g.l0 * g.l0 - a * a, 0.0))
	var side_dir := pole - u * pole.dot(u)
	if side_dir.length() < 0.0001:
		side_dir = Vector3.DOWN - u * Vector3.DOWN.dot(u)
	return g.s + u * a + side_dir.normalized() * h


## Keeps the upper arm inside the crocodilian range, in the chest's frame: at most cone_max from
## the standing hang and elev_max over the chest's horizontal; a held elbow is counted.
func _hold_range(g: Grip, elbow: Vector3) -> Vector3:
	var rom: Dictionary = _cfg["rom"]
	var basis := chest(g.to_local)
	var dir := (basis.inverse() * (elbow - g.s)).normalized()
	var held := false
	var cone := deg_to_rad(Num.f(rom["cone_max"]))
	if dir.angle_to(g.rest_dir) > cone:
		var axis := g.rest_dir.cross(dir).normalized()
		dir = g.rest_dir.rotated(axis, cone)
		held = true
	var up := sin(deg_to_rad(Num.f(rom["elev_max"])))
	if dir.y > up:
		var flat := Vector2(dir.x, dir.z)
		flat = flat.normalized() * sqrt(1.0 - up * up)
		dir = Vector3(flat.x, up, flat.y)
		held = true
	if not held:
		return elbow
	clamp_hits += 1
	return g.s + basis * dir * g.l0


## The chest's yaw toward the strike (degrees, negative = turned away to load) `at` seconds in.
func _chest_deg(at: float) -> float:
	return _scalar(0.0, Num.f(_cfg["chest_load_deg"]), Num.f(_cfg["chest_over_deg"]), at)


## The yaw (rad, about the rig's up) of the hips, the lower and the upper spine `at` seconds in:
## the chest whips (leading the arm by chest_lead of the strike), the hips follow a beat behind (a
## share of it, at most hip_max), the rest of the turn split between the two spine bones.
func _spine_yaws(at: float) -> Vector3:
	var lead := Num.f(_cfg["chest_lead"]) * strike_s()
	var g := deg_to_rad(_chest_deg(at + lead))
	var lagged := deg_to_rad(_chest_deg(at - Num.f(_cfg["hip_lag_s"])))
	var hip_max := deg_to_rad(Num.f(_cfg["hip_max_deg"]))
	var hips := clampf(-Num.f(_cfg["hip_share"]) * lagged, -hip_max, hip_max)
	var split := Num.f(_cfg["chest_split"])
	return side * Vector3(hips, (g - hips) * split, (g - hips) * (1.0 - split))


## Where the shoulder `shoulder` (rig space, as the gait holds it) stands at the hit, with the
## torso turned as it will be then: the azimuth that puts the claw on the snout line depends on it.
func _shoulder_at_hit(shoulder: Vector3, to_local: Transform3D) -> Vector3:
	var yaws := _spine_yaws(hit_time())
	var pivot: Array[Vector3] = []
	for n: String in ["spine0", "spine1", "spine2"]:
		pivot.append(to_local * rig.bone(n).global_position)
	var q := shoulder
	var heads := pivot.duplicate()
	for i: int in 3:
		var turn := Basis(Vector3.UP, yaws[i])
		q = heads[i] + turn * (q - heads[i])
		for j: int in range(i + 1, 3):
			heads[j] = heads[i] + turn * (heads[j] - heads[i])
	return q + Vector3(side * _shift(hit_time()), 0.0, 0.0)


## Sideways weight shift (rig units) toward the strike side as the chest twists.
func _shift(at: float) -> float:
	var over_g := Num.f(_cfg["chest_over_deg"])
	var g := _chest_deg(at + Num.f(_cfg["chest_lead"]) * strike_s())
	return Num.f(_cfg["weight_shift"]) * rig.head_of("leg_l0").y * clampf(g / over_g, -1.0, 1.0)


## Lays the torso: the chest whips, the hips follow, the head comes late, the weight goes over.
func _torso() -> void:
	var yaws := _spine_yaws(t)
	_yaw("spine0", yaws.x)
	_yaw("spine1", yaws.y)
	_yaw("spine2", yaws.z)
	var follow := lerpf(
		Num.f(_cfg["head_follow_lo"]),
		1.0,
		smoothstep(0.0, 1.0, (t - hit_time()) / Num.f(_cfg["head_follow_s"]))
	)
	_yaw("head0", -(yaws.x + yaws.y + yaws.z) * (1.0 - follow))
	rig.bone("spine0").position += Vector3(side * _shift(t), 0.0, 0.0)


## Turns bone `bone_name` about the rig's up through its head by `angle`, on top of its pose.
func _yaw(bone_name: String, angle: float) -> void:
	if absf(angle) < 0.000001 or not rig.has_bone(bone_name):
		return
	var node := rig.bone(bone_name)
	var parent := node.get_parent() as Node3D
	var p := (
		(rig.global_transform.affine_inverse() * parent.global_transform).basis.orthonormalized()
	)
	var turned := p.inverse() * Basis(Vector3.UP, angle) * p * node.transform.basis
	node.transform = Transform3D(turned, node.transform.origin)
