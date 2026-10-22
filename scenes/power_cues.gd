class_name PowerCues
extends RefCounted
## The signature's Recharge ready pulse and Regeneration's motes (Rampage presents them each
## physics frame): the pulse and its sound fire on the step the signature comes ready, the motes
## and their sound follow the healing. Presentation only; it reads the sim and decides nothing.

var _sim: RampageSim
var _fx: AbilityFx
var _sfx: Sfx
var _was_ready := true


func _init(p_sim: RampageSim, p_fx: AbilityFx, p_sfx: Sfx) -> void:
	_sim = p_sim
	_fx = p_fx
	_sfx = p_sfx


## One frame: `at` is where the kaiju stands (world), `facing` its heading in world space.
func update(at: Vector3, facing: Vector3) -> void:
	var sim := _sim
	var fx := _fx
	var sfx := _sfx
	var charged := sim.ability_ready_in <= 0.0
	if charged and not _was_ready:
		var head := at + Vector3(0, 6.0, 0) * sim.body_scale()
		fx.ready_pulse(at, head + facing * sim.body_scale())
		sfx.play("ready")
	_was_ready = charged
	var healing := sim.stat("regen") > 0.0 and sim.hp < sim.max_hp
	fx.regen(at + Vector3(0, 3.0 * sim.body_scale(), 0), healing)
	sfx.regen(healing)
