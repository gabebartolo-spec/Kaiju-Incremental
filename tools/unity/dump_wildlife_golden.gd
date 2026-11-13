extends SceneTree
## Writes how Godot's wildlife (scenes/wildlife_view.gd) starts and moves on the wildlife suite's
## two towers: a roar beside them, a section landing on one, a roar far away, over two minutes,
## so the Unity port (unity/Assets/Scripts/Rampage/Wildlife.cs) can be checked against it step
## for step.
##
##   godot --headless --path . --script tools/unity/dump_wildlife_golden.gd
##
## Output: unity/SimTests/golden/wildlife.txt, read by WildlifeCheck
## (`dotnet run --project unity/SimTests`). B: a bird as built (kind, index, position, home centre,
## radius, height, angle, spin, phase, perched); S: every bird every EVERY steps (step, kind, index,
## position, the x and z columns of its looking_at basis, perched); W: the whale then (step, state,
## visible, position, yaw); END: birds scattered, surfacings, dives.

const OUT := "res://unity/SimTests/golden/wildlife.txt"
const DT := 1.0 / 15.0
const STEPS := 1800
const EVERY := 60
const ROAR_AT := 150  # an ultimate beside the towers
const FALL_AT := 600  # a section of the second tower lands
const FAR_AT := 900  # a leap far away: scares no bird, sends the whale down
const TOWERS: Array[Dictionary] = [
	{"x": 0.0, "z": 0.0, "w": 4, "d": 4, "h": 20, "tier": 1, "style": 0},
	{"x": 12.0, "z": 6.0, "w": 4, "d": 4, "h": 16, "tier": 1, "style": 0},
]
const FAR := Vector3(5000.0, 0.0, 5000.0)

var _lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(
		stats, Content.tuning(), TOWERS.duplicate(true), Seeds.make("army", 0)
	)
	var stage := Node3D.new()
	root.add_child(stage)
	var view := WildlifeView.attach(stage, sim)
	view.set_process(false)
	for flock: Dictionary in view._flocks:
		var birds: Array[Dictionary] = flock["birds"]
		for i: int in birds.size():
			_built(str(flock["kind"]), i, birds[i])
	for s: int in STEPS:
		if s == ROAR_AT:
			view.on_event({"type": "ultimate"}, Vector3.ZERO)
		elif s == FALL_AT:
			view.on_event({"type": "fall_land", "building": 1}, Vector3.ZERO)
		elif s == FAR_AT:
			view.on_event({"type": "leap"}, FAR)
		view._process(DT)
		if s % EVERY == 0:
			_dump(view, s)
	_lines.append("END %d %d %d" % [view.scattered, view.surfacings, view.dives])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("wrote %s (%d lines)" % [OUT, _lines.size()])
	quit()


func _built(kind: String, i: int, bird: Dictionary) -> void:
	var home: Dictionary = bird["home"]
	var p: Vector3 = bird["pos"]
	var c: Vector3 = home["centre"]
	_lines.append(
		(
			"B %s %d %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %s"
			% [
				kind,
				i,
				p.x,
				p.y,
				p.z,
				c.x,
				c.y,
				c.z,
				home["radius"],
				home["height"],
				home["angle"],
				home["spin"],
				bird["phase"],
				bird["perched"]
			]
		)
	)


func _dump(view: WildlifeView, s: int) -> void:
	for flock: Dictionary in view._flocks:
		var birds: Array[Dictionary] = flock["birds"]
		for i: int in birds.size():
			var bird := birds[i]
			var p: Vector3 = bird["pos"]
			var facing: Vector3 = bird["facing"]
			var b := _basis(facing)
			_lines.append(
				(
					"S %d %s %d %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %s"
					% [
						s,
						flock["kind"],
						i,
						p.x,
						p.y,
						p.z,
						b.x.x,
						b.x.y,
						b.x.z,
						b.z.x,
						b.z.y,
						b.z.z,
						bird["perched"]
					]
				)
			)
	var w := view.whale.position
	_lines.append(
		(
			"W %d %s %s %.4f %.4f %.4f %.4f"
			% [s, view.whale_state(), view.whale.visible, w.x, w.y, w.z, view.whale.rotation.y]
		)
	)


## The basis _move_flock gives the bird's instance (its own lines, headless keeps no MultiMesh).
func _basis(facing: Vector3) -> Basis:
	var flat := Vector3(facing.x, clampf(facing.y, -0.5, 0.5), facing.z)
	return Basis.looking_at(flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD)
