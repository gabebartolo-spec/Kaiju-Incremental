extends RefCounted
## The croc's neck stays on its shoulders (director comments 2026-10-21 #32, #33): after a dash the
## head does not sink back into the body "like a turtle", and in a sharp turn the skull does not
## part from the neck ("like his head is tearing off"). The real sim drives the reptilian the way
## the rampage scene does (60 Hz); a neck cell never lies further than a cell from a skull cell
## beyond how it lies at rest, and the skull keeps its distance from the neck's base.

const DT := 1.0 / 60.0
## The skull-to-neck-base distance may differ from rest by this share through a dash and 2 s after.
const MAX_REACH_CHANGE := 0.05
## Cells of the neck's end and the skull's base this close to the joint are compared (rig units).
const JOINT_BAND := 0.07
## A gap opens at most this many cells wider than at rest.
## Every STRIDE-th cell of the joint band is compared (cheap, and a wedge is many cells wide).
const STRIDE := 4
const MAX_GAP_CELLS := 1.0


class Result:
	var rest_reach := 0.0
	var rest_gap := 0.0
	var reach: Array[float] = []
	var turn_gap: Array[float] = []
	var log: Array[String] = []

	func worst_reach_change() -> float:
		var worst := 0.0
		for r: float in reach:
			worst = maxf(worst, absf(r - rest_reach) / rest_reach)
		return worst

	func worst_gap() -> float:
		var worst := 0.0
		for g: float in turn_gap:
			worst = maxf(worst, g)
		return worst


static func measure(root: Node, species: String, stage: String) -> Result:
	var def := Content.species_def(species)
	var tree := UpgradeTree.new(Content.upgrades(), {}, species)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species(species)
	sim.kaiju_pos = Vector2(-20, 10)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(species, colors, stage)
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var rig: KaijuRig = kaiju._rig
	var out := Result.new()
	for i: int in 90:
		_frame(sim, kaiju, Vector2(0, -1), false)
	out.rest_reach = _reach(rig)
	out.rest_gap = _gap(rig)
	# A dash, then 2 s of walking on.
	for i: int in 200:
		_frame(sim, kaiju, Vector2(0, -1), i == 0)
		out.reach.append(_reach(rig))
		if i % 12 == 0:
			out.log.append("dash t=%.2f dashing=%s speed=%.1f reach=%.3f skull(rig)=%s shoulder(rig)=%s" % [i * DT, sim.body.dash.on(), kaiju._rig.gait.speed, _reach(rig), _local(rig, "head1"), _local(rig, "head0")])
	# A sharp turn at the top turn rate: the stick swings round and round.
	for i: int in 240:
		var a := float(i) * 0.05 + (PI if i > 120 else 0.0)
		_frame(sim, kaiju, Vector2(cos(a), sin(a)), false)
		if i % 3 == 0:
			out.turn_gap.append(_gap(rig))
		if i % 12 == 0:
			out.log.append("turn t=%.2f yawrate=%.2f gap=%.2f look=%.2f" % [i * DT, kaiju._rig.gait.yaw_rate, out.turn_gap[-1], kaiju._rig.gait.turn_ahead])
	kaiju.free()
	return out


static func _frame(sim: RampageSim, kaiju: KaijuModel, move: Vector2, dash: bool) -> void:
	sim.step(DT, move, false, Dash.BUTTON if dash else 0)
	kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
	kaiju.animate(DT, 1.0, -sim.body.turn_left)


static func _local(rig: KaijuRig, bone_name: String) -> String:
	var p := rig.global_transform.affine_inverse() * rig.bone(bone_name).global_position
	return "(%.2f %.2f %.2f)" % [p.x, p.y, p.z]


## Skull base to neck base, in rig units (the rig's own scale is divided out).
static func _reach(rig: KaijuRig) -> float:
	var scale := rig.bone("head0").global_transform.basis.get_scale().x
	return (rig.bone("head1").global_position - rig.bone("head0").global_position).length() / scale


## How far the neck's end cells lie from the skull's base cells, and the other way, at the worst
## cell, in cells (a skull turned about the joint opens a wedge at its edge: the worst cell shows
## it, the nearest pair would not).
static func _gap(rig: KaijuRig) -> float:
	var neck := _band(rig, "head0", true)
	var skull := _band(rig, "head1", false)
	var worst := maxf(_far(neck, skull), _far(skull, neck))
	var scale := rig.bone("head0").global_transform.basis.get_scale().x
	return sqrt(worst) / (rig.voxel_size() * scale)


## The largest squared distance from a cell of `from` to its nearest cell of `to`.
static func _far(from: PackedVector3Array, to: PackedVector3Array) -> float:
	var worst := 0.0
	for a: Vector3 in from:
		var best := INF
		for b: Vector3 in to:
			best = minf(best, a.distance_squared_to(b))
		worst = maxf(worst, best)
	return worst


static var _bands: Dictionary = {}  # bone -> cells' bone-local positions near the joint


static func _band(rig: KaijuRig, bone_name: String, tail: bool) -> PackedVector3Array:
	var key := "%d:%s" % [rig.get_instance_id(), bone_name]
	if not _bands.has(key):
		var cells := rig.voxels_of(bone_name)
		var head: Vector3 = rig._head[bone_name]
		var dir := rig.dir_of(bone_name)
		var axis := dir.normalized()
		var keep := PackedVector3Array()
		for cell: Vector3i in cells.cells:
			var p := Vector3(cell) * rig.voxel_size() - head
			var along := p.dot(axis)
			if (tail and along > dir.length() - JOINT_BAND) or (not tail and along < JOINT_BAND):
				if hash(cell) % STRIDE == 0:
					keep.append(p)
		_bands[key] = keep
	var local: PackedVector3Array = _bands[key]
	var t := rig.bone(bone_name).global_transform
	var out := PackedVector3Array()
	for p: Vector3 in local:
		out.append(t * p)
	return out


static func check(check: Callable, root: Node) -> void:
	for stage: String in ["baby", "adolescent", "adult"]:
		var m := measure(root, "reptilian", stage)
		var change := m.worst_reach_change()
		check.call(
			change <= MAX_REACH_CHANGE,
			"%s: through a dash the skull keeps its distance from the neck's base (%.1f%% <= 5%%)" % [stage, change * 100.0]
		)
		var turn := m.worst_gap()
		check.call(
			turn - m.rest_gap <= MAX_GAP_CELLS,
			"%s: in a sharp turn neck and skull part by at most a cell (%.2f over rest %.2f)" % [stage, turn, m.rest_gap]
		)
