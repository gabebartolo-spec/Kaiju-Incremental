class_name RadialWalkers
extends RefCounted
## Which of RadialGait's arms walk (split out of gait_radial.gd to keep files small): the
## LEAD_ARMS rooted nearest the heading, within LEAD_ARC of it. Presentation only.


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
