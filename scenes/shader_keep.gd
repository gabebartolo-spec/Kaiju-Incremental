class_name ShaderKeep
extends Node3D
## One hidden user of each effect material variant, for the whole run (part of Fx). Godot frees
## a material's shader when its last user goes and compiles it again, on the main thread, the
## next time one is used: 8-10 ms for every breath's sparks, every claw swipe and every landmark
## burst (b2-3, tools/capture/bench_heavy.gd). A hidden, idle user keeps each one compiled.
## Presentation only: nothing it holds is ever drawn.

var _held: Dictionary = {}  # key -> the hidden node using that material
var _quad := QuadMesh.new()


## Keeps `mat`'s shader compiled for the run, once per `key` (later calls with the key are free).
func hold(key: String, mat: Material) -> void:
	if mat == null or _held.has(key):
		return
	var node: GeometryInstance3D
	if mat is ParticleProcessMaterial:
		var particles := GPUParticles3D.new()
		particles.emitting = false
		particles.process_material = mat
		node = particles
	else:
		var surface := MeshInstance3D.new()
		surface.mesh = _quad
		surface.material_override = mat
		node = surface
	node.visible = false
	add_child(node)
	_held[key] = node


## How many variants are held (tests).
func held() -> int:
	return _held.size()
