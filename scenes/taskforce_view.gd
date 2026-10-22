class_name TaskforceView
extends Node3D
## The Anti Kaiju Taskforce's agents as placeholder boxes (no art yet: obsidian boxes with a blue
## strip; the real model is a later PR, D-143), one per sim agent, placed where the sim has it:
## on its roof chunk, or in the air along its flight. A railgun's aiming line is a thin blue box
## from the agent to where it points. Presentation only: it reads sim.army_units.taskforce and
## decides nothing.

const OBSIDIAN := Color(0.04, 0.04, 0.06)
const BLUE := Color(0.1, 0.5, 1.0)
const SIZE := Vector3(0.5, 1.0, 0.5)
const LINE := 0.06

var _sim: RampageSim
var _boxes: Dictionary = {}  # agent id -> MeshInstance3D
var _lines: Dictionary = {}  # agent id -> MeshInstance3D (the aiming line)


func _init(sim: RampageSim) -> void:
	_sim = sim


func _process(_delta: float) -> void:
	var live := {}
	var aiming := {}
	for agent: Taskforce.Agent in _sim.army_units.taskforce.agents:
		live[agent.id] = true
		aiming[agent.id] = agent.state == Taskforce.AIM
		var box := _box(_boxes, agent.id, SIZE, _plain(OBSIDIAN))
		box.position = Vector3(agent.pos.x, agent.y + SIZE.y * 0.5, agent.pos.y)
		_aim(agent)
	_drop(_boxes, live)
	_drop(_lines, aiming)


## Frees the node of every id `keep` no longer holds as true.
func _drop(table: Dictionary, keep: Dictionary) -> void:
	for id: int in table.keys():
		if not keep.get(id, false):
			(table[id] as Node3D).queue_free()
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
