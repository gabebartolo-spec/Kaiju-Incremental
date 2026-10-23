class_name SerpentCoil
extends RefCounted
## The shape the serpent draws itself into when it stops (director D-210: "snake curls up into a
## defensive position"): the body stacked in a tight coil, a few loops high with the tail tucked
## in at the bottom, and from the top of the pile the head and neck rise and draw back in an S,
## ready to strike. The head stays where the sim's head stopped, facing the way it was going, so
## nothing travels; the coil sits beside and just behind it, on the side the body already lay.
## Built from the head back, a joint at a time: the neck (coil_neck m, an S in the ground plane,
## rising coil_head_rise m above the pile), then a spiral from the pile's top (radius coil_radius,
## shrinking coil_shrink per loop, each loop coil_rise m above the next). Pure geometry
## (data/tuning.json "serpent"); presentation only.


## The coil for a body `seg` m per joint, the head at `points[0]` facing `heading`, with the
## chain of `count` + 1 joints: [joints (ground plane), heights (m above the ground)].
static func target(
	points: PackedVector2Array, heading: Vector2, seg: float, cfg: Dictionary
) -> Array:
	var f := heading.normalized()
	var v := f.orthogonal()
	var head := points[0]
	var side := _side(points, head, v)
	var neck := Num.f(cfg["coil_neck"])
	var plan := neck * Num.f(cfg["coil_neck_plan"])
	var radius := Num.f(cfg["coil_radius"])
	var rim := head - f * plan  # where the neck meets the top of the pile
	var centre := rim - v * (side * radius)
	var e1 := v * side  # from the centre toward the rim
	var e2 := -f  # the way the body circulates at the rim: backward
	var out := PackedVector2Array()
	var height := PackedFloat32Array()
	var angles := PackedFloat32Array()
	var psi := 0.0
	var last := points.size() - 1
	for j: int in last + 1:
		var d := j * seg
		if d <= neck + 0.0001:
			var x := 1.0 - d / neck  # 0 at the pile, 1 at the snout
			var wave := Num.f(cfg["coil_neck_s"]) * sin(TAU * x)
			out.append(rim + f * (plan * x) + v * wave)
			height.append(0.0)
			angles.append(0.0)
			continue
		var r := maxf(radius - Num.f(cfg["coil_shrink"]) * psi / TAU, seg)
		psi += 2.0 * asin(minf(seg / (2.0 * r), 1.0))  # a chord of one joint spacing
		out.append(centre + (e1 * cos(psi) + e2 * sin(psi)) * r)
		height.append(0.0)
		angles.append(psi)
	var total := angles[last]
	var rise := Num.f(cfg["coil_rise"])
	var pile := rise * total / TAU
	for j: int in last + 1:
		var d := j * seg
		if d <= neck + 0.0001:
			var up := smoothstep(neck, neck * 0.3, d)
			height[j] = pile + Num.f(cfg["coil_head_rise"]) * up
		else:
			height[j] = rise * (total - angles[j]) / TAU
	return [out, height]


## Which way the body lies from the head's line (+1 / -1 along `v`): the side most of its first
## 30 m is on, so the coil forms where the body already is.
static func _side(points: PackedVector2Array, head: Vector2, v: Vector2) -> float:
	var sum := 0.0
	for j: int in range(4, mini(points.size(), 31)):
		sum += (points[j] - head).dot(v)
	return -1.0 if sum < 0.0 else 1.0


## The most any joint of `joints` is from `centre` (m): the coil's reach.
static func reach(joints: PackedVector2Array, centre: Vector2) -> float:
	var most := 0.0
	for p: Vector2 in joints:
		most = maxf(most, p.distance_to(centre))
	return most
