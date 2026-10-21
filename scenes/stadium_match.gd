class_name StadiumMatch
extends Node3D
## A match on the stadium's pitch (D-078): one sport per run (data/sports.json), picked from a
## presentation stream seeded off the run, its markings and posts as voxel props, two kits of
## street people (VoxelPerson) and a ball. Players spread loosely over the field and never
## stand still: the few nearest chase the ball, the nearest kicks it on, the rest drift about
## their spots. The moment the stadium loses its first chunk every player, after a moment's
## shock, runs for one of the tunnel mouths round the pitch away from the kaiju and is gone once
## inside; stomps crush them like any civilian. The stands hold the crowd (StadiumCrowd), who
## flee with them. Presentation only: the sim and the economy never know any of them exist.

## The poses a player uses: a jog while playing, the arms-up run when fleeing.
const POSES: Array[int] = [
	VoxelPerson.Pose.WALK_A, VoxelPerson.Pose.WALK_B, VoxelPerson.Pose.RUN_A, VoxelPerson.Pose.RUN_B
]
const SKINS: Array[String] = ["e0b48e", "8d5a3b", "c58c5f"]
const JOG_HZ := 5.0
const RUN_HZ := 6.0
const REACH := 0.6  # how near a player must be to the ball to play it
const JOSTLE := 2.0  # how fast (rad/s) the players at the ball circle it
const ROLL := 2.0  # the dropped ball's speed when the wall goes, and its drag (1/s)
const ROLL_DRAG := 1.5
const BALL_FADE := 0.3  # seconds the ball takes to fade once the pitch is empty
const MOUTH_REACH := 0.15  # a fleeing player is gone this near the far end of a tunnel mouth
const MOUTH_COLOR := Color("0b0b0d")

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
	var wait := 0.0
	var exit := Vector2.ZERO


var sim: RampageSim
var sport: Dictionary
var players: Array[Player] = []
var crowd: StadiumCrowd
## Inside each tunnel mouth round the pitch's edge: where a fleeing player runs to.
var mouths: Array[Vector2] = []
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
var _roll := Vector2.ZERO
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
	_add_mouths()
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
			_add_player(team, n, field)
	_ball = _centre
	_ball_from = _centre
	_ball_to = _centre
	_ball_node = MeshInstance3D.new()
	_ball_node.mesh = _ball_mesh(voxel * Num.f(_cfg["ball_scale"]), Num.f(_cfg["ball_glow"]))
	add_child(_ball_node)
	if StadiumCrowd.enabled:
		crowd = StadiumCrowd.new(sim, _index, kits, _rng)
		crowd.fx = _fx
		add_child(crowd)


## Loose positions over the field, each side mostly in its own half; the first player starts by
## the ball in the middle so the game opens with a kick.
func _add_player(team: int, n: int, field: Vector2) -> void:
	var p := Player.new()
	var end := -1.0 if team == 0 else 1.0
	var at := Vector2(-0.04, 0.0)
	if n + team > 0:
		at = Vector2.INF
		while at.length() > 0.9:  # inside the oval's edge
			at = Vector2(end * _rng.randf_range(-0.2, 0.85), _rng.randf_range(-0.85, 0.85))
	p.home = _centre + at * field
	p.pos = p.home
	p.team = team
	p.skin = _rng.randi_range(0, SKINS.size() - 1)
	p.phase = _rng.randf()
	p.pull = _rng.randf_range(0.15, 0.45)
	players.append(p)


## Dark tunnel mouths evenly round the pitch's edge; each leads a short way under the stands to
## the point a fleeing player runs to.
func _add_mouths() -> void:
	var count := Num.i(_cfg["mouths"])
	var size: Array = _cfg["mouth"]
	var box := BoxMesh.new()
	box.size = Vector3(Num.f(size[0]), Num.f(size[1]), Num.f(size[2]))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MOUTH_COLOR
	mat.roughness = 1.0
	box.material = mat
	for k: int in count:
		var out := Vector2.from_angle((k + 0.5) * TAU / count)
		var edge := _centre + out * _half
		var mouth := MeshInstance3D.new()
		mouth.mesh = box
		mouth.position = Vector3(edge.x, _top + box.size.y * 0.5, edge.y)
		mouth.rotation.y = atan2(-out.x, -out.y)
		add_child(mouth)
		mouths.append(edge + out * box.size.z * 0.5)


## Players still on the pitch.
func on_pitch() -> int:
	return players.size()


## Everyone within `radius` of `at` is crushed (one dust puff), players and fans where they are
## now. Returns how many.
func crush(at: Vector3, radius: float) -> int:
	var dead := killed
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
	dead = killed - dead
	if crowd != null:
		dead += crowd.crush(at, radius)
	return dead


func _process(delta: float) -> void:
	_clock += delta
	if not fleeing and sim.buildings[_index].frame.alive_count < _start_alive:
		_panic()
	if fleeing:
		_flee(delta)
	else:
		_play(delta)
	_draw()


## The wall gave: after a moment's shock each player makes for the nearest tunnel mouth that is
## not on the kaiju's side.
func _panic() -> void:
	fleeing = true
	var kaiju := sim.kaiju_pos
	if crowd != null:
		crowd.panic(kaiju)
	var toward := (kaiju - _centre).normalized()
	var safe: Array[Vector2] = []
	for m: Vector2 in mouths:
		if (m - _centre).normalized().dot(toward) < 0.3:
			safe.append(m)
	_roll = (_ball_to - _ball_from).normalized() * ROLL
	var react: Array = _cfg["react"]
	for p: Player in players:
		var near := p.pos
		safe.sort_custom(
			func(a: Vector2, b: Vector2) -> bool: return a.distance_to(near) < b.distance_to(near)
		)
		p.exit = safe[0]
		p.wait = _rng.randf_range(Num.f(react[0]), Num.f(react[1]))


## In shock they keep drifting; then each runs for its mouth and is gone once inside.
func _flee(delta: float) -> void:
	for i: int in range(players.size() - 1, -1, -1):
		var p := players[i]
		p.wait -= delta
		var running := p.wait <= 0.0
		var to := (p.exit if running else _drift(p)) - p.pos
		if running and to.length() < MOUTH_REACH:
			players.remove_at(i)
			escaped += 1
			continue
		var speed := Num.f(_cfg["flee_speed"] if running else _cfg["player_speed"])
		p.heading = to.normalized() if to.length() > 0.01 else p.heading
		p.pos += p.heading * minf(speed * delta, to.length())
	# The ball, dropped: it rolls to a stop, and fades out once the last player is gone.
	_ball += _roll * delta
	_roll *= maxf(0.0, 1.0 - ROLL_DRAG * delta)
	_ball_from = _ball
	_ball_to = _ball
	_ball_t = 1.0
	if players.is_empty():
		_ball_node.scale = _ball_node.scale.move_toward(Vector3.ZERO, delta / BALL_FADE)


## A player's spot as the game sways: home, wandering a little, drawn toward the ball.
func _drift(p: Player) -> Vector2:
	var t := (_clock * Num.f(_cfg["drift_hz"]) + p.phase) * TAU
	var wander := Vector2(sin(t), cos(t * 0.7 + p.phase)) * Num.f(_cfg["drift"])
	return (p.home + wander).lerp(_ball_to, p.pull)


## The few nearest the ball chase it and the nearest plays it; the rest drift about.
func _play(delta: float) -> void:
	_ball_t = minf(1.0, _ball_t + delta / _ball_time)
	_ball = _ball_from.lerp(_ball_to, _ball_t)
	var order := players.duplicate()
	order.sort_custom(
		func(a: Player, b: Player) -> bool:
			return a.pos.distance_to(_ball_to) < b.pos.distance_to(_ball_to)
	)
	var chasers := Num.i(_cfg["chasers"])
	var step := Num.f(_cfg["player_speed"]) * delta
	var sprint := step * Num.f(_cfg["sprint"])
	for i: int in order.size():
		var p: Player = order[i]
		var goal := _drift(p)
		if i < chasers:  # the nearest on the ball, the next jostling round it; never still
			var round := Vector2.from_angle(_clock * JOSTLE + p.phase * TAU)
			goal = _ball_to + round * (REACH * 0.3 if i == 0 else REACH * 1.2)
		var to := goal - p.pos
		if to.length() > 0.02:
			p.heading = to.normalized()
			p.pos += p.heading * minf(sprint if i < chasers else step, to.length())
	_kick_in -= delta
	if not order.is_empty() and _ball_t >= 1.0:  # the nearest has it at their feet: never dead
		var holder: Player = order[0]
		if holder.pos.distance_to(_ball) < REACH:
			_ball_to = holder.pos + holder.heading * REACH * 0.4
			_ball_from = _ball_to
			_ball = _ball_to
	if not order.is_empty() and _ball_t >= 1.0 and _kick_in <= 0.0:
		var nearest: Player = order[0]
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


## The ball, lit (its colour glows at `glow`) with a pale highlight on top, so it reads at the
## game camera on any grass.
func _ball_mesh(voxel: float, glow: float) -> ArrayMesh:
	var v := VoxelBuilder.new()
	v.blob(Vector3(0, 1.5, 0), Vector3(1.6, 1.3, 1.3), "ball")
	v.put(Vector3i(0, 2, 0), "shine")
	v.put(Vector3i(-1, 2, 0), "shine")
	var ball := Color(str(sport["ball"]))
	ball.a = 0.0  # the glow flag (voxel.gdshader)
	var shine := Color(1, 1, 1, 0)
	return v.bake({"ball": ball, "shine": shine}, voxel, Vector3.ZERO, glow)
