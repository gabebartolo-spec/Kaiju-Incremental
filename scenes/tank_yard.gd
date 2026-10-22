class_name TankYard
extends RefCounted
## The army's tank models in a rampage: one TankModel per sim tank, steered to the sim's pose,
## firing and wrecked on the sim's events. Presentation only (Rampage owns it).

## Tank id -> TankModel (Rampage's `_tank_nodes`; the captures and flow checks read it).
var nodes: Dictionary
var _owner: Rampage
var _sim: RampageSim
var _city: CityView


func _init(p_owner: Rampage, p_sim: RampageSim, p_city: CityView, p_nodes: Dictionary) -> void:
	_owner = p_owner
	_sim = p_sim
	_city = p_city
	nodes = p_nodes


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
		if flatten:
			_city.crush(Vector3(tank.pos.x, 0.0, tank.pos.y), 1.4, true)
		if not nodes.has(tank.id):
			continue
		var node: TankModel = nodes[tank.id]
		node.position = Vector3(tank.pos.x, 0.0, tank.pos.y)
		var front := convoy.front(tank.id)  # the sim's hull pose: it pivots, then drives
		if front != Vector2.ZERO:
			node.rotation.y = atan2(-front.x, -front.y)
		node.aim(kaiju_at + Vector3(0, 2.0 * _sim.body_scale(), 0), delta)


## A tank_fired event: its shell flies to `at`; false if the tank has no model (nothing drawn, no
## recoil shake). A miss is a stray shell (StrayShell): it lands in the city beside the kaiju.
func fire(event: Dictionary, at: Vector3, kaiju_at: Vector3) -> bool:
	if event.get("miss", false):
		TankFx.stray(_city, at, Num.f(_sim.army["miss"]["radius"]))
	var id := Num.i(event["tank"])
	if not nodes.has(id):
		return false
	var node: TankModel = nodes[id]
	var target := at + Vector3(0, 1.0, 0)
	if at.distance_to(Vector3(_sim.kaiju_pos.x, 0.0, _sim.kaiju_pos.y)) < 0.01:
		target = kaiju_at + Vector3(0, 4.0 * _sim.body_scale(), 0)
	TankFx.fire_shell(_owner, node, target)
	return true


func destroy(id: int, pos: Vector3) -> void:
	if nodes.has(id):
		var node: Node3D = nodes[id]
		node.queue_free()
		nodes.erase(id)
	var gained := Num.f(_sim.army["tank_rubble"]) * _sim.stat("rubble_mult")
	TankFx.wreck(_city, pos, gained)
