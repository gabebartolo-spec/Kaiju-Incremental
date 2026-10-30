class_name TaskforceView
extends Node3D
## The Anti Kaiju Taskforce's agents as placeholder boxes (no art yet: obsidian boxes with a blue
## strip; the real model is a later PR, D-143), one per sim agent, placed where the sim has it:
## on its roof chunk, or in the air along its flight. A railgun's aiming line is a thin blue box
## from the agent to where it points. Adult city: a gas soldier's box is gas-tinted, a gas cloud
## is a soft blue-black dome, a walking mech a knee-high obsidian box, and each laser bomb on its
## way down an electric-blue target ring on the street. Presentation only: it reads
## sim.army_units.taskforce and decides nothing.

const OBSIDIAN := Color(0.04, 0.04, 0.06)
const BLUE := Color(0.1, 0.5, 1.0)
const SIZE := Vector3(0.5, 1.0, 0.5)
const LINE := 0.06
const GAS := Color(0.08, 0.12, 0.22)
const CLOUD := Color(0.06, 0.08, 0.16, 0.55)
## A mech's box as shares of the kaiju's reach height (knee-high, D-143).
const MECH := Vector3(0.12, 0.25, 0.12)
const RING := 0.15

var _sim: RampageSim
var _boxes: Dictionary = {}  # agent id -> MeshInstance3D
var _lines: Dictionary = {}  # agent id -> MeshInstance3D (the aiming line)
var _mechs: Dictionary = {}  # mech id -> MeshInstance3D
var _marks: Array[MeshInstance3D] = []  # gas clouds and target rings, rebuilt to the sim's count


func _init(sim: RampageSim) -> void:
	_sim = sim


func _process(_delta: float) -> void:
	var live := {}
	var aiming := {}
	for agent: Taskforce.Agent in _sim.army_units.taskforce.agents:
		live[agent.id] = true
		aiming[agent.id] = agent.state == Taskforce.AIM
		var box := _box(_boxes, agent.id, SIZE, _plain(GAS if agent.gas else OBSIDIAN))
		box.position = Vector3(agent.pos.x, agent.y + SIZE.y * 0.5, agent.pos.y)
		_aim(agent)
	_drop(_boxes, live)
	_drop(_lines, aiming)
	_draw_mechs()
	_draw_marks()


func _draw_mechs() -> void:
	var live := {}
	var size := MECH * _sim.reach_height()
	for mech: TaskforceMechs.Mech in _sim.army_units.taskforce.mechs.mechs:
		live[mech.id] = true
		var box := _box(_mechs, mech.id, size, _plain(OBSIDIAN))
		box.position = Vector3(mech.pos.x, size.y * 0.5, mech.pos.y)
		box.rotation.y = atan2(-mech.facing.y, mech.facing.x)
	_drop(_mechs, live)


## One mark per standing cloud and per falling bomb, reused in order.
func _draw_marks() -> void:
	var tf := _sim.army_units.taskforce
	var n := 0
	for cloud: Array in tf.gas.clouds:
		var at: Vector2 = cloud[1]
		var r := tf.gas.radius()
		n = _mark(n, Vector3(at.x, 0.0, at.y), Vector3(r * 2.0, r, r * 2.0), true)
	var ring := Num.f(tf.mechs.cfg["bomb_radius"]) * 2.0
	for bomb: Array in tf.mechs.bombs:
		var at: Vector2 = bomb[1]
		n = _mark(n, Vector3(at.x, 0.05, at.y), Vector3(ring, 1.0, ring), false)
	while _marks.size() > n:
		_marks.pop_back().queue_free()


func _mark(n: int, at: Vector3, size: Vector3, cloud: bool) -> int:
	if n < _marks.size() and (_marks[n].mesh is SphereMesh) != cloud:
		_marks[n].queue_free()
		_marks.remove_at(n)
	if n >= _marks.size():
		var mesh := MeshInstance3D.new()
		if cloud:
			var dome := SphereMesh.new()
			var mat := _plain(CLOUD)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dome.material = mat
			mesh.mesh = dome
		else:
			var torus := TorusMesh.new()
			torus.inner_radius = 0.5 - RING
			torus.outer_radius = 0.5
			torus.material = CityView.glow(BLUE, 6.0)
			mesh.mesh = torus
		add_child(mesh)
		_marks.insert(n, mesh)
	_marks[n].position = at
	_marks[n].scale = size
	return n + 1


## Frees the node of every id `keep` no longer holds as true.
func _drop(table: Dictionary, keep: Dictionary) -> void:
	for id: int in table.keys():
		if not keep.get(id, false):
			var node: Node3D = table[id]
			node.queue_free()
			table.erase(id)


## The aiming line of an agent that is aiming: a thin box from its muzzle to the aim point.
func _aim(agent: Taskforce.Agent) -> void:
	if agent.state != Taskforce.AIM:
		return
	var from := Vector3(agent.pos.x, agent.y + SIZE.y, agent.pos.y)
	var to := Vector3(agent.aim_at.x, _sim.stand_y + 2.0, agent.aim_at.y)
	var line := _box(_lines, agent.id, Vector3(LINE, LINE, 1.0), CityView.glow(BLUE, 6.0))
	line.position = from.lerp(to, 0.5)
	line.scale = Vector3(1.0, 1.0, from.distance_to(to))
	if from.distance_to(to) > 0.01:
		line.look_at_from_position(line.position, to, Vector3.UP)


func _box(table: Dictionary, id: int, size: Vector3, material: Material) -> MeshInstance3D:
	if table.has(id):
		return table[id]
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	cube.material = material
	mesh.mesh = cube
	add_child(mesh)
	table[id] = mesh
	return mesh


func _plain(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	return mat
