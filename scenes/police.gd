class_name Police
extends Node3D
## Police for StreetLife: every so often two cruisers race to a crossing ahead of the kaiju and
## park nose to nose across the street, lights flashing, and their officers take up posts
## behind them and fire their pistols, in vain, until the kaiju is almost on them; then they
## scatter. Officers are StreetLife people (drawn and crushed with everyone else).
## Presentation only.

const COP_FLEE_SECONDS := 10.0  # a fleeing officer is gone after this
const BARRIER := 1.8  # cruisers park this far from the crossing, toward the kaiju
const POST := 0.9  # officers stand this far from the crossing, behind the cruisers
const ARRIVE := 1.4  # seconds for the cruisers to pull in; officers get out after
const SPOT_MIN := 14.0  # a blockade crossing is at least / at most this far from the kaiju
const SPOT_MAX := 26.0
const AHEAD := 0.4  # ...and roughly in front of it (cosine)
const MAX_FLASHES := 32
const FLASH_SECONDS := 0.07
const RICOCHET_CHANCE := 0.3
const SIREN_HZ := 3.0
const SIREN_ENERGY := 1.6


class Blockade:
	extends RefCounted
	var at := Vector2.ZERO  # the crossing
	var toward := Vector2.ZERO  # along the street, toward the kaiju
	var across := Vector2.ZERO
	var t := 0.0
	var out := false
	var holding := 0
	var light: PooledLight


## An officer's own state, which Police drives; its pos and heading are copied into the street's
## arrays after each update (what is drawn and crushed).
class Officer:
	extends RefCounted
	var pos := Vector2.ZERO
	var heading := Vector2(0, -1)
	var phase := 0.0
	var state := 0  # 0 to post, 1 holding, 2 fleeing
	var post := Vector2.ZERO
	var away := Vector2.ZERO
	var fire_in := 0.0
	var timer := 0.0
	var blockade: Blockade


var sim: RampageSim
## Running totals (tests and the capture tool read them).
var shots := 0
var blockades_made := 0
var _street: StreetLife
var _rng: RandomNumberGenerator
var _cfg: Dictionary
var _voxel: float
var _blockades: Array[Blockade] = []
var _flashes: Array[Dictionary] = []
var _flash_mm: MultiMesh
var _clock := 0.0
var _next_blockade: float


func _init(street: StreetLife, rng: RandomNumberGenerator) -> void:
	_street = street
	sim = street.sim
	_rng = rng
	_cfg = Content.section("street")
	_voxel = Num.f(_cfg["person_voxel"])
	_next_blockade = Num.f(_cfg["blockade_interval"]) * 0.5


func _ready() -> void:
	_flash_mm = MultiMesh.new()
	_flash_mm.transform_format = MultiMesh.TRANSFORM_3D
	_flash_mm.use_colors = true
	_flash_mm.mesh = Look.voxel_mesh(_voxel * 1.6, 6.0)
	_flash_mm.instance_count = MAX_FLASHES
	_flash_mm.visible_instance_count = 0
	var flash_mmi := MultiMeshInstance3D.new()
	flash_mmi.multimesh = _flash_mm
	flash_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash_mmi)


## Returns true when the officer is gone (ran off).
func update_cop(p: Officer, delta: float, kaiju: Vector2) -> bool:
	var run := Num.f(_cfg["run_speed"])
	match p.state:
		0:
			var to := p.post - p.pos
			if to.length() <= run * delta:
				p.pos = p.post
				p.state = 1
			else:
				p.heading = to.normalized()
				p.pos += p.heading * run * delta
		1:
			p.heading = (kaiju - p.pos).normalized()
			p.fire_in -= delta
			if p.fire_in <= 0.0:
				p.fire_in = Num.f(_cfg["cop_fire_interval"]) * _rng.randf_range(0.6, 1.4)
				_shoot(p)
			if p.pos.distance_to(kaiju) < Num.f(_cfg["cop_hold_radius"]):
				p.state = 2
				p.blockade.holding -= 1
				var jitter := p.blockade.across * _rng.randf_range(-0.3, 0.3)
				p.away = (-p.blockade.toward + jitter).normalized()
				_street.fled += 1
		_:
			p.heading = p.away
			p.pos += p.away * run * delta
			p.timer += delta
			return p.timer > COP_FLEE_SECONDS
	return false


func _shoot(p: Officer) -> void:
	shots += 1
	var h := Vector3(p.heading.x, 0, p.heading.y)
	var tip := Vector3(p.pos.x, 0, p.pos.y) + h * _voxel * 5.0 + Vector3.UP * _voxel * 8.5
	if _flashes.size() < MAX_FLASHES:
		_flashes.append({"at": tip, "t": FLASH_SECONDS})
	# The odd round glints off the kaiju's hide (a flash, not a particle burst: those cost
	# milliseconds to create).
	if _rng.randf() < RICOCHET_CHANCE and _flashes.size() < MAX_FLASHES:
		var hit := Vector3(sim.kaiju_pos.x, 0, sim.kaiju_pos.y)
		var spot := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(2, 5), _rng.randf_range(-1, 1)
		)
		_flashes.append({"at": hit + spot * sim.body_scale(), "t": FLASH_SECONDS * 2.0})


func update(delta: float, kaiju: Vector2) -> void:
	_clock += delta
	_next_blockade -= delta
	if _next_blockade <= 0.0:
		_next_blockade = Num.f(_cfg["blockade_interval"])
		if _blockades.size() < Num.i(_cfg["max_blockades"]):
			_start_blockade(kaiju)
	var red := int(_clock * SIREN_HZ) % 2 == 0
	for b: Blockade in _blockades.duplicate():
		b.t += delta
		b.light.light_color = Color(1.0, 0.15, 0.1) if red else Color(0.2, 0.35, 1.0)
		if not b.out and b.t >= ARRIVE:
			b.out = true
			_cops_out(b)
		if b.out and b.holding <= 0:
			_blockades.erase(b)
			b.light.queue_free()
	_draw_flashes(delta)


## Picks a crossing ahead of the kaiju and sends two cruisers to block the street there.
func _start_blockade(kaiju: Vector2) -> void:
	var traffic := _street.traffic
	var want := Num.f(_cfg["blockade_distance"])
	var best := -1
	var best_score := INF
	for n: int in traffic.crossings():
		var at := traffic.crossing(n)
		var d := at - kaiju
		var dist := d.length()
		if dist < SPOT_MIN or dist > SPOT_MAX:
			continue
		var facing := d.normalized().dot(sim.facing)
		if facing < AHEAD:
			continue
		var taken := false
		for tank: RampageSim.Tank in sim.tanks:  # never across a tank's road
			taken = taken or tank.pos.distance_to(at) < TankKeepOut.KEEP * 2.0
		for other: Blockade in _blockades:
			taken = taken or other.at.distance_to(at) < 1.0
		var score := absf(dist - want) - facing * 4.0
		if not taken and score < best_score:
			best_score = score
			best = n
	if best < 0:
		return
	var b := Blockade.new()
	b.at = traffic.crossing(best)
	# Block the street that leads from the crossing most nearly toward the kaiju.
	var v := (kaiju - b.at).normalized()
	for d: Vector2 in traffic.street_dirs(best):
		if b.toward == Vector2.ZERO or d.dot(v) > b.toward.dot(v):
			b.toward = d
	b.across = Vector2(-b.toward.y, b.toward.x)
	var line := b.at + b.toward * BARRIER
	for s: float in [-1.0, 1.0]:  # nose to nose across the road
		var slot := line + b.across * s * 0.85
		var from := b.at - b.toward * 9.0 + b.across * s * 0.4
		var angle := _rng.randf_range(-0.2, 0.2)
		_street.traffic.add_police(from, slot, (-b.across * s).rotated(angle))
	b.light = PooledLight.new("beacon")
	b.light.set_energy(SIREN_ENERGY)
	b.light.omni_range = 7.0
	b.light.position = Vector3(line.x, 1.2, line.y)
	add_child(b.light)
	_blockades.append(b)
	blockades_made += 1


func _cops_out(b: Blockade) -> void:
	var n := Num.i(_cfg["cops_per_blockade"])
	var line := b.at + b.toward * BARRIER
	for k: int in n:
		var s := (float(k) / maxf(1.0, n - 1.0)) * 2.0 - 1.0  # -1..1 across the road
		var p := Officer.new()
		p.blockade = b
		p.phase = _rng.randf()
		p.pos = line + b.across * s * 0.9 - b.toward * 0.2
		p.post = b.at + b.toward * POST + b.across * s * 1.2
		p.fire_in = _rng.randf_range(0.2, 1.0)
		_street.add_cop(p)
		b.holding += 1


func _draw_flashes(delta: float) -> void:
	var shown := 0
	for f: Dictionary in _flashes.duplicate():
		f["t"] = Num.f(f["t"]) - delta
		if Num.f(f["t"]) <= 0.0:
			_flashes.erase(f)
			continue
		var at: Vector3 = f["at"]
		_flash_mm.set_instance_transform(shown, Transform3D(Basis(), at))
		_flash_mm.set_instance_color(shown, Color(1.0, 0.85, 0.5, 0.0))
		shown += 1
	_flash_mm.visible_instance_count = shown
