class_name TankYard
extends RefCounted
## The army's tank models in a rampage: one TankModel per sim tank, steered to the sim's pose,
## firing and wrecked on the sim's events, and the Taskforce's placeholder agents. Presentation
## only (Rampage owns it).

## Tank id -> TankModel (Rampage's `_tank_nodes`; the captures and flow checks read it).
var nodes: Dictionary
## Tank id -> the hull's heading (radians), kept apart from its tumble (TankFlight tilt).
var _yaw: Dictionary
var _owner: Rampage
var _sim: RampageSim
var _city: CityView


func _init(p_owner: Rampage, p_sim: RampageSim, p_city: CityView, p_nodes: Dictionary) -> void:
	_owner = p_owner
	_sim = p_sim
	_city = p_city
	nodes = p_nodes
	_owner.add_child(TaskforceView.new(_sim))  # the Anti Kaiju Taskforce's boxes (D-143)


func spawn(id: int) -> void:
	var tank := TankModel.new()
	_owner.add_child(tank)
	nodes[id] = tank


## Hull to the way it drives (front to the kaiju when it stands or backs off), turret on the
## kaiju; tanks roll over cars and lamps every tenth step.
func update(delta: float, kaiju_at: Vector3, steps: int) -> void:
	var flatten := steps % 10 == 0
	var convoy := _sim.army_units.convoy
	for tank: RampageSim.Tank in _sim.tanks:
		if flatten and tank.height <= 0.0:
			_city.crush(Vector3(tank.pos.x, 0.0, tank.pos.y), 1.4, true)
		if not nodes.has(tank.id):
			continue
		var node: TankModel = nodes[tank.id]
		node.position = Vector3(tank.pos.x, tank.height, tank.pos.y)  # flung (TankFlight): in the air
		var front := convoy.front(tank.id)  # the sim's hull pose: it pivots, then drives
		if front != Vector2.ZERO:
			_yaw[tank.id] = atan2(-front.x, -front.y)
		node.basis = tank.tilt * Basis(Vector3.UP, Num.f(_yaw.get(tank.id, 0.0)))  # its tumble on top
		if not tank.flying and not tank.toppled:
			node.aim(kaiju_at + Vector3(0, 2.0 * _sim.body_scale(), 0), delta)


## A tank event (Rampage hands over all four): spawned and destroyed tanks come and go; a fired
## shell flies to where it goes, and a stray's impact comes when it lands (the sim lands it after
## army.shell_flight).
func on_event(event: Dictionary, kaiju_at: Vector3) -> void:
	match str(event["type"]):
		"tank_spawned":
			spawn(Num.i(event["tank"]))
			return
		"tank_destroyed":
			destroy(Num.i(event["tank"]), Vector3(Num.f(event["x"]), 0.5, Num.f(event["z"])))
			return
	var at: Vector2 = event.get("at", _sim.kaiju_pos)
	var world := Vector3(at.x, 0.0, at.y)
	if str(event["type"]) == "stray_landed":
		TankFx.stray(_city, world, Num.f(_sim.army["miss"]["radius"]))
		_owner.sfx.play_at("shell_hit", world)
	elif fire(event, world, kaiju_at):
		_owner.add_trauma(_owner.shake.source("tank_fire"))


## A tank_fired event: its shell flies to `at`; false if the tank has no model (nothing drawn, no
## recoil shake). A miss (StrayShell) flies to where it will land, with no hit on the kaiju.
func fire(event: Dictionary, at: Vector3, kaiju_at: Vector3) -> bool:
	var id := Num.i(event["tank"])
	if not nodes.has(id):
		return false
	var node: TankModel = nodes[id]
	var miss: bool = event.get("miss", false)
	var target := at + Vector3(0, 1.0, 0)
	if at.distance_to(Vector3(_sim.kaiju_pos.x, 0.0, _sim.kaiju_pos.y)) < 0.01:
		target = kaiju_at + Vector3(0, 4.0 * _sim.body_scale(), 0)
	TankFx.fire_shell(_owner, node, target, miss)
	return true


func destroy(id: int, pos: Vector3) -> void:
	if nodes.has(id):
		var node: Node3D = nodes[id]
		node.queue_free()
		nodes.erase(id)
	_yaw.erase(id)
	TankFx.wreck(_city, pos)
