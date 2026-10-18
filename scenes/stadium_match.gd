class_name StadiumMatch
extends Node3D
## A match on the stadium's pitch (D-078): one sport per run (data/sports.json), picked from a
## presentation stream seeded off the run, its markings and posts as voxel props, two kits of
## street people (VoxelPerson) and a ball. Players drift toward the ball, which is kicked or
## passed about; no rules. The moment the stadium loses its first chunk every player runs from
## the kaiju for the tunnel farthest from it and is gone once through; stomps crush them like
## any civilian. The stands hold the crowd (StadiumCrowd), who flee with the players.
## Presentation only: the sim and the economy never know any of them exist.

## The poses a player uses: a jog while playing, the arms-up run when fleeing.
const POSES: Array[int] = [
	VoxelPerson.Pose.WALK_A, VoxelPerson.Pose.WALK_B, VoxelPerson.Pose.RUN_A, VoxelPerson.Pose.RUN_B
]
const SKINS: Array[String] = ["e0b48e", "8d5a3b", "c58c5f"]
const JOG_HZ := 5.0
const RUN_HZ := 6.0
const REACH := 0.6  # how near a player must be to the ball to play it
const TUNNEL_REACH := 0.4

## Tests and captures: the sport to play instead of the seeded pick ("" = pick).
static var force_sport := ""


class Player:
	extends RefCounted
	var pos := Vector2.ZERO
	var home := Vector2.ZERO
	var heading := Vector2(1, 0)
	var team := 0
	var skin := 0
	var phase := 0.0
	var pull := 0.5
	var exit := Vector2.ZERO


var sim: RampageSim
var sport: Dictionary
var players: Array[Player] = []
var crowd: StadiumCrowd
var fleeing := false
## Running totals (tests and the capture tool read them).
var escaped := 0
var killed := 0
var kicks := 0
var _index: int
var _start_alive: int
var _cfg: Dictionary
var _fx: Fx
var _rng: RandomNumberGenerator
var _centre := Vector2.ZERO
var _half := Vector2.ZERO
var _top := 0.0
var _ball := Vector2.ZERO
var _ball_from := Vector2.ZERO
var _ball_to := Vector2.ZERO
var _ball_t := 1.0
var _ball_time := 1.0
var _kick_in := 0.0
var _ball_node: MeshInstance3D
var _mms: Array[MultiMesh] = []
var _counts := PackedInt32Array()
var _clock := 0.0


## index: the stadium's building in sim.buildings. rng: the run's presentation stream.
func _init(p_sim: RampageSim, index: int, fx: Fx, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_index = index
	_fx = fx
	_rng = rng
	var data := Content.sports()
	_cfg = data["pitch"]
	var sports: Array = data["sports"]
	sport = sports[_rng.randi_range(0, sports.size() - 1)]
	for s: Dictionary in sports:
		if str(s["id"]) == force_sport:
			sport = s


func _ready() -> void:
	var b := sim.buildings[_index]
	_start_alive = b.frame.alive_count
	_centre = Vector2(b.x, b.z)
	var half: Array = _cfg["half"]
	_half = Vector2(Num.f(half[0]), Num.f(half[1]))
	_top = Num.f(_cfg["top"])
	var props := MeshInstance3D.new()
	props.mesh = PitchProps.mesh(sport, _half, Num.f(_cfg["voxel"]))
	props.position = Vector3(_centre.x, _top, _centre.y)
	add_child(props)
	var voxel := Num.f(Content.section("street")["person_voxel"])
	var per_side := Num.i(sport["per_side"])
	var kits: Array = sport["kits"]
	for team: int in kits.size():
		var kit: Dictionary = kits[team]
		for skin: int in SKINS.size():
			var outfit := kit.duplicate()
			outfit["skin"] = SKINS[skin]
			for pose: int in POSES:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = VoxelPerson.dressed(outfit, pose, voxel)
				mm.instance_count = per_side
				mm.visible_instance_count = 0
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				add_child(mmi)
				_mms.append(mm)
	_counts.resize(_mms.size())
	var field := Vector2(PitchProps.field(sport, _half)) / PitchProps.RES
	for team: int in kits.size():
		for n: int in per_side:
			_add_player(team, n, per_side, field)
	_ball = _centre
	_ball_from = _centre
	_ball_to = _centre
	_ball_node = MeshInstance3D.new()
	_ball_node.mesh = _ball_mesh(voxel)
	add_child(_ball_node)
	if StadiumCrowd.enabled:
		crowd = StadiumCrowd.new(sim, _index, kits, _rng)
		add_child(crowd)


## A formation: each side holds its own half in rows, nearer its end the lower its number.
func _add_player(team: int, n: int, per_side: int, field: Vector2) -> void:
	var p := Player.new()
	var rows := 4
	var row := n % rows
	var col := floori(float(n) / rows)
	var cols := ceili(float(per_side) / rows)
	var end := -1.0 if team == 0 else 1.0
	var x := end * field.x * (0.85 - 0.75 * float(row) / (rows - 1))
	var z := field.y * (-0.75 + 1.5 * (float(col) + 0.5) / cols) + _rng.randf_range(-0.3, 0.3)
	p.home = _centre + Vector2(x, z)
	p.pos = p.home
	p.team = team
	p.skin = _rng.randi_range(0, SKINS.size() - 1)
	p.phase = _rng.randf()
	p.pull = _rng.randf_range(0.2, 0.6)
	players.append(p)


## Players still on the pitch.
func on_pitch() -> int:
	return players.size()


## Everyone within `radius` of `at` is crushed (one dust puff).
func crush(at: Vector3, radius: float) -> void:
	var c := Vector2(at.x, at.z)
	var puffed := false
	for i: int in range(players.size() - 1, -1, -1):
		if players[i].pos.distance_to(c) > radius:
			continue
		if not puffed:
			puffed = true
			_fx.puff(Vector3(players[i].pos.x, _top + 0.15, players[i].pos.y))
		players.remove_at(i)
		killed += 1
	if crowd != null:
		crowd.crush(at, radius)


func _process(delta: float) -> void:
	_clock += delta
	if not fleeing and sim.buildings[_index].frame.alive_count < _start_alive:
		_panic()
	if fleeing:
		_flee(delta)
	else:
		_play(delta)
	_draw()


## The wall gave: everyone makes for the tunnel farthest from the kaiju.
func _panic() -> void:
	fleeing = true
	var kaiju := sim.kaiju_pos
	if crowd != null:
		crowd.panic(kaiju)
	var tunnels: Array[Vector2] = [
		_centre + Vector2(_half.x, 0),
		_centre - Vector2(_half.x, 0),
		_centre + Vector2(0, _half.y),
		_centre - Vector2(0, _half.y),
	]
	for p: Player in players:
		var best := tunnels[0]
		for t: Vector2 in tunnels:
			if (
				t.distance_to(kaiju) - t.distance_to(p.pos)
				> best.distance_to(kaiju) - best.distance_to(p.pos)
			):
				best = t
		p.exit = best


func _flee(delta: float) -> void:
	var step := Num.f(_cfg["flee_speed"]) * delta
	for i: int in range(players.size() - 1, -1, -1):
		var p := players[i]
		var to := p.exit - p.pos
		if to.length() < TUNNEL_REACH:
			players.remove_at(i)
			escaped += 1
			continue
		p.heading = to.normalized()
		p.pos += p.heading * minf(step, to.length())
	_ball_t = 1.0


## Each player drifts from their spot toward the ball; the nearest runs onto it and, after a
## moment, kicks it on to a team-mate or up the field.
func _play(delta: float) -> void:
	_ball_t = minf(1.0, _ball_t + delta / _ball_time)
	_ball = _ball_from.lerp(_ball_to, _ball_t)
	var nearest: Player = null
	for p: Player in players:
		if nearest == null or p.pos.distance_to(_ball_to) < nearest.pos.distance_to(_ball_to):
			nearest = p
	var step := Num.f(_cfg["player_speed"]) * delta
	for p: Player in players:
		var goal := _ball_to if p == nearest else p.home.lerp(_ball_to, p.pull)
		var to := goal - p.pos
		if to.length() > 0.05:
			p.heading = to.normalized()
			p.pos += p.heading * minf(step, to.length())
	_kick_in -= delta
	if nearest != null and _ball_t >= 1.0 and _kick_in <= 0.0:
		if nearest.pos.distance_to(_ball) < REACH:
			_kick(nearest)


func _kick(from: Player) -> void:
	var mates: Array[Player] = []
	for p: Player in players:
		if p.team == from.team and p != from:
			mates.append(p)
	var target := (
		_centre
		+ Vector2(
			_rng.randf_range(-_half.x, _half.x) * 0.8, _rng.randf_range(-_half.y, _half.y) * 0.8
		)
	)
	if not mates.is_empty() and _rng.randf() < 0.8:
		target = mates[_rng.randi_range(0, mates.size() - 1)].pos
	_ball_from = _ball
	_ball_to = target
	_ball_time = maxf(0.3, _ball.distance_to(target) / Num.f(_cfg["kick_speed"]))
	_ball_t = 0.0
	kicks += 1
	var every: Array = _cfg["kick_every"]
	_kick_in = _ball_time + _rng.randf_range(Num.f(every[0]), Num.f(every[1]))


func _draw() -> void:
	_counts.fill(0)
	var running := 2 if fleeing else 0
	var hz := RUN_HZ if fleeing else JOG_HZ
	for p: Player in players:
		var odd := int(_clock * hz + p.phase * 2.0) % 2
		var bucket := (p.team * SKINS.size() + p.skin) * POSES.size() + running + odd
		var mm := _mms[bucket]
		if _counts[bucket] >= mm.instance_count:
			continue
		var basis := Basis(Vector3.UP, atan2(-p.heading.x, -p.heading.y))
		mm.set_instance_transform(
			_counts[bucket], Transform3D(basis, Vector3(p.pos.x, _top, p.pos.y))
		)
		_counts[bucket] += 1
	for i: int in _mms.size():
		_mms[i].visible_instance_count = _counts[i]
	var arc := 4.0 * _ball_t * (1.0 - _ball_t) * minf(1.5, _ball_from.distance_to(_ball_to) * 0.25)
	_ball_node.position = Vector3(_ball.x, _top + arc, _ball.y)


func _ball_mesh(voxel: float) -> ArrayMesh:
	var v := VoxelBuilder.new()
	v.blob(Vector3(0, 1.5, 0), Vector3(1.6, 1.3, 1.3), "ball")
	return v.bake({"ball": Color(str(sport["ball"]))}, voxel, Vector3.ZERO, 0.0)
