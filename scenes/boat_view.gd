class_name BoatView
extends Node3D
## Boats on the water (D-404, director 2026-10-31: "boats don't rock or capsize, and don't flee
## his wake"): the Tripo harbour mix (trawler, tug, yacht, launch; assets/boats/*.kvox, baked by
## tools/boats/bake.sh at real size) moored along the port's piers, out in the bay he rises from
## and on the river. Each rocks on the swell; the kaiju's wake (his body within wake_radius) rocks
## it harder and pushes it away, and one he wades into (capsize_radius) rolls over and sinks.
## Pure spectacle: it reads the kaiju's position and decides nothing. Seeded (Seeds "boats").
## Numbers: data/tuning.json "boats".

const DIR := "res://assets/boats/%s.kvox"

## Boats rolled over so far (the boat suite reads it).
var capsized := 0
var boats: Array[Dictionary] = []  # {"where" (pier, bay, river), "node", "pos", "vel", "yaw", "y", "phase", "hz", "wake", "roll", "flip", "sunk"}
var _cfg: Dictionary
var _sim: RampageSim
var _rng: RandomNumberGenerator
var _models: Dictionary = {}  # id -> VoxelBuilder (one read a city)
var _t := 0.0


## Builds the boats under `city` (a CityView) for its sim.
static func attach(city: Node3D, sim: RampageSim) -> BoatView:
	var view := BoatView.new()
	view._sim = sim
	city.add_child(view)
	return view


func _ready() -> void:
	name = "Boats"
	_cfg = Content.section("boats")
	_rng = Seeds.make("boats", 0)
	var plan := CityGen.map(_sim.city)
	_moor_piers(plan)
	_moor_bay(plan)
	_moor_river(plan)


func _process(delta: float) -> void:
	step(delta, _sim.kaiju_pos)


## Advances every boat `delta` seconds with the kaiju at `kaiju` (ground plane).
func step(delta: float, kaiju: Vector2) -> void:
	_t += delta
	var wake_r := Num.f(_cfg["wake_radius"])
	var push := Num.f(_cfg["flee_push"])
	var drag := Num.f(_cfg["drag"])
	for boat: Dictionary in boats:
		if boat["sunk"] == true:
			continue
		var pos: Vector2 = boat["pos"]
		var away := pos - kaiju
		var d := away.length()
		var wake := clampf(1.0 - d / wake_r, 0.0, 1.0)
		boat["wake"] = maxf(Num.f(boat["wake"]) - delta / Num.f(_cfg["wake_fade_s"]), wake)
		if Num.f(boat["flip"]) <= 0.0 and d < Num.f(_cfg["capsize_radius"]):
			boat["flip"] = delta
			capsized += 1
		var vel: Vector2 = boat["vel"]
		if wake > 0.0 and d > 0.01:
			vel += away / d * push * wake * delta
		vel *= maxf(0.0, 1.0 - drag * delta)
		var next := pos + vel * delta
		if _wet(boat, next):
			boat["pos"] = next
		else:
			vel = Vector2.ZERO
		boat["vel"] = vel
		_pose(boat, delta)


## Whether boat `boat` may float at p (its own water: the bay's or the river's).
func _wet(boat: Dictionary, p: Vector2) -> bool:
	var water: Array = boat["water"]
	var plan: Dictionary = boat["plan"]
	return water.any(func(r: Rect2) -> bool: return r.has_point(p)) or (
		boat["sea"] == true and CityHarbour.holds(plan, p)
	)


func _pose(boat: Dictionary, delta: float) -> void:
	var node: Node3D = boat["node"]
	var wake := Num.f(boat["wake"])
	var hz := Num.f(boat["hz"])
	var phase := Num.f(boat["phase"]) + _t * TAU * hz
	var rock := deg_to_rad(Num.f(_cfg["rock_deg"]) + Num.f(_cfg["wake_rock_deg"]) * wake)
	var roll := sin(phase) * rock
	var pitch := sin(phase * 0.7 + 1.3) * rock * 0.4
	var sink := 0.0
	var flip := Num.f(boat["flip"])
	if flip > 0.0:
		flip += delta
		boat["flip"] = flip
		var over := clampf(flip / Num.f(_cfg["capsize_s"]), 0.0, 1.0)
		roll = lerpf(roll, PI, over * over * (3.0 - 2.0 * over))
		sink = maxf(0.0, flip - Num.f(_cfg["capsize_s"])) / Num.f(_cfg["sink_s"])
		if sink >= 1.0:
			boat["sunk"] = true
			node.visible = false
			return
	var pos: Vector2 = boat["pos"]
	var bob := sin(phase * 1.3) * Num.f(_cfg["bob"]) * (1.0 + 3.0 * wake)
	node.position = Vector3(pos.x, Num.f(boat["y"]) + bob - sink * Num.f(boat["height"]), pos.y)
	node.basis = Basis(Vector3.UP, Num.f(boat["yaw"])) * Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, pitch)


## Boats moored alongside the port's finger piers, bow along the pier.
func _moor_piers(plan: Dictionary) -> void:
	if not plan.has("harbour"):
		return
	var piers: Array[Rect2] = plan["harbour"]["piers"]
	var gap := Num.f(_cfg["pier_gap"])
	for pier: Rect2 in piers:
		var along_z := pier.size.y > pier.size.x
		var length := pier.size.y if along_z else pier.size.x
		var n := int(length / Num.f(_cfg["pier_spacing"]))
		for i: int in n:
			for side: float in [-1.0, 1.0]:
				if _rng.randf() > Num.f(_cfg["pier_fill"]):
					continue
				var u := (i + 0.5) / n
				var c := pier.get_center()
				var p := (
					Vector2(c.x + side * (pier.size.x * 0.5 + gap), pier.position.y + u * length)
					if along_z
					else Vector2(pier.position.x + u * length, c.y + side * (pier.size.y * 0.5 + gap))
				)
				if CityHarbour.holds(plan, p):
					_add(_pick(), p, 0.0 if along_z else PI * 0.5, plan, true, [])["where"] = "pier"


## Boats at anchor out in the bay he rises from, headings at random.
func _moor_bay(plan: Dictionary) -> void:
	var basin := CityHarbour.basin(plan)
	if basin.is_empty():
		return
	var rect: Rect2 = basin[0]
	var want := Num.i(_cfg["bay"])
	for attempt: int in want * 20:
		if want == 0:
			break
		var p := rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size
		if CityHarbour.holds(plan, p) and _clear(p):
			_add(_pick(), p, _rng.randf() * TAU, plan, true, [])["where"] = "bay"
			want -= 1


## Boats moored along the river, bow along its flow.
func _moor_river(plan: Dictionary) -> void:
	var channels := CityRiver.channels(plan, _sim.city)
	if channels.is_empty():
		return
	var river: Rect2 = channels[0]
	var y := -Num.f(_sim.city.get("river_depth", 0.0))
	var want := Num.i(_cfg["river"])
	for attempt: int in want * 20:
		if want == 0:
			break
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var p := Vector2(
			river.position.x + _rng.randf() * river.size.x,
			river.get_center().y + side * river.size.y * Num.f(_cfg["river_bank"])
		)
		if _clear(p):
			var b := _add(_pick(), p, PI * 0.5 if _rng.randf() < 0.5 else -PI * 0.5, plan, false, channels)
			b["y"] = y - Num.f(b["draft"])
			b["where"] = "river"
			want -= 1


## Whether p is far enough from every boat already moored.
func _clear(p: Vector2) -> bool:
	var space := Num.f(_cfg["spacing"])
	for b: Dictionary in boats:
		var q: Vector2 = b["pos"]
		if p.distance_to(q) <= space:
			return false
	return true


## A model id drawn from the harbour mix.
func _pick() -> String:
	var mix: Dictionary = _cfg["mix"]
	var total := 0.0
	for id: String in mix:
		total += Num.f(mix[id])
	var roll := _rng.randf() * total
	for id: String in mix:
		roll -= Num.f(mix[id])
		if roll < 0.0:
			return id
	return mix.keys()[0]


func _model(id: String) -> VoxelBuilder:
	if not _models.has(id):
		var read := Kvox.read(DIR % id)
		_models[id] = read.frames[0] if not read.frames.is_empty() else null
	return _models[id]


func _add(id: String, p: Vector2, yaw: float, plan: Dictionary, sea: bool, water: Array) -> Dictionary:
	var row: Dictionary = _cfg["models"][id]
	var voxel := Num.f(_cfg["voxel"])
	var holder := Node3D.new()
	holder.name = "%s_%d" % [id, boats.size()]
	add_child(holder)
	var vox := _model(id)
	var height := 0.0
	if vox != null:
		holder.add_child(vox.build({}, voxel, 0.0, Vector3.ZERO))
		height = Num.f(row["metres_tall"]) / Num.f(_cfg["metres_per_unit"])
	var draft := height * Num.f(row["draft"])
	var boat := {
		"id": id, "node": holder, "pos": p, "vel": Vector2.ZERO, "yaw": yaw,
		"y": CityHarbour.sea(_sim.city) - draft, "draft": draft, "height": height,
		"phase": _rng.randf() * TAU, "hz": _rng.randf_range(_range(0), _range(1)),
		"wake": 0.0, "flip": 0.0, "sunk": false, "plan": plan, "sea": sea, "water": water,
	}
	boats.append(boat)
	_pose(boat, 0.0)
	return boat


func _range(i: int) -> float:
	var hz: Array = _cfg["rock_hz"]
	return Num.f(hz[i])
