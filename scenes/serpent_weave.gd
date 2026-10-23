class_name SerpentWeave
extends RefCounted
## The serpent's S-wave, drawn over the sim's centreline (D-198 "Wide, ~6 m each side";
## data/tuning.json "serpent"). A serpenoid (Hirose's curve, the snake robots' standard): a drawn
## head whose heading swings about the sim head's course by alpha x cos(2 pi s / wave_length),
## s its own distance travelled, alpha set so the path swings wave_amp m to each side; a
## gentle pull (wave_pull per m off) holds it to that swing about the sim's centreline, and it never
## bends tighter than min_bend_widths body widths. It records its path by distance (a
## SerpentTrail) and the drawn body lies along that: every body point passes through the same S
## (Jayne 2020, terrestrial lateral undulation: points follow one path and the wave runs at the
## forward speed). The swing ramps in with speed (eased over wave_ease m of travel), is kept while
## slowing, and gives way in a turn to what the bend limit leaves. Presentation only: one per drawn
## serpent, stepped with the sim.

## The drawn head's speed stays within this many times the sim head's.
const MOST_SPEED := 2.5
## The bend limit is held this much under min_bend_widths: the body's joints, a polyline laid along
## the drawn path, read about 1% tighter than the path's own bend.
const BEND_MARGIN := 0.96
## Bisection steps that find the heading swing for the ruled sideways swing.
const SOLVE_STEPS := 30

## The drawn head's own path; its head is the drawn head.
var drawn: SerpentTrail
var _cfg: Dictionary
var _ramp := 0.0  # 0..1: how much of the full swing is being laid now
var _alpha := 0.0  # the heading swing (rad) that lays the full sideways swing


func _init(body: SerpentBody) -> void:
	_cfg = body.cfg
	var reach := body.length() * 1.25
	drawn = SerpentTrail.new(body.trail.spacing, reach, body.pos, body.heading)
	_alpha = heading_swing(Num.f(_cfg["wave_amp"]), TAU / Num.f(_cfg["wave_length"]))


## How far the S swings at a crest where the head goes at `speed`: it ramps in with speed (full
## at wave_full_at of top speed, none at rest).
static func amplitude(cfg: Dictionary, speed: float) -> float:
	var full := Num.f(cfg["speed"]) * Num.f(cfg["wave_full_at"])
	return Num.f(cfg["wave_amp"]) * smoothstep(0.0, full, speed)


## The sideways offset at arc position `s` for a crest of `amp`.
static func lateral(cfg: Dictionary, s: float, amp: float) -> float:
	return amp * sin(TAU * s / Num.f(cfg["wave_length"]))


## The heading swing alpha whose serpenoid (wave number k) swings `amp` to each side: the side
## reach of a quarter wave is (1/k) x the integral over 0..pi/2 of sin(alpha cos u) du.
static func heading_swing(amp: float, k: float) -> float:
	var lo := 0.0
	var hi := PI * 0.5
	for _i: int in SOLVE_STEPS:
		var mid := (lo + hi) * 0.5
		if side_reach(mid, k) < amp:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## How far a serpenoid with heading swing `alpha` (wave number k) reaches to each side.
static func side_reach(alpha: float, k: float) -> float:
	var steps := 32  # Simpson's rule over a quarter wave
	var h := PI * 0.5 / steps
	var sum := 0.0
	for i: int in steps + 1:
		var w := 1.0 if i == 0 or i == steps else (4.0 if i % 2 == 1 else 2.0)
		sum += w * sin(alpha * cos(i * h))
	return sum * h / 3.0 / k


## How far forward a serpenoid with heading swing `alpha` goes per metre of its path: the mean of
## cos(alpha cos u) over a wave.
static func progress(alpha: float) -> float:
	var steps := 32  # Simpson's rule over a quarter wave
	var h := PI * 0.5 / steps
	var sum := 0.0
	for i: int in steps + 1:
		var w := 1.0 if i == 0 or i == steps else (4.0 if i % 2 == 1 else 2.0)
		sum += w * cos(alpha * cos(i * h))
	return maxf(sum * h / 3.0 / (PI * 0.5), 0.3)


## One step of `dt` after the sim body stepped: the drawn head swings about the sim's course.
func step(body: SerpentBody, dt: float) -> void:
	var v := body.speed
	if v <= 0.0 or dt <= 0.0:
		return
	var full := smoothstep(0.0, Num.f(_cfg["speed"]) * Num.f(_cfg["wave_full_at"]), v)
	_ramp = lerpf(_ramp, maxf(full, _ramp), 1.0 - exp(-v * dt / Num.f(_cfg["wave_ease"])))
	var most := BEND_MARGIN / (Num.f(_cfg["min_bend_widths"]) * Num.f(_cfg["head_width"]))
	var k := TAU / Num.f(_cfg["wave_length"])
	# A turn's own bend uses up the bend limit: the swing keeps what is left of it.
	var left := clampf(1.0 - absf(body.spin / v) / most, 0.0, 1.0)
	var share := _ramp * minf(1.0, left * most / maxf(_alpha * k, 0.0001))
	# Short moves, at most a sample's spacing each, so the drawn path has no corners.
	var moves := ceili(MOST_SPEED * v * dt / drawn.spacing)
	for _i: int in moves:
		_advance(body, dt / moves, Vector3(most, k, share))


## One short move of the drawn head over `h` s; `lim`: (bend limit, wave number, swing share).
func _advance(body: SerpentBody, h: float, lim: Vector3) -> void:
	var v := body.speed
	var phase := lim.y * drawn.head_s
	var at := drawn.head
	var course := body.heading
	var side := (at - body.pos).dot(course.orthogonal())
	var off := Num.f(_cfg["wave_amp"]) * lim.z * sin(phase) - side
	var pull := 0.5 * tanh(Num.f(_cfg["wave_pull"]) * off / 0.5)  # eased, never a corner
	var swing := -_alpha * lim.z * cos(phase) - pull
	var facing := drawn.head_heading
	var behind := (body.pos - at).dot(course)  # > 0: the drawn head is behind the sim's
	# Every point slides along the S at one steady speed (a snake's body does not surge): the
	# forward speed over the S's mean progress per metre of path, eased level with the sim head.
	var catch_up := 1.0 + behind / Num.f(_cfg["wave_catch"])
	var u := clampf(v * catch_up / progress(_alpha * lim.z), 0.0, MOST_SPEED * v)
	# The bend wanted to face the new way within wave_settle m, held softly (tanh) under the
	# limit, so the bend never jumps where the limit takes over.
	var bend := facing.angle_to(course.rotated(swing)) / Num.f(_cfg["wave_settle"])
	var turn := lim.x * tanh(bend / lim.x) * u * h
	var heading := facing.rotated(turn)
	drawn.advance(at + heading * u * h, heading, u, turn / h)


## The drawn body settled into `points` (joints, head first) while it stood: its path is laid
## again along them, so it sets off from the shape it settled in.
func settle_into(points: PackedVector2Array) -> void:
	drawn.relay(points)


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
