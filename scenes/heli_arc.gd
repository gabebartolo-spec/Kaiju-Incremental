class_name HeliArc
extends RefCounted
## The fall of a shot-down helicopter as the view draws it (D-140, lead ruling 2026-10-23): an
## authored arc from the sim's death point to the sim's crash point, in the sim's crash time (1.4 s,
## air.fall_seconds: a real fall, so the view has nothing to fill). The sim decides where it dies,
## where and when it crashes; this decides how it looks on the way: a pop up and shove away (a few
## frames), then a ballistic fall from rest at the top (height falls as t squared, so it only ever
## accelerates and meets the street at speed), spinning about its mast with the nose dipping. The
## sideways travel is front-loaded (done by `slide_share` of the fall), so the last frames drop
## straight down and the screen descent is not cancelled by drift. Pure functions of time, so a
## test can check them against the sim. Numbers: tuning "heli_wreck" (pop_seconds, pop_height,
## slide_share, swing, fall_turns, pitch_deg, roll_deg). Presentation only.


## Where the hull is `t` seconds after it died: `from` the death point (at the sim's altitude),
## `drift` the sim's ground drift per second, `side` the unit direction its path bows toward,
## `seconds` the sim's fall time. At t = seconds this is exactly from + drift x seconds on the
## street (the crash).
static func point(
	from: Vector3, drift: Vector3, side: Vector3, seconds: float, t: float, cfg: Dictionary
) -> Vector3:
	var now := clampf(t, 0.0, seconds)
	var pop := Num.f(cfg["pop_seconds"])
	var slide := seconds * Num.f(cfg["slide_share"])
	var h := clampf(now / slide, 0.0, 1.0)  # sideways: fast at first (the swat's shove), easing out
	var along := 1.0 - (1.0 - h) * (1.0 - h)
	var ground := from + drift * seconds * along + side * sin(PI * h) * Num.f(cfg["swing"])
	var apex := from.y + Num.f(cfg["pop_height"])
	var height := 0.0
	if now < pop:  # the pop: up, easing out to the top
		height = from.y + Num.f(cfg["pop_height"]) * sin(0.5 * PI * now / pop)
	else:  # ballistic from rest at the top: gravity, meeting the street at the sim's crash time
		var s := (now - pop) / maxf(seconds - pop, 0.001)
		height = apex * (1.0 - s * s)
	return Vector3(ground.x, maxf(height, 0.0), ground.z)


## The hull's yaw about its mast `t` seconds after it died: fall_turns full turns by the crash,
## slow at first and faster as it falls.
static func yaw(seconds: float, t: float, cfg: Dictionary) -> float:
	var u := clampf(t / seconds, 0.0, 1.0)
	return TAU * Num.f(cfg["fall_turns"]) * (0.3 * u + 0.7 * u * u)


## The hull's orientation: yaw about the mast, banked from the first frames (swung out by the
## swat, then rocking), the nose dipping more as it falls.
static func basis(seconds: float, t: float, cfg: Dictionary) -> Basis:
	var u := clampf(t / seconds, 0.0, 1.0)
	var bank := deg_to_rad(Num.f(cfg["roll_deg"]))
	var roll := bank * (1.0 - exp(-t / 0.12)) * cos(TAU * 0.75 * u)
	var dip := deg_to_rad(Num.f(cfg["pitch_deg"]))
	var pitch := -dip * (0.35 + 0.65 * pow(u, 1.2))
	return (
		Basis(Vector3.UP, yaw(seconds, t, cfg))
		* Basis(Vector3.RIGHT, pitch)
		* Basis(Vector3.BACK, roll)
	)
