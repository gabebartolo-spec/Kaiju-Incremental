class_name MeshTiles
extends Node3D
## One MultiMesh's instances split into square ground tiles, one MultiMesh each, so the renderer
## culls every tile on its own (a MultiMesh is drawn all or nothing, so a city-wide one draws
## everything behind the camera too; perf study 2026-10-21). Each instance keeps its transform,
## colour and custom data, and inside its tile the source's order; the setters and getters take
## the source's instance index. The tiles share the template's mesh and formats.

## Per source instance: its tile, and its index in that tile's MultiMesh.
var tile_of := PackedInt32Array()
var slot_of := PackedInt32Array()
var multimeshes: Array[MultiMesh] = []
## The template's mesh, which every tile draws.
var mesh: Mesh


## template: the formats and mesh every tile copies (its own instances are not used); size: the
## tile's side (m); at: each instance's position, in instance order.
func _init(template: MultiMesh, size: float, at: PackedVector3Array) -> void:
	mesh = template.mesh
	var index := {}  # Vector2i tile -> its place in multimeshes
	var counts := PackedInt32Array()
	for p: Vector3 in at:
		var key := Vector2i(floori(p.x / size), floori(p.z / size))
		if not index.has(key):
			index[key] = counts.size()
			counts.append(0)
		var tile: int = index[key]
		tile_of.append(tile)
		slot_of.append(counts[tile])
		counts[tile] += 1
	for n: int in counts:
		var mm := MultiMesh.new()
		mm.transform_format = template.transform_format
		mm.use_colors = template.use_colors
		mm.use_custom_data = template.use_custom_data
		mm.mesh = template.mesh
		mm.instance_count = n
		multimeshes.append(mm)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


## Every tile's shadow casting (a MultiMeshInstance3D's cast_shadow).
func cast_shadows(setting: GeometryInstance3D.ShadowCastingSetting) -> void:
	for mmi: Node in get_children():
		(mmi as MultiMeshInstance3D).cast_shadow = setting


## How many instances, over every tile.
func instance_count() -> int:
	return tile_of.size()


func set_instance_transform(i: int, t: Transform3D) -> void:
	multimeshes[tile_of[i]].set_instance_transform(slot_of[i], t)


func get_instance_transform(i: int) -> Transform3D:
	return multimeshes[tile_of[i]].get_instance_transform(slot_of[i])


func set_instance_color(i: int, c: Color) -> void:
	multimeshes[tile_of[i]].set_instance_color(slot_of[i], c)


func set_instance_custom_data(i: int, c: Color) -> void:
	multimeshes[tile_of[i]].set_instance_custom_data(slot_of[i], c)
