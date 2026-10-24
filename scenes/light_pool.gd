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


## The lights nearest `origin`, nearest first (energy-less lights never take a slot). Keeps only
## the best `pool_size` seen, in order, as it scans (no sort of every lamp): the order is the
## distance, then the tree order, exactly as sorting them all by (distance, index) gave. The
## distance is a 32-bit float, as it was when it was stored in a Vector2 to sort.
func nearest(origin: Vector3) -> Array[PooledLight]:
	var all := get_tree().get_nodes_in_group(PooledLight.GROUP)
	var dist := PackedFloat32Array()  # the best so far, ascending
	var best: Array[PooledLight] = []
	for i: int in all.size():
		var light: PooledLight = all[i]
		if not light.is_inside_tree() or light.energy <= 0.0:
			continue
		var d := Vector2(light.global_position.distance_to(origin), 0.0).x  # 32-bit, as before
		if best.size() == _size and d >= dist[_size - 1]:
			continue  # ties go to the earlier light in the tree
		var at := dist.bsearch(d, false)  # after any equal distance: later lights sort after
		dist.insert(at, d)
		best.insert(at, light)
		if best.size() > _size:
			dist.resize(_size)
			best.resize(_size)
	return best


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
