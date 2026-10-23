class_name SerpentWeave
extends RefCounted
## The serpent's S-wave, drawn over the sim's centreline (D-198 "Wide, ~6 m each side";
## data/tuning.json "serpent"). The S is a serpenoid (Hirose's curve, the snake robots' standard:
## the heading swings by alpha x cos(2 pi s / wave_length), s the distance along the S, alpha set so
## it swings wave_amp m to each side) laid in the centreline's own frame: the drawn head sits at a
## point of the sim's centreline, pushed sideways along that point's own normal by the serpenoid's
## offset there. Through a turn the S therefore swings about the curve itself and keeps rippling
## behind the bend (round 4 swung it about the head's new heading and a turn pulled it into a
## straight leg). On a turn's inner side the offset gives way by wave_inner_give x the turn's
## bend x the offset, so the inner crest never folds; the outer crest keeps its full swing. The drawn head
## records its path by distance (a SerpentTrail) and the drawn body lies along that: every body
## point passes through the same S (Jayne 2020, terrestrial lateral undulation: points follow one
## path and the wave runs at the forward speed), at one steady speed along it. The swing ramps in
## with speed (eased over wave_ease m of travel) and is kept while slowing. Presentation only: one
## per drawn serpent, stepped with the sim.

## The drawn head's speed stays within this many times the sim head's.
const MOST_SPEED := 2.5
## Bisection steps that find the heading swing for the ruled sideways swing.
const SOLVE_STEPS := 30
## Points in the serpenoid's one-wave table (offset by distance along the centreline).
const TABLE := 256
## How far behind the sim head the drawn head is held (m along the centreline): on ground the head
## has already laid, so a turn the head is making now never shifts a point already drawn.
const LAG := 3.0
## ...and never nearer it than this (m), whatever the S's stretch.
const LAG_LEAST := 1.0
## How far ahead along the centreline the drawn head steers for the S (m).
const LOOK := 1.5
## The bend limit is held this much under min_bend_widths: the body's joints, a polyline laid along
## the drawn path, read a little tighter than the path's own bend.
const BEND_MARGIN := 0.96
## Step (m along the centreline) over which the S's stretch and the centreline's bend are measured.
const PROBE := 0.5

## The drawn head's own path; its head is the drawn head.
var drawn: SerpentTrail
var _cfg: Dictionary
var _ramp := 0.0  # 0..1: how much of the full swing is being laid now
var _alpha := 0.0  # the heading swing (rad) that lays the full sideways swing
## Where along the sim's centreline (its arc position) the drawn head sits now.
var _sigma := 0.0
## The offset (m, along the centreline's normal) point_at last laid.
var _off := 0.0
## How far forward the serpenoid goes per metre of its own path (the S's mean progress).
var _progress := 1.0
## The serpenoid over one wave: distance along its axis (0..TAU) and offset (-1..1), by its phase.
var _axis := PackedFloat32Array()
var _side := PackedFloat32Array()
## How far the drawn head stood off the S as it set off from a coil, fading over wave_ease m.
var _carry := Vector2.ZERO


func _init(body: SerpentBody) -> void:
	_cfg = body.cfg
	var reach := body.length() * 1.25
	drawn = SerpentTrail.new(body.trail.spacing, reach, body.pos, body.heading)
	_alpha = heading_swing(Num.f(_cfg["wave_amp"]), TAU / Num.f(_cfg["wave_length"]))
	_progress = progress(_alpha)
	_sigma = body.trail.head_s - LAG
	_tabulate()


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


## One step of `dt` after the sim body stepped: the drawn head moves on along the S.
func step(body: SerpentBody, dt: float) -> void:
	var v := body.speed
	if v <= 0.0 or dt <= 0.0:
		return
	var full := smoothstep(0.0, Num.f(_cfg["speed"]) * Num.f(_cfg["wave_full_at"]), v)
	_ramp = lerpf(_ramp, maxf(full, _ramp), 1.0 - exp(-v * dt / Num.f(_cfg["wave_ease"])))
	# Short moves, at most a sample's spacing each, so the drawn path has no corners.
	var moves := ceili(MOST_SPEED * v * dt / drawn.spacing)
	for _i: int in moves:
		_advance(body, dt / moves)


## The wave's phase `s` m along the S's own path: the wave number swells and eases by
## wave_wobble_len over wave_wobble_len_s of travel, so no two waves are the same length (a real
## snake's S is never a clean sine). By distance, so every body point shares it.
func phase_at(s: float) -> float:
	var k := TAU / Num.f(_cfg["wave_length"])
	var each := Num.f(_cfg["wave_wobble_len_s"])
	var swell := Num.f(_cfg["wave_wobble_len"]) * each / TAU
	return k * (s + swell * sin(TAU * s / each))


## How much the wave's size is scaled at `s` of travel (1 on average): each crest a little
## different, from the wave_wobble_amp swell over wave_wobble_amp_s.
func size_at(s: float) -> float:
	var each := Num.f(_cfg["wave_wobble_amp_s"])
	return 1.0 + Num.f(_cfg["wave_wobble_amp"]) * sin(TAU * s / each + 0.7)


## Where the S lies at arc position `sigma` of the sim's centreline: that point, pushed along its normal by the serpenoid's offset (wave_amp x size x the
## ramp), eased in on a turn's inner side (by wave_inner_give x the bend x the offset).
func point_at(trail: SerpentTrail, sigma: float) -> Vector2:
	var behind := trail.head_s - sigma
	var normal := trail.course_at(behind).orthogonal()
	var s := sigma / _progress  # distance along the S's own path
	var off := Num.f(_cfg["wave_amp"]) * _ramp * size_at(s) * _offset(phase_at(s))
	var inner := maxf(_bend_at(trail, behind).dot(normal) * signf(off), 0.0)
	off /= 1.0 + Num.f(_cfg["wave_inner_give"]) * inner * absf(off)
	_off = off
	return trail.at(behind) + normal * off


## The centreline's bend `behind` the sim head (rad per m, toward the turn's inside): its course
## change over PROBE m each way.
static func _bend_at(trail: SerpentTrail, behind: float) -> Vector2:
	return (trail.course_at(behind - PROBE) - trail.course_at(behind + PROBE)) / (2.0 * PROBE)


## One short move of the drawn head over `h` s: along the S at one steady speed (a snake's body
## does not surge), the forward speed over the S's mean progress per metre of path, eased level
## with the sim head over wave_catch m. It steers for the S LOOK m ahead by pure pursuit (the arc
## that meets it), its bend eased under min_bend_widths body widths, so a tight inner crest is
## rounded off rather than folded.
func _advance(body: SerpentBody, h: float) -> void:
	var v := body.speed
	var trail := body.trail
	var behind := trail.head_s - _sigma - LAG  # > 0: the drawn head has fallen behind
	var u := clampf(v * (1.0 + behind / Num.f(_cfg["wave_catch"])) / _progress, 0.0, MOST_SPEED * v)
	var here := point_at(trail, _sigma)
	var stretch := here.distance_to(point_at(trail, _sigma + PROBE)) / PROBE
	_sigma = minf(_sigma + u * h / maxf(stretch, 0.2), trail.head_s - LAG_LEAST)
	_carry *= exp(-u * h / Num.f(_cfg["wave_ease"]))
	var from := drawn.head
	var to := from + drawn.head_heading * u * h
	var aim := point_at(trail, _sigma + LOOK) + _carry
	var reach := aim.distance_to(from)
	var turn := 0.0
	if reach > 0.0:
		var bend := 2.0 * sin(drawn.head_heading.angle_to(aim - from)) / reach
		var most := BEND_MARGIN / (Num.f(_cfg["min_bend_widths"]) * Num.f(_cfg["girth"]))
		bend /= pow(1.0 + pow(absf(bend) / most, 6.0), 1.0 / 6.0)  # eased under the limit
		turn = bend * u * h
	var heading := drawn.head_heading.rotated(turn)
	to = from + heading * u * h
	drawn.advance(to, heading, u, turn / h)


## The serpenoid's offset (-1..1) where it has gone `phase` (radians a wave) along its axis: from
## the one-wave table, the point whose axis distance is that.
func _offset(phase: float) -> float:
	var want := fposmod(phase, TAU) * _axis[TABLE] / TAU
	var lo := 0
	var hi := TABLE
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _axis[mid] <= want:
			lo = mid
		else:
			hi = mid
	var f := (want - _axis[lo]) / maxf(_axis[hi] - _axis[lo], 0.000001)
	return lerpf(_side[lo], _side[hi], clampf(f, 0.0, 1.0))


## The serpenoid over one wave of its own path, by phase: how far along its axis it has gone (in
## waves x TAU) and its offset off the axis (scaled to -1..1, 0 at phase 0).
func _tabulate() -> void:
	_axis.resize(TABLE + 1)
	_side.resize(TABLE + 1)
	var x := 0.0
	var y := 0.0
	var most := 0.0
	var h := TAU / TABLE
	for i: int in TABLE + 1:
		_axis[i] = x
		_side[i] = y
		most = maxf(most, absf(y))
		var u := (i + 0.5) * h
		x += cos(_alpha * cos(u)) * h
		y += sin(_alpha * cos(u)) * h
	for i: int in TABLE + 1:
		_side[i] /= most


## The drawn body settled into `points` (joints, head first) while it stood: its path is laid
## again along them, so it sets off from the shape it settled in and eases onto the S.
func settle_into(points: PackedVector2Array, body: SerpentBody) -> void:
	drawn.relay(points)
	_ramp = 0.0
	_sigma = body.trail.head_s - LAG
	_carry = drawn.head - point_at(body.trail, _sigma)


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
