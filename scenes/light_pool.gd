class_name LightPool
extends Node
## Keeps the city's positional lights under gl_compatibility's cap of 32 a frame
## (rendering/limits/opengl/max_renderable_lights; R 12.1, R 12.2): only the lights.pool_size
## PooledLights nearest the camera are real, every other lamp, fire and beacon is its emissive
## voxels and glow. Re-picks on a timer or when the camera has moved lights.repick_distance, not
## every frame. The order is by distance, then by tree order, so a pick is the same every run.
## A light that drops out fades first; the one that replaces it starts only once a slot is free,
## so no more than pool_size lights are ever drawn. Presentation only.

const GROUP := "light_pool"

var _size: int
var _every: float
var _moved: float
var _clock := 0.0
var _last := Vector3(INF, INF, INF)


func _init() -> void:
	var cfg := Content.section("lights")
	_size = Num.i(cfg["pool_size"])
	_every = Num.f(cfg["repick_seconds"])
	_moved = Num.f(cfg["repick_distance"])


func _ready() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_clock += delta
	var at := camera.global_position
	if _last.x == INF or _clock >= _every or at.distance_to(_last) >= _moved:
		_clock = 0.0
		_last = at
		repick(at)


## The lights nearest `origin`, nearest first (energy-less lights never take a slot).
func nearest(origin: Vector3) -> Array[PooledLight]:
	var all := get_tree().get_nodes_in_group(PooledLight.GROUP)
	var keyed: Array[Vector2] = []
	for i: int in all.size():
		var light: PooledLight = all[i]
		if light.is_inside_tree() and light.energy > 0.0:
			keyed.append(Vector2(light.global_position.distance_to(origin), i))
	keyed.sort_custom(
		func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y)
	)
	var out: Array[PooledLight] = []
	for k: Vector2 in keyed.slice(0, _size):
		out.append(all[int(k.y)])
	return out


func repick(origin: Vector3) -> void:
	var near := nearest(origin)
	var all := get_tree().get_nodes_in_group(PooledLight.GROUP)
	for node: Node in all:
		var light: PooledLight = node
		if not near.has(light):
			light.set_wanted(false)
	var live := 0
	for node: Node in all:
		live += 1 if (node as PooledLight).is_live() else 0
	for light: PooledLight in near:
		if light.wanted:
			continue
		if light.is_live():  # still fading out: it holds its slot already
			light.set_wanted(true)
		elif live < _size:
			light.set_wanted(true)
			live += 1
