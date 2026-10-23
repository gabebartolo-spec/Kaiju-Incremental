class_name SerpentWeave
extends RefCounted
## The serpent's S-wave, drawn over the sim's centreline (D-198 "Wide, ~6 m each side";
## data/tuning.json "serpent"). A drawn head chases a point that swings amplitude x
## sin(2 pi s / wave_length) to each side of the sim's head path (s: the distance the sim head has
## travelled), wave_lookahead m ahead of it, turning at most to a bend of min_bend_widths body
## widths; the drawn head records its own path by distance (a SerpentTrail) and the drawn body lies
## along that. So the S belongs to the ground, not to the body: every body point passes through the
## same S (Jayne 2020, terrestrial lateral undulation: points follow one path and the wave runs at
## the forward speed), no bend is ever tighter than the limit, a tight turn flattens the S on its
## own, and a stopped serpent keeps its S, frozen. The swing ramps in with speed (eased over
## wave_ease m of travel). Presentation only: one per drawn serpent, stepped with the sim.

## How hard the drawn head closes a gap along the sim head's way (per lookahead length).
const CATCH_UP := 1.0
## The drawn head's speed stays within this many times the sim head's.
const MOST_SPEED := 2.5

## The drawn head's own path; its head is the drawn head.
var drawn: SerpentTrail
var _cfg: Dictionary
var _amp := 0.0


func _init(body: SerpentBody) -> void:
	_cfg = body.cfg
	var reach := body.length() * 1.25
	drawn = SerpentTrail.new(body.trail.spacing, reach, body.pos, body.heading)


## How far the S swings at a crest where the head goes at `speed`: it ramps in with speed (full
## at wave_full_at of top speed, none at rest).
static func amplitude(cfg: Dictionary, speed: float) -> float:
	var full := Num.f(cfg["speed"]) * Num.f(cfg["wave_full_at"])
	return Num.f(cfg["wave_amp"]) * smoothstep(0.0, full, speed)


## The sideways offset at arc position `s` for a crest of `amp`.
static func lateral(cfg: Dictionary, s: float, amp: float) -> float:
	return amp * sin(TAU * s / Num.f(cfg["wave_length"]))


## One step of `dt` after the sim body stepped: the drawn head follows its swinging target.
func step(body: SerpentBody, dt: float) -> void:
	var v := body.speed
	if v <= 0.0 or dt <= 0.0:
		return
	var ahead := Num.f(_cfg["wave_lookahead"])
	_amp = lerpf(_amp, amplitude(_cfg, v), 1.0 - exp(-v * dt / Num.f(_cfg["wave_ease"])))
	var swing := lateral(_cfg, body.trail.head_s + ahead, _amp)
	var target := body.pos + body.heading * ahead + body.heading.orthogonal() * swing
	var at := drawn.head
	var facing := drawn.head_heading
	var to := target - at
	var bend := 2.0 * sin(facing.angle_to(to)) / maxf(to.length(), 0.001)  # pure pursuit
	var most := 1.0 / (Num.f(_cfg["min_bend_widths"]) * Num.f(_cfg["head_width"]))
	bend = clampf(bend, -most, most)
	var behind := (body.pos - at).dot(body.heading)  # > 0: the drawn head is behind the sim's
	var lean := maxf(facing.dot(body.heading), 0.3)  # a drawn head across the way goes faster
	var u := clampf(v * (1.0 + CATCH_UP * behind / ahead) / lean, 0.0, MOST_SPEED * v)
	var heading := facing.rotated(bend * u * dt)
	drawn.advance(at + heading * u * dt, heading, u, bend * u)


## The drawn path, head first: the drawn head, then its samples back until `reach` of path is
## covered (or the trail runs out). Ground plane (x, z).
func path(reach: float) -> PackedVector2Array:
	var out := PackedVector2Array([drawn.head])
	var covered := 0.0
	var n := drawn.last()
	while n >= drawn.first() and covered < reach:
		var p := drawn.point(n)
		covered += p.distance_to(out[out.size() - 1])
		out.append(p)
		n -= 1
	return out


## `count` + 1 joints `spacing` apart along `points` (head first): joint 0 is the head's tip.
## Past the path's end the body carries on straight.
static func joints(points: PackedVector2Array, spacing: float, count: int) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	var i := 0
	var into := 0.0  # how far along points[i] -> points[i + 1] the last joint sits
	for _k: int in count:
		var need := spacing
		while i + 1 < points.size():
			var seg := points[i].distance_to(points[i + 1]) - into
			if seg >= need:
				into += need
				need = 0.0
				break
			need -= seg
			i += 1
			into = 0.0
		var last := points.size() - 1
		var from := points[mini(i, last)]
		var to := points[mini(i + 1, last)]
		var dir := (to - from).normalized() if from.distance_to(to) > 0.0 else _tail_dir(points)
		out.append(from + dir * (into + need))
		into += need
	return out


static func _tail_dir(points: PackedVector2Array) -> Vector2:
	var n := points.size()
	if n < 2:
		return Vector2(0, 1)
	return (points[n - 1] - points[n - 2]).normalized()
