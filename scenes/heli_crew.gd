class_name HeliCrew
extends Node3D
## The crew of a downed helicopter bailing out (HeliWreck): each a soldier in drab hanging under a
## pale canopy, the dome opening above them as they fall clear, then drifting down with the wind.
## Numbers: tuning "heli_wreck". Presentation only.

const OUTFIT := 2  # VoxelPerson.ROOFTOP_OUTFITS: a soldier in drab
const CANOPY := Color("e2dac4")

var _cfg: Dictionary
var _chutes: Array[Chute] = []


## A crew member under a canopy, drifting from `from` to `to`.
class Chute:
	var node: Node3D
	var from: Vector3
	var to: Vector3
	var seconds: float
	var t := 0.0


func _init(cfg: Dictionary) -> void:
	_cfg = cfg


func _process(delta: float) -> void:
	var still: Array[Chute] = []
	for chute: Chute in _chutes:
		chute.t += delta
		var u := chute.t / chute.seconds
		if u >= 1.0:
			chute.node.queue_free()
			continue
		chute.node.position = chute.from.lerp(chute.to, u)
		chute.node.rotation.z = sin(chute.t * 2.0) * 0.15  # swinging under the canopy
		still.append(chute)
	_chutes = still


## One crew member bailing out: a soldier hanging under a pale canopy, drifting down with the wind.
func jump(from: Vector3, drift: Vector3) -> void:
	var voxel := Num.f(Content.section("street")["person_voxel"])
	var person := MeshInstance3D.new()
	person.mesh = VoxelPerson.dressed(
		VoxelPerson.ROOFTOP_OUTFITS[OUTFIT], VoxelPerson.Pose.RUN_A, voxel
	)
	person.scale = Vector3.ONE * Num.f(_cfg["crew_scale"])  # big enough to read under the canopy
	add_child(person)
	var canopy := _canopy()
	canopy.scale = Vector3.ONE / Num.f(_cfg["crew_scale"])  # the dome keeps its own size
	person.add_child(canopy)
	var open := Num.f(_cfg["canopy_open"])  # the dome opens from the soldier's back, never pops in
	canopy.scale *= 0.05
	create_tween().tween_property(canopy, "scale", canopy.scale * 20.0, open).set_ease(
		Tween.EASE_OUT
	)
	var seconds := from.y / Num.f(_cfg["chute_speed"])
	var chute := Chute.new()
	chute.node = person
	chute.from = from
	chute.to = Vector3(from.x, 0.0, from.z) + drift * seconds * 0.5
	chute.seconds = seconds
	_chutes.append(chute)


## A voxel dome of pale fabric in alternating panels (one MultiMesh of cubes, widest at the rim),
## shroud lines down to the soldier's shoulders. It catches a little light of its own so it reads at
## night, under the bloom.
func _canopy() -> Node3D:
	var out := Node3D.new()
	var voxel := Num.f(_cfg["canopy_voxel"])
	var width := Num.f(_cfg["canopy_width"])
	var hang := Num.f(_cfg["canopy_hang"])
	var rim := roundi(width * 0.5 / voxel)
	var rise := maxi(1, roundi(rim * 0.55))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = CANOPY
	mat.emission_energy_multiplier = Num.f(_cfg["canopy_glow"])
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * voxel
	cube.material = mat
	var cells: Array[Vector3] = []
	for x: int in range(-rim, rim + 1):
		for z: int in range(-rim, rim + 1):
			for y: int in rise + 1:
				var flat := Vector2(x, z).length_squared() / float(rim * rim)
				if flat + float(y * y) / float(rise * rise) <= 1.0:
					cells.append(Vector3(x, y, z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = cells.size()
	for n: int in cells.size():
		var cell := cells[n]
		mm.set_instance_transform(n, Transform3D(Basis(), cell * voxel))
		var panel := int(floorf((atan2(cell.z, cell.x) + PI) / (TAU / 8.0))) % 2
		mm.set_instance_color(n, CANOPY if panel == 0 else CANOPY.darkened(0.28))
	var dome := MultiMeshInstance3D.new()
	dome.multimesh = mm
	dome.position = Vector3(0, hang, 0)
	out.add_child(dome)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var from := Vector3(corner.x * width * 0.4, hang, corner.y * width * 0.4)
		out.add_child(_line(from, Vector3(0, hang * 0.45, 0), mat))
	return out


func _line(from: Vector3, to: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, from.distance_to(to))
	box.material = mat
	var line := MeshInstance3D.new()
	line.mesh = box
	line.transform = Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	return line
