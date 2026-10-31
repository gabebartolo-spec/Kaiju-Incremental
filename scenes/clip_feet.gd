class_name ClipFeet
extends RefCounted
## Where a clip-driven kaiju's (ClipGait) toes go this frame: a planted foot holds its spot in
## the world, a lifted one follows its clip path from where it left the ground (SwingPath), a foot
## left behind takes a catch step (ClipStomp). A foot whose spot moves under it mid-swing eases
## onto it instead of jumping: the Colossus teleported 6.6 m in a frame (director 2026-11-01).

## A lifted foot whose clip spot jumps (a clip change, the sim's step length changing mid-swing)
## eases onto it at this rate (1/s).
const SHIFT_EASE := 6.0


## Foot i's toe this frame (world; down: leg.planted): a catch step, its lock, or its air path.
static func target(g: ClipGait, i: int, pose: KaijuClips.Pose, dt: float) -> Vector3:
	var clip_toe := g.rig.global_transform * g._stepped(g.clips.to_rig(pose.feet[i]))
	var cut := g.state == "walk" and g._from == "walk_start" and g.step_ratio != g._ratio_was
	g._cut[i] = g._cut[i] or cut
	var planted := pose.planted[i] and not g._stomp.catching(i)
	if _restepped(g, i, planted, clip_toe):
		planted = false
	var toe: Vector3
	if g._stomp.catching(i):
		var k := g._stomp.advance(i, dt)
		g._lag[i] *= 1.0 - smoothstep(0.0, 1.0, k)
		toe = clip_toe + g._lag[i] + Vector3.UP * g._stomp.rise(i, k) * g.hip_height * g.s
		if not g._stomp.catching(i):  # on the street this frame: it plants now, not a frame on
			planted = pose.planted[i]
			toe = put_down(g, i, toe, clip_toe) if planted else toe
	elif planted:
		toe = _land(g, i, clip_toe)
	else:
		toe = _swing(g, i, dt, clip_toe)
	g.legs[i].planted = planted
	g._cut[i] = false
	if planted:
		g._shift[i] = Vector3.ZERO
	g._was_planted[i] = planted
	g._restep.update(i, planted)
	return toe


## A planted foot the body got away from steps after it (ClipStomp.restep): true if so.
static func _restepped(g: ClipGait, i: int, planted: bool, clip_toe: Vector3) -> bool:
	if planted and g._was_planted[i] and g._restep.overreached(g, i, g._lock[i], clip_toe):
		g._stomp.restep(i)
		return true
	return false


## A foot the clip has down: it lands where it was going; an eased swing lands where it is.
static func _land(g: ClipGait, i: int, clip_toe: Vector3) -> Vector3:
	var toe := g._path.down(i, clip_toe + g._lag[i] + g._shift[i])
	if not g._was_planted[i] and g._shift[i] != Vector3.ZERO:
		toe = g._path.down(i, g._air_at[i])
	return put_down(g, i, toe, clip_toe)


## A lifted foot: its air path from where it left the ground, plus a jump in its spot easing out.
static func _swing(g: ClipGait, i: int, dt: float, clip_toe: Vector3) -> Vector3:
	g._stomp.forget(i)
	if g._was_planted[i]:
		g._path.lift(g, i, clip_toe, g._lock[i])
	var toe := g._path.target(g, i, dt, clip_toe)
	if g._cut[i] and not g._was_planted[i]:  # its spot moved: swing on from where it is, never jump
		g._shift[i] = g._air_at[i] - toe
	g._shift[i] *= exp(-SHIFT_EASE * dt)
	toe += g._shift[i]
	g._air_at[i] = toe
	g._lag[i] = g._path.lag[i]
	return toe


## A foot the clip has down: it locks where it lands, its footfall goes out; returns its spot.
static func put_down(g: ClipGait, i: int, toe: Vector3, clip_toe: Vector3) -> Vector3:
	var leg := g.legs[i]
	if not g._was_planted[i]:
		g._lock[i] = toe
		g._plant_heading[i] = g._hold.foot_yaw(leg)
		leg.plant_at = toe
		leg.drift = 0.0
		var strength := g._stomp.landing(i, clampf(0.2 + g.speed_k(), 0.0, 1.0), g.s)
		if g._feet_primed:  # the first frame's feet were already down: no step, no ring
			g.rig.foot_planted.emit("left" if leg.side < 0.0 else "right", strength, toe)
	g._lag[i] = g._lock[i] - clip_toe
	return g._lock[i]
