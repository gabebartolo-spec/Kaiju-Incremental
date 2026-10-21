class_name FallContact
extends RefCounted
## Where a falling part meets the kaiju's body (director comments #24: "when collapsing buildings
## fall upon the kaiju, they just clip right through him. they should break upon impact"). The
## body is BodyContact's discs as world cylinders; a topple's leading face is the plane through
## its pivot edge, turned by the same lean curve the view draws (tilt), so the sim's contact is
## where the drawn tower touches him. Pure, deterministic, no RNG.


## The topple's lean (radians from upright) t seconds into a fall the sim times at `duration`:
## a shudder that creeps to lean_deg, then a lean that accelerates (sinh, like a tipping column)
## to 90 degrees exactly when the sim lands it. cfg: the "topple_fx" tuning (empty: gravity's
## plain k squared). ToppleFx draws this curve.
static func tilt(cfg: Dictionary, t: float, duration: float) -> float:
	if cfg.is_empty():
		var k := clampf(t / maxf(0.001, duration), 0.0, 1.0)
		return PI * 0.5 * k * k
	var shudder := minf(Num.f(cfg["shudder_s"]), duration * Num.f(cfg["shudder_max_share"]))
	var lean := deg_to_rad(Num.f(cfg["lean_deg"]))
	if t < shudder:
		var k := t / shudder
		var wobble := (
			sin(t * TAU * Num.f(cfg["shudder_hz"])) * deg_to_rad(Num.f(cfg["shudder_deg"]))
		)
		return lean * k * k + wobble * (1.0 - k * 0.5)
	var u := clampf((t - shudder) / maxf(0.001, duration - shudder), 0.0, 1.0)
	var c := Num.f(cfg["lean_curve"])
	return lean + (PI * 0.5 - lean) * sinh(c * u) / sinh(c)


## A toppling part's first touch of the body at lean `angle`, or {} if none: "s" how far from
## the pivot edge (along the fall) the face meets the body, "crack" how far up the tower (along
## its own axis) that is, "at" the world contact point, "side" (+1 or -1) which side of the
## tower's centre line the body stands (0: on it), "radius" the touching disc's radius.
## discs: BodyContact.world_discs(); half_width: half the tower's width across the fall.
static func topple(f: RampageSim.Fall, angle: float, half_width: float, discs: Array) -> Dictionary:
	if angle <= 0.0:
		return {}
	var start := Vector2(f.pivot.x, f.pivot.z)
	var across := Vector2(-f.dir.y, f.dir.x)
	var reach := f.height * sin(angle)  # how far out the top is now
	var cot := cos(angle) / sin(angle)
	var low := f.pivot.y
	var best := {}
	for d: Array in discs:
		var c: Vector2 = d[0]
		var r := Num.f(d[1])
		var rel := c - start
		var lateral := rel.dot(across)
		if absf(lateral) > half_width + r:
			continue
		var s := maxf(0.05, rel.dot(f.dir) - r)
		if rel.dot(f.dir) + r <= 0.0 or s > reach:
			continue  # behind the pivot edge, or beyond the top
		var face := low + s * cot
		if face > Num.f(d[3]) or low + f.height < Num.f(d[2]):
			continue
		if best.is_empty() or s < Num.f(best["s"]):
			var side := signf(lateral) if absf(lateral) > 0.01 else 0.0
			best = {
				"s": s,
				"crack": minf(f.height, s / sin(angle)),
				"at": Vector3(start.x + f.dir.x * s, face, start.y + f.dir.y * s),
				"side": side,
				"radius": r,
				"centre": c,
			}
	return best


## A dropping part's first touch of the body, or {}: "at" the contact point on the body's top.
## bottom: the part's lowest point now (world y); feet: its chunks' world centres.
static func drop(bottom: float, height: float, feet: Array[Vector3], discs: Array) -> Dictionary:
	for d: Array in discs:
		if bottom > Num.f(d[3]) or bottom + height < Num.f(d[2]):
			continue
		var c: Vector2 = d[0]
		var r := Num.f(d[1])
		for p: Vector3 in feet:
			var gap := Vector2(maxf(absf(p.x - c.x) - 0.5, 0.0), maxf(absf(p.z - c.y) - 0.5, 0.0))
			if gap.length() < r:
				return {"at": Vector3(p.x, Num.f(d[3]), p.z), "centre": c, "radius": r}
	return {}
