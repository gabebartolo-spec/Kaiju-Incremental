class_name HeliArc
extends RefCounted
## The fall of a shot-down helicopter as the view draws it (D-140, lead ruling 2026-10-23): an
## authored arc from the sim's death point to the sim's crash point, in the sim's crash time. The
## sim decides where it dies, where and when it crashes; this decides how it looks on the way: a
## short pop up and back (no hover), then a gravity fall that only ever descends, spinning about
## its rotor mast 1-2 turns with the nose dipping. Pure functions of time, so a test can check them
## against the sim.
## Numbers: tuning "heli_wreck" (pop_seconds, pop_height, pop_back, fall_lead, fall_turns, swing,
## pitch_deg, roll_deg). Presentation only.


## Where the hull is `t` seconds after it died: `from` the death point (at the sim's altitude),
## `drift` the sim's ground drift per second, `side` the unit direction its path bows toward,
## `seconds` the sim's fall time. At t = seconds this is exactly from + drift x seconds on the
## street (the crash).
static func point(
	from: Vector3, drift: Vector3, side: Vector3, seconds: float, t: float, cfg: Dictionary
) -> Vector3:
	var now := clampf(t, 0.0, seconds)
	var pop := Num.f(cfg["pop_seconds"])
	var ground := from + drift * now + side * sin(PI * now / seconds) * Num.f(cfg["swing"])
	var apex := from.y + Num.f(cfg["pop_height"])
	var height := 0.0
	if now < pop:  # the pop: up and a little back, easing out to the top
		var k := sin(0.5 * PI * now / pop)
		height = from.y + Num.f(cfg["pop_height"]) * k
		ground -= drift.normalized() * Num.f(cfg["pop_back"]) * sin(PI * now / pop)
	else:  # the fall from rest at the top: a first push, then gravity
		var s := (now - pop) / maxf(seconds - pop, 0.001)
		var lead := Num.f(cfg["fall_lead"])
		height = apex * (1.0 - (lead * s + (1.0 - lead) * s * s))
	return Vector3(ground.x, height, ground.z)


## The hull's yaw about its mast `t` seconds after it died: fall_turns full turns by the crash,
## slow at first and faster as it falls.
static func yaw(seconds: float, t: float, cfg: Dictionary) -> float:
	var u := clampf(t / seconds, 0.0, 1.0)
	return TAU * Num.f(cfg["fall_turns"]) * (0.3 * u + 0.7 * u * u)


## The hull's orientation: yaw about the mast, the nose dipping and a little roll as it falls.
static func basis(seconds: float, t: float, cfg: Dictionary) -> Basis:
	var u := clampf(t / seconds, 0.0, 1.0)
	var pitch := -deg_to_rad(Num.f(cfg["pitch_deg"])) * pow(u, 1.2)
	var roll := deg_to_rad(Num.f(cfg["roll_deg"])) * sin(PI * u)
	return (
		Basis(Vector3.UP, yaw(seconds, t, cfg))
		* Basis(Vector3.RIGHT, pitch)
		* Basis(Vector3.BACK, roll)
	)
