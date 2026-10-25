extends RefCounted
## The head leads a turn (director comments #16: "if the kaiju's head were to turn the direction
## he wants to walk slightly before his body angles to move it would read more naturally"). The
## baby reptilian, driven by the real sim the way the rampage scene drives it (60 Hz), walks north
## and the stick swings east: its head swings toward the new way before the body does, and the
## way it travels never runs ahead of the body (that would be a sideways slide).

const DT := 1.0 / 60.0
## How far the head must get ahead of the body during the turn (rad).
const MIN_LEAD := 0.25
## How far the travel may run ahead of the body (rad; the clip's sway, not a slide).
const MAX_SLIDE := 0.1


static func check(check: Callable, root: Node) -> void:
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
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	for i: int in 90:
		_frame(sim, kaiju, Vector2(0, -1))
	var head0 := _head_yaw(kaiju)
	var body0 := kaiju._rig.gait.body_yaw
	var lead := 0.0
	var slide := 0.0
	for i: int in 60:
		var from := sim.kaiju_pos
		_frame(sim, kaiju, Vector2(1, 0))
		var d := sim.kaiju_pos - from
		# East is yaw -PI/2 from north: turning there is negative yaw, so lead = -(change).
		var body := -wrapf(kaiju._rig.gait.body_yaw - body0, -PI, PI)
		var head := -wrapf(_head_yaw(kaiju) - head0, -PI, PI)
		var travel := -wrapf(atan2(-d.x, -d.y) - body0, -PI, PI)
		lead = maxf(lead, head - body)
		slide = maxf(slide, travel - body)
	kaiju.free()
	check.call(
		lead >= MIN_LEAD,
		(
			"the head turns toward the new way before the body (%.2f >= %.2f rad ahead)"
			% [lead, MIN_LEAD]
		)
	)
	check.call(
		slide <= MAX_SLIDE,
		"the way it travels never runs ahead of the body (%.2f <= %.2f rad)" % [slide, MAX_SLIDE]
	)


static func _frame(sim: RampageSim, kaiju: KaijuModel, move: Vector2) -> void:
	sim.step(DT, move, false, RampageSim.STOMP)
	kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
	kaiju.animate(DT, 1.0, -sim.body.turn_left)  # the yaw still to turn: the head leads by it


## Where the skull points, flat (yaw, 0 = -Z, as the model's rotation.y).
static func _head_yaw(kaiju: KaijuModel) -> float:
	var rig: KaijuRig = kaiju._rig
	var d := rig.tail_world("head1") - rig.bone("head1").global_position
	return atan2(-d.x, -d.z)
