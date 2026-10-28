class_name RadialWalkers
extends RefCounted
## RadialGait's arms (split out of gait_radial.gd to keep files small): each built from its
## spring chain, and which walk (the LEAD_ARMS rooted nearest the heading, within LEAD_ARC of
## it). Presentation only.


## An arm on a tentacle's spring chain: its feel, angle round the body, length and ripple phase
## (one draw from `rng`).
static func make_arm(
	rig: KaijuRig, chain: KaijuRig.SpringChain, rng: RandomNumberGenerator
) -> RadialGait.Arm:
	var arm := RadialGait.Arm.new()
	arm.chain = chain
	chain.stiffness = RadialGait.ARM_STIFFNESS
	chain.gravity_scale = RadialGait.ARM_GRAVITY
	var tip := rig.head_of(chain.names[-1]) + rig.dir_of(chain.names[-1])
	arm.angle = atan2(tip.x, -tip.z)
	for n: String in chain.names:
		arm.length += rig.dir_of(n).length()
	arm.phase = rng.randf() * TAU
	return arm


static func pick(
	arms: Array[RadialGait.Arm], root: Transform3D, heading: Vector3
) -> Array[RadialGait.Arm]:
	var ranked: Array[RadialGait.Arm] = []
	for arm: RadialGait.Arm in arms:
		if pointing(arm, root).dot(heading) > cos(RadialGait.LEAD_ARC):
			ranked.append(arm)
	ranked.sort_custom(
		func(a: RadialGait.Arm, b: RadialGait.Arm) -> bool:
			return pointing(a, root).dot(heading) > pointing(b, root).dot(heading)
	)
	return ranked.slice(0, RadialGait.LEAD_ARMS)


## Which way an arm points out from the body (world, flat).
static func pointing(arm: RadialGait.Arm, root: Transform3D) -> Vector3:
	var out := root.basis * Vector3(sin(arm.angle), 0, -cos(arm.angle))
	return Vector3(out.x, 0, out.z).normalized()
