extends RefCounted
## Render plan item 8 (tuning render_opt.fx_pool): the pool's own behaviour, beside the node-count
## bar in fx_burst_nodes.gd. Slots are made once with their own process material (never one per
## burst); a slot given back is hidden and stopped and comes out reset (a tinted dust's colour
## ramp does not stay on the next plain dust); a kind with no free slot falls back to building a
## system, so no burst is dropped, and the extras are freed as before; the flag off gives exactly
## the old path; a fire and a blast take bare slots and give them back. Seeded by design: nothing
## here is random.

const Nodes := preload("res://tests/lib/fx_burst_nodes.gd")
const SCALE := 10.0
const LIFE := 3.2  # a dust's lifetime and a little over (Engine.time_scale shortens the wait)

var _check: Callable
var _tree: SceneTree
var _fx: Fx
var _pool: FxPool


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	_fx = Fx.new()
	_tree.root.add_child(_fx)
	await _tree.process_frame
	_pool = _fx.pool
	var scale_before := Engine.time_scale
	Engine.time_scale = SCALE
	await _wait()  # Fx's own prewarm bursts are done and given back first
	await _slots_and_materials()
	await _reset_on_take()
	await _exhausted_and_flag_off()
	await _fire_and_blast()
	Engine.time_scale = scale_before
	_fx.free()


func _wait() -> void:
	await _tree.create_timer(LIFE).timeout


func _material_ids(kind: String) -> Array[int]:
	var ids: Array[int] = []
	for child: Node in _pool.get_children():
		var p := child as GPUParticles3D
		if p != null and p.get_meta("fx_kind") == kind:
			ids.append(p.process_material.get_instance_id())
	return ids


func _slots_and_materials() -> void:
	var slots := FxPool.slots_for("dust", 24)
	_check.call(_pool.slot_count("dust") == slots, "dust has %d slots from tuning" % slots)
	var ids := _material_ids("dust")
	var unique := {}
	for id: int in ids:
		unique[id] = true
	_check.call(unique.size() == slots, "each of %d dust slots has its own material" % slots)
	for i: int in slots:
		_fx.dust(Vector3(i, 0, 0), 1.0)
	_check.call(_pool.busy("dust").size() == slots, "%d bursts take %d slots" % [slots, slots])
	for p: GPUParticles3D in _pool.busy("dust"):
		_check.call(p.visible and p.emitting, "a taken slot is shown and emitting")
	await _wait()
	_check.call(_pool.free_count("dust") == slots, "every dust slot is given back")
	var given_back := true
	for child: Node in _pool.get_children():
		var p := child as GPUParticles3D
		if p != null and p.get_meta("fx_kind") == "dust" and (p.visible or p.emitting):
			given_back = false
	_check.call(given_back, "a slot given back is hidden and stopped")
	_check.call(_material_ids("dust") == ids, "no material was made or replaced by the bursts")
	_check.call(_pool.fallbacks == 0, "no burst needed the create path")


func _reset_on_take() -> void:
	var slots := _pool.slot_count("dust")
	for i: int in slots:
		_fx.dust(Vector3(i, 0, 0), 2.0, Color(0.8, 0.2, 0.2, 0.7))
	await _wait()
	for i: int in slots:
		_fx.dust(Vector3(i, 0, 0), 1.0)
	var ramp := _fx._dust_mat.color_ramp as Texture2D
	var plain := true
	for p: GPUParticles3D in _pool.busy("dust"):
		var mat := p.process_material as ParticleProcessMaterial
		if mat.color_ramp != ramp:
			plain = false
	_check.call(plain, "a plain dust after a tinted one has the base colour ramp again")
	await _wait()


func _exhausted_and_flag_off() -> void:
	var slots := _pool.slot_count("dust")
	var before := Nodes.particles_under(_fx)
	var fallbacks := _pool.fallbacks
	for i: int in slots + 3:
		_fx.dust(Vector3(i, 0, 5), 1.0)
	_check.call(
		Nodes.particles_under(_fx) == before + 3,
		"3 bursts past the %d slots are built, none dropped" % slots
	)
	_check.call(_pool.fallbacks == fallbacks + 3, "the 3 extra bursts are counted as fallbacks")
	await _wait()
	_check.call(Nodes.particles_under(_fx) == before, "the extra systems are freed after")
	_check.call(_pool.free_count("dust") == slots, "all dust slots are free again")
	_pool.on = false
	_fx.dust(Vector3(0, 0, 9), 1.0)
	_check.call(
		Nodes.particles_under(_fx) == before + 1 and _pool.free_count("dust") == slots,
		"with the flag off a burst is built, not pooled"
	)
	await _wait()
	_check.call(Nodes.particles_under(_fx) == before, "the flag-off system is freed after")
	_pool.on = true


func _fire_and_blast() -> void:
	var before := Nodes.particles_under(_fx)
	var flames := _pool.free_count("flames")
	var host := Node3D.new()
	_tree.root.add_child(host)
	var fire := Fire.new(1.0, 0.0)
	host.add_child(fire)
	_check.call(_pool.free_count("flames") == flames - 1, "a fire takes a flames slot")
	var taken: Array[int] = []
	for child: Node in fire.get_children():
		if child is GPUParticles3D:
			taken.append(child.get_instance_id())
	_check.call(taken.size() == 3, "the fire has its 3 particle systems")
	fire.retire()
	await _tree.process_frame
	await _tree.process_frame
	_check.call(_pool.free_count("flames") == flames, "a retired fire gives its flames back")
	_check.call(Nodes.particles_under(_fx) == before, "no particle system was freed or added")
	var second := Fire.new(1.0, 1.0)
	host.add_child(second)
	var reused := false
	for child: Node in second.get_children():
		if child is GPUParticles3D and taken.has(child.get_instance_id()):
			reused = true
	_check.call(reused, "the next fire is built from the retired one's systems")
	second.retire()
	await _tree.process_frame
	await _tree.process_frame
	var blast := _pool.free_count("burst")
	var mat := ParticleProcessMaterial.new()
	BlastParts.emit(host, mat, BlastParts.spark_cube(), 10, 0.2, Vector3.ZERO)
	_check.call(_pool.free_count("burst") == blast - 1, "a blast burst takes a bare slot")
	await _wait()
	_check.call(_pool.free_count("burst") == blast, "and gives it back")
	_check.call(Nodes.particles_under(_fx) == before, "the pool's node count is unchanged")
	host.free()
