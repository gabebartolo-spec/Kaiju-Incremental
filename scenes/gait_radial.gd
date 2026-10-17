class_name RadialGait
extends KaijuGait
## The cephalopod's crawl: no legs, no tip-toe. The arms at the front take turns: one reaches
## ahead, slaps down and grips (the ground, or a building's corner or edge in reach), and the
## body surges after it; between grips the body drags and slides, slowing, while the arms
## behind trail along the street. The mantle stretches toward its grip, squashes on the slap
## and breathes. Standing, the arms ripple and grope, and wrap any building edge close enough.

## Arm chain feel: stiffness towards the splayed rest pose, gravity share.
const ARM_STIFFNESS := 5.0
const ARM_GRAVITY := 1.6
## Reaching: seconds per reach (scale 1), arc height (body heights), most arms reaching at once.
const REACH_SECONDS := 0.42
const REACH_ARC := 0.4
const MAX_REACHING := 1
## Only the LEAD_ARMS arms rooted nearest the travel direction (and within this angle of it,
## rad) walk; the rest trail.
## A new reach waits this long (s at scale 1) after the last grip landed.
const LEAD_ARC := 1.25
const LEAD_ARMS := 3
const REACH_GAP := 0.2
## Drag and surge: between grips the body moves at this share of the sim's speed; after a grip
## it catches up at this rate (1/s) for SURGE seconds; it may fall this far behind (hip heights).
const DRAG := 0.3
const SURGE_RATE := 7.0
const SURGE := 0.35
const MAX_LAG := 1.4
const MAX_LAG_SECONDS := 0.45  ## ... or this many seconds of the sim's travel, if more
## Where a reaching arm aims: share of its length, how far ahead of the travel direction.
const AIM_REACH := 0.9
const AIM_AHEAD := 0.9
## A gripping arm pushes until its grip is this far behind the body (share of its length).
const PUSH_UNTIL := 0.35
## A gripping arm lets go when stretched past this share of its length.
const RELEASE_STRETCH := 0.98
## A gripping arm shortens to keep this much slack (share of its length), down to CONTRACT_MIN.
const GRIP_SLACK := 0.95
const CONTRACT_MIN := 0.5
## Turning faster than this (rad/s) frees the arms behind the new heading; a grip's lurch.
const TURN_RELEASE := 0.8
const SLAP := 2.0
## Grab and throw (species powers): reach time, hold height (body heights), throw speed.
const GRAB_SECONDS := 0.3
const HOLD_HEIGHT := 1.6
const THROW_SPEED := 45.0
## A tentacle slapping down to grip (KaijuRig.foot_planted strength for an adult).
const GRIP_WEIGHT := 0.45
## Grip on buildings: search radius (arm lengths).
const GRIP_RADIUS := 1.1
## Mantle: stretch toward the grip, squash, drag tilt, breathing.
const STRETCH := 0.35
const DRAG_TILT := 0.18
const BREATH_HZ := 0.6
const BREATH := 0.07
## The roar: the mantle puffs up by this share, the arms ripple this many times faster.
const ROAR_PUFF := 0.2
const ROAR_RIPPLE := 3.0
## Groping while standing: curl wave speed (Hz) and strength (rad per bone).
const GROPE_HZ := 0.7
const GROPE := 0.32


class Arm:
	var chain: KaijuRig.SpringChain
	var angle := 0.0  ## around the body, rig space
	var length := 0.0  ## rig units, root to tip
	var gripping := false
	var reaching := false
	var t := 0.0
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var grip := Vector3.ZERO
	var on_building := false
	var phase := 0.0
	var idle := 0.0  ## seconds free (not gripping or reaching)
	var holding := false  ## grabbed something for a throw (KaijuModel.grab)


var arms: Array[Arm] = []
## Optional: Callable(world_point: Vector3, radius: float) -> Vector3 giving the nearest building
## corner or edge to grip (Vector3.INF when none). Set by the scene that knows the city.
var grip_finder := Callable()
var _mantle: Node3D
var _pull := 0.0
var _pull_v := 0.0
var _slam := 0.0
var _lash := 0.0
var _tilt := Vector2.ZERO
var _lag := Vector3.ZERO
var _surge := 0.0
var _since_grip := 1.0
var _moving := false
var _turning := false


func _init(p_rig: KaijuRig) -> void:
	super(p_rig)
	turn_max = 2.5
	for chain: KaijuRig.SpringChain in rig.chains:
		if not chain.names[0].begins_with("tentacle"):
			continue
		var arm := Arm.new()
		arm.chain = chain
		chain.stiffness = ARM_STIFFNESS
		chain.gravity_scale = ARM_GRAVITY
		var tip := rig.head_of(chain.names[-1]) + rig.dir_of(chain.names[-1])
		var root := rig.head_of(chain.names[0])
		arm.angle = atan2(tip.x, -tip.z)
		for n: String in chain.names:
			arm.length += rig.dir_of(n).length()
		arm.phase = rng.randf() * TAU
		hip_height = maxf(hip_height, root.y)
		arms.append(arm)
	for child: Node in rig.bone("mantle0").get_children():
		if child is MultiMeshInstance3D:
			_mantle = child as MultiMeshInstance3D


func update(delta: float) -> void:
	track(delta)
	var dt := minf(delta, 1.0 / 20.0)
	var hip_w := hip_height * s
	var moving := speed > 0.15 * s
	_crawl(dt, hip_w, moving)
	var root := rig.global_transform
	var ground := root.origin.y
	# Turning, the arms behind the new heading let go and the next reach comes sooner.
	var turning := absf(yaw_rate) > TURN_RELEASE
	_moving = moving
	_turning = turning
	var heading := velocity.normalized() if speed > 0.05 else Vector3.ZERO
	var reaching := 0
	for arm: Arm in arms:
		reaching += 1 if arm.reaching else 0
	_since_grip += dt
	var gap := REACH_GAP * sqrt(s) * (0.5 if turning else 1.0)
	var behind := _lag.length() > _max_lag(hip_w) * 0.7  # falling far behind: grab now
	var walkers := _walkers(root, heading)
	var may_reach := reaching < MAX_REACHING and (_since_grip > gap or behind)
	var pick: Arm = null  # the free front arm that has waited longest reaches next
	for arm: Arm in arms:
		arm.chain.ground = ground + 0.1 * s
		var base := arm.chain.pos[0] if arm.chain.pos.size() > 0 else root.origin
		if arm.holding:
			_hold(arm, root, dt)
			continue
		if arm.gripping:
			_maybe_release(arm, root, base)
		var free := not arm.gripping and not arm.reaching
		arm.idle = arm.idle + dt if free else 0.0
		if free and moving and arm in walkers:
			if pick == null or arm.idle > pick.idle:
				pick = arm
		elif free and not moving and may_reach and _wants_grip(arm, root):
			_reach(arm, root, base)
		if arm.reaching:
			_advance_reach(arm, dt)
		var want := 1.0
		if arm.gripping:
			arm.chain.pins = {arm.chain.names.size(): arm.grip}
			want = clampf(
				(arm.grip - base).length() / (arm.length * s * GRIP_SLACK), CONTRACT_MIN, 1.0
			)
		arm.chain.contract = lerpf(arm.chain.contract, want, minf(1.0, dt * 10.0))
		_curl(arm, moving)
	if pick != null and may_reach:
		_reach(pick, root, pick.chain.pos[0] if pick.chain.pos.size() > 0 else root.origin)
	_pose_mantle(dt, root, moving)
	rig.simulate_chains(delta)


## Drag and surge: between grips the body lags behind the sim, sliding slower; after a grip
## it surges to catch up. The body's lag is held as a world offset of the rig.
func _crawl(dt: float, hip_w: float, moving: bool) -> void:
	var frame := rig.get_parent_node_3d().global_transform
	_surge = maxf(0.0, _surge - dt)
	if moving:
		_lag += velocity * (1.0 - DRAG) * dt
	if _surge > 0.0 or not moving:
		_lag *= maxf(0.0, 1.0 - SURGE_RATE * dt)
	_lag.y = 0.0
	_lag = _lag.limit_length(_max_lag(hip_w))
	rig.position = frame.basis.inverse() * -_lag


func _maybe_release(arm: Arm, root: Transform3D, base: Vector3) -> void:
	var moving := _moving
	var turning := _turning
	var heading := velocity.normalized() if speed > 0.05 else Vector3.ZERO
	var stretch := (arm.grip - base).length() / (arm.length * s)
	var behind := (arm.grip - root.origin).dot(heading) / (arm.length * s)
	if stretch > RELEASE_STRETCH or (not moving and not arm.on_building and stretch > 0.9):
		_release(arm)
	elif moving and (behind < -PUSH_UNTIL or stretch < CONTRACT_MIN or (turning and behind < 0.0)):
		_release(arm)  # it has pushed the body past: peel off and trail


## A reaching arm arcs to its target; on arrival it slaps down, grips, and the body surges.
func _advance_reach(arm: Arm, dt: float) -> void:
	arm.t = minf(1.0, arm.t + dt / (REACH_SECONDS * sqrt(s)))
	var e := arm.t * arm.t * (3.0 - 2.0 * arm.t)
	var p := arm.from.lerp(arm.to, e)
	p.y += sin(PI * arm.t) * REACH_ARC * hip_height * s * 2.0
	arm.chain.pins = {arm.chain.names.size(): p}
	if arm.t < 1.0:
		return
	arm.reaching = false
	arm.gripping = true
	arm.grip = arm.to
	_pull_v += SLAP  # a slap: the body lurches toward the new grip
	_slam = maxf(_slam, 0.6)
	_surge = SURGE * sqrt(s)
	_since_grip = 0.0
	var stage := clampf(sqrt(s / 1.3), 0.4, 1.0)
	rig.foot_planted.emit("t%d" % arms.find(arm), GRIP_WEIGHT * stage, arm.grip)


func _max_lag(hip_w: float) -> float:
	return maxf(MAX_LAG * hip_w, speed * MAX_LAG_SECONDS)


## The arms that walk: the LEAD_ARMS rooted nearest the heading (within LEAD_ARC of it).
func _walkers(root: Transform3D, heading: Vector3) -> Array[Arm]:
	var ranked: Array[Arm] = []
	for arm: Arm in arms:
		if _out(arm, root).dot(heading) > cos(LEAD_ARC):
			ranked.append(arm)
	ranked.sort_custom(
		func(a: Arm, b: Arm) -> bool: return _out(a, root).dot(heading) > _out(b, root).dot(heading)
	)
	return ranked.slice(0, LEAD_ARMS)


## Which way an arm points out from the body (world, flat).
func _out(arm: Arm, root: Transform3D) -> Vector3:
	var out := root.basis * Vector3(sin(arm.angle), 0, -cos(arm.angle))
	return Vector3(out.x, 0, out.z).normalized()


func stomp() -> void:
	_slam = 1.0
	for arm: Arm in arms:
		if not arm.gripping:
			arm.chain.kick(Vector3(0, -10, 0) * s, 1.0 / 60.0)


## Tentacle Lash: every arm lets go and whips around the body.
func roar() -> void:
	_lash = 1.0
	for arm: Arm in arms:
		_release(arm)
		var side := Vector3(cos(arm.angle), 0, sin(arm.angle))
		arm.chain.kick(rig.global_transform.basis * (side * 30.0 + Vector3(0, 8, 0)), 1.0 / 60.0)


## Reach a tentacle (limb_hint picks one; below 0, the one nearest `at`) to `at` and hold on.
func grab(limb_hint: int, at: Vector3) -> void:
	if arms.is_empty():
		return
	var arm := arms[posmod(limb_hint, arms.size())]
	if limb_hint < 0:
		for a: Arm in arms:
			if a.chain.pos.size() > 0 and arm.chain.pos.size() > 0:
				var d := (a.chain.pos[-1] - at).length()
				if d < (arm.chain.pos[-1] - at).length():
					arm = a
	_release(arm)
	arm.from = arm.chain.pos[-1] if arm.chain.pos.size() > 0 else at
	arm.to = at
	arm.t = 0.0
	arm.holding = true


## Hurl whatever the holding tentacle has, toward a point.
func throw(toward: Vector3) -> void:
	for arm: Arm in arms:
		if arm.holding:
			_release(arm)
			var tip := arm.chain.pos[-1] if arm.chain.pos.size() > 0 else toward
			arm.chain.kick((toward - tip).normalized() * THROW_SPEED * s, 1.0 / 60.0)
			_pull_v -= SLAP


## World position of a tentacle's tip (to carry a grabbed thing), or the body if there is none.
func limb_tip(limb_hint: int) -> Vector3:
	for arm: Arm in arms:
		if arm.holding:
			return arm.chain.pos[-1]
	if arms.is_empty() or arms[0].chain.pos.is_empty():
		return rig.global_position
	return arms[posmod(limb_hint, arms.size())].chain.pos[-1]


## A holding tentacle: reach to the thing, then lift it high over the body, coiled round it.
func _hold(arm: Arm, root: Transform3D, dt: float) -> void:
	arm.t = minf(2.0, arm.t + dt / (GRAB_SECONDS * sqrt(s)))
	var high := root.origin + Vector3.UP * HOLD_HEIGHT * hip_height * s
	var p := arm.from.lerp(arm.to, minf(1.0, arm.t))
	if arm.t > 1.0:
		p = arm.to.lerp(high, arm.t - 1.0)
	arm.chain.pins = {arm.chain.names.size(): p}
	arm.chain.contract = lerpf(arm.chain.contract, 0.8, minf(1.0, dt * 6.0))


func _release(arm: Arm) -> void:
	arm.holding = false
	arm.gripping = false
	arm.reaching = false
	arm.on_building = false
	arm.chain.pins = {}


func _reach(arm: Arm, root: Transform3D, base: Vector3) -> void:
	var out := root.basis * Vector3(sin(arm.angle), 0, -cos(arm.angle))
	out = Vector3(out.x, 0, out.z).normalized()
	var ahead := velocity.normalized() if speed > 0.05 else out
	# Every arm reaches forward of where it starts: front arms straight out ahead, back arms
	# along the flank, so the whole ring hauls the body and pushes once it is passed.
	var front := clampf(out.dot(ahead), -1.0, 1.0)
	var dir := (out * (0.6 + 0.4 * front) + ahead * AIM_AHEAD).normalized()
	var target := base + dir * arm.length * s * AIM_REACH
	target.y = root.origin.y
	arm.on_building = false
	if grip_finder.is_valid():
		var edge: Vector3 = grip_finder.call(target, arm.length * s * GRIP_RADIUS * 0.5)
		if edge.is_finite() and (edge - base).length() < arm.length * s * 0.95:
			target = edge
			arm.on_building = true
	arm.from = arm.chain.pos[arm.chain.pos.size() - 1] if arm.chain.pos.size() > 0 else base
	arm.to = target
	arm.t = 0.0
	arm.reaching = true


## Standing still, an arm reaches only for a building edge close by (to wrap it).
func _wants_grip(arm: Arm, root: Transform3D) -> bool:
	if not grip_finder.is_valid() or rng.randf() > 0.02:
		return false
	var out := root.basis * Vector3(sin(arm.angle), 0, -cos(arm.angle))
	var probe := root.origin + out.normalized() * arm.length * s * 0.6
	var edge: Vector3 = grip_finder.call(probe, arm.length * s * 0.5)
	return edge.is_finite()


## A free arm curls and gropes; a gripping arm coils slightly around its hold.
func _curl(arm: Arm, moving: bool) -> void:
	var n := arm.chain.drive.size()
	var amount := GROPE * (0.35 if moving else 1.0) * (1.0 + _lash)
	if arm.gripping or arm.reaching:
		amount = 0.3 if arm.on_building else 0.03
	for i: int in n:
		var wave := sin(time * TAU * GROPE_HZ * (1.0 + ROAR_RIPPLE * _lash) + arm.phase - i * 0.7)
		var curl := (wave * amount + amount * 0.6) * (float(i + 1) / n)
		var twist := sin(time * 1.3 + arm.phase + i) * 0.1
		arm.chain.drive[i] = Basis(Vector3.RIGHT, -curl) * Basis(Vector3.UP, twist)


func _pose_mantle(dt: float, root: Transform3D, moving: bool) -> void:
	# The body stretches toward its grip in a surge and eases back as it drags.
	var target := clampf(_surge / (SURGE * sqrt(s)), 0.0, 1.0) if moving else 0.0
	var p := spring(_pull, _pull_v, target, 7.0, 0.5, dt)
	_pull = p.x
	_pull_v = p.y
	_slam = maxf(0.0, _slam - dt * 4.0)
	_lash = maxf(0.0, _lash - dt * 1.5)
	var local_v := root.basis.inverse() * velocity / maxf(0.001, s)
	var drag := Vector2(local_v.z, -local_v.x) * DRAG_TILT / maxf(0.5, hip_height)
	var tp := spring(_tilt.x, _tilt.y, drag.x, 6.0, 0.7, dt)
	_tilt = tp
	var breath := sin(time * TAU * BREATH_HZ) * BREATH + _lash * ROAR_PUFF
	var squash := _slam * 0.3 - _pull * STRETCH * 0.5
	var low := -0.08 * hip_height * (1.0 - _pull) if moving else 0.0  # sliding low between grips
	rig.pose(
		"mantle0",
		Vector3(_tilt.x + _lash * 0.3 * sin(time * 20.0), _lash * sin(time * 9.0) * 0.6, drag.y),
		Vector3(0, low - _slam * 0.3, -_pull * STRETCH)
	)
	if _mantle != null:
		_mantle.scale = Vector3(
			1.0 + breath + squash * 0.6, 1.0 + breath - squash, 1.0 + breath * 0.5 + _pull * STRETCH
		)
