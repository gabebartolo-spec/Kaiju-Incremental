extends SceneTree
## Writes how Godot's crushed props lie (PropField _crush_group, _fallen through crush and
## crush_box) and the kaiju's ground box (KaijuFootprint.of), so the Unity port
## (unity/Assets/Scripts/GameLogic/PropCrush.cs, KaijuFootprint.cs) can be checked against it.
##
##   godot --path . --script tools/unity/dump_prop_crush_golden.gd
##
## Not headless: a headless MultiMesh keeps no instance transforms, so the cells would read back
## as identity.
##
## Output: unity/SimTests/golden/prop_crush.txt, read by PropCrushCheck
## (`dotnet run --project unity/SimTests`). VOXEL: the props' voxel. FOOT: species, size tier,
## share and the box (x, y, w, h). STOMP: a stomp's point and radius, then one PROP per prop it
## crushed (base, offset) and one CELL per cell (origin, folds, the transform drawn: basis
## diagonal, origin). BODY: a body transform (basis x, y, z, origin) and the box it walks with,
## then every prop base (BASE) and whether crush_box took it.

const OUT := "res://unity/SimTests/golden/prop_crush.txt"
const SPECIES: Array[String] = ["reptilian", "insectoid"]
const TIERS := 5
const SHARES: Array[float] = [1.0, 0.5]
const VOXEL := CityDecor.PROP_VOXEL
const FOLDS: Array[String] = ["pole", "umbrella0", "umbrella1"]
const GRID := 8  # props per side of the test lot
const STEP := Vector2(3.3, 2.7)  # their spacing (m), off the voxel grid so offsets round
const CORNER := Vector2(-11.0, -9.0)
const STOMPS: Array[Vector4] = [
	Vector4(-7.6, 0.0, -6.1, 2.4),
	Vector4(0.4, 0.0, 0.2, 3.1),
	Vector4(5.5, 0.0, 4.3, 1.7),
	Vector4(-11.0, 0.0, -9.0, 0.6),
]
const BODIES: Array[Vector4] = [  # x, z, yaw, scale
	Vector4(0.0, 0.0, 0.0, 1.0),
	Vector4(-3.2, 1.7, 0.7, 1.3),
	Vector4(4.1, -2.6, -2.2, 0.8),
	Vector4(1.0, 5.0, 3.0, 2.1),
]

var _lines: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var share := Num.f(Content.section("city")["trample_share"])
	var foot := Rect2()
	_lines.append("VOXEL " + _f(VOXEL))
	for species: String in SPECIES:
		var def: Dictionary = Content.species_def(species)
		var colors: Dictionary = def["colors"]
		var model := KaijuModel.new(species, colors, "adult")
		for tier: int in TIERS:
			for s: float in [share] + SHARES:
				var rect := KaijuFootprint.of(model, tier, s)
				_lines.append("FOOT %s %d %s %s" % [species, tier, _f(s), _rect(rect)])
				if species == "reptilian" and tier == 3 and s == share:
					foot = rect
		model.free()
	_stomps()
	_bodies(foot)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("prop crush golden: %d lines -> %s" % [_lines.size(), OUT])
	quit(0)


## A fresh lot of props, half umbrellas (pole and canopy fold) and half cars (flatten).
func _lot() -> PropField:
	var field := PropField.new(VOXEL)
	for i: int in GRID:
		for j: int in GRID:
			var at := Vector3(CORNER.x + i * STEP.x, 0, CORNER.y + j * STEP.y)
			if (i + j) % 2 == 0:
				field.add(at, _umbrella, false, FOLDS)
			else:
				field.add(at, _car)
	var palette := {
		"pole": Color(0.9, 0.9, 0.9),
		"umbrella0": Color(0.9, 0.2, 0.2),
		"umbrella1": Color(0.2, 0.2, 0.9),
		"sand": Color(0.8, 0.7, 0.5),
		"car": Color(0.3, 0.5, 0.8),
	}
	root.add_child(field.build(palette, 7, 0.0))
	return field


static func _umbrella(v: VoxelBuilder) -> void:
	for y: int in 9:
		v.put(Vector3i(0, y, 0), "pole")
	for x: int in range(-3, 4):
		for z: int in range(-3, 4):
			if x * x + z * z <= 10:
				v.put(Vector3i(x, 9, z), "umbrella0" if (x + z) % 2 == 0 else "umbrella1")
	v.put(Vector3i(3, 0, 1), "sand")  # a towel by the pole: it flattens, it does not fold


static func _car(v: VoxelBuilder) -> void:
	for x: int in range(-1, 2):
		for y: int in 2:
			for z: int in range(-3, 3):
				v.put(Vector3i(x, y, z), "car")


func _stomps() -> void:
	var field := _lot()
	for s: Vector4 in STOMPS:
		var at := Vector3(s.x, s.y, s.z)
		var before := _crushed(field)
		field.crush(at, s.w)
		_lines.append("STOMP %s %s" % [_v(at), _f(s.w)])
		for k: int in field._groups.size():
			if before[k] or not field._groups[k].get("crushed", false):
				continue
			_prop(field, field._groups[k])


func _prop(field: PropField, group: Dictionary) -> void:
	var offset: Vector3i = group["offset"]
	var at: Vector3 = group["at"]
	var tile: int = group["tile"]
	_lines.append("PROP %s %d %d" % [_v(at), offset.x, offset.z])
	var mm := field._tiles[tile].multimesh
	var ids: PackedInt32Array = group["ids"]
	var origins: PackedVector3Array = group["origins"]
	var keys: PackedStringArray = group["keys"]
	var folds: Array[String] = group["folds"]
	for k: int in ids.size():
		var t := mm.get_instance_transform(ids[k])
		var diag := Vector3(t.basis.x.x, t.basis.y.y, t.basis.z.z)
		var fold := 1 if keys[k] in folds else 0
		_lines.append("CELL %s %d %s %s" % [_v(origins[k]), fold, _v(diag), _v(t.origin)])


func _bodies(foot: Rect2) -> void:
	for b: Vector4 in BODIES:
		var field := _lot()
		var basis := Basis(Vector3.UP, b.z).scaled(Vector3.ONE * b.w)
		var body := Transform3D(basis, Vector3(b.x, 0.0, b.y))
		field.crush_box(body, foot)
		_lines.append(
			(
				"BODY %s %s %s %s %s"
				% [_v(basis.x), _v(basis.y), _v(basis.z), _v(body.origin), _rect(foot)]
			)
		)
		for group: Dictionary in field._groups:
			var at: Vector3 = group["at"]
			_lines.append("BASE %s %d" % [_v(at), 1 if group.get("crushed", false) else 0])


static func _crushed(field: PropField) -> Array[bool]:
	var out: Array[bool] = []
	for group: Dictionary in field._groups:
		out.append(group.get("crushed", false))
	return out


static func _f(x: float) -> String:
	return "%.7f" % x


static func _v(v: Vector3) -> String:
	return "%s %s %s" % [_f(v.x), _f(v.y), _f(v.z)]


static func _rect(r: Rect2) -> String:
	return "%s %s %s %s" % [_f(r.position.x), _f(r.position.y), _f(r.size.x), _f(r.size.y)]
