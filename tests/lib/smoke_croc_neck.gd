extends RefCounted
## The croc's neck stays on its shoulders (director comments 2026-10-21 #32 "head retracts into his
## body like a turtle after a dash", #33 "a gap forms where his head meets his shoulders when he
## turns sharply"). The real sim drives each stage of the reptilian the way the rampage scene does
## (60 Hz): through a dash and 2 s on, the skull keeps its distance from the neck's base; in the
## sharpest look-ahead the skull turns no more than MAX_TWIST off the neck (rigid cells part at a
## joint twisted further: the neck carries most of the turn, ClipGait.NECK_SHARE).

const DT := 1.0 / 60.0
## The skull-to-neck-base distance may differ from rest by this share.
const MAX_REACH_CHANGE := 0.05
## The skull's yaw off the neck's, beyond what the clip has at rest (rad).
const MAX_TWIST := 0.2


static func measure(root: Node, stage: String) -> Dictionary:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(-20, 10)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var rig: KaijuRig = kaiju._rig
	for i: int in 90:
		_frame(sim, kaiju, Vector2(0, -1), false, INF)
	var rest_reach := _reach(rig)
	var rest_twist := _twist(rig)
	var reach := 0.0
	for i: int in 200:  # a dash, then 2 s of walking on
		_frame(sim, kaiju, Vector2(0, -1), i == 0, INF)
		reach = maxf(reach, absf(_reach(rig) - rest_reach) / rest_reach)
	var twist := 0.0
	for look: float in [3.0, -3.0]:  # the head thrown into the sharpest look-ahead each way
		for i: int in 60:
			_frame(sim, kaiju, Vector2(0, -1), false, look)
		twist = maxf(twist, absf(_twist(rig) - rest_twist))
	kaiju.free()
	return {"reach": reach, "twist": twist}


static func _frame(sim: RampageSim, kaiju: KaijuModel, move: Vector2, dash: bool, ahead: float) -> void:
	sim.step(DT, move, false, Dash.BUTTON if dash else 0)
	kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
	kaiju.animate(DT, 1.0, -sim.body.turn_left if ahead == INF else ahead)


## Skull base to neck base, in rig units (the model's scale divided out).
static func _reach(rig: KaijuRig) -> float:
	var scale := rig.bone("head0").global_transform.basis.get_scale().x
	return (rig.bone("head1").global_position - rig.bone("head0").global_position).length() / scale


## How far the skull is turned about the world's up from the neck (rad).
static func _twist(rig: KaijuRig) -> float:
	var neck := -rig.bone("head0").global_transform.basis.z
	var skull := -rig.bone("head1").global_transform.basis.z
	return atan2(neck.x, neck.z) - atan2(skull.x, skull.z)


static func check(check: Callable, root: Node) -> void:
	for stage: String in ["baby", "adolescent", "adult"]:
		var m := measure(root, stage)
		var reach: float = m["reach"]
		var twist: float = m["twist"]
		check.call(
			reach <= MAX_REACH_CHANGE,
			"%s: through a dash the skull keeps its distance from the neck base (%.1f%% <= 5%%)" % [stage, reach * 100.0]
		)
		check.call(
			twist <= MAX_TWIST,
			"%s: thrown into a sharp look the skull turns %.2f rad off the neck (<= %.2f)" % [stage, twist, MAX_TWIST]
		)
