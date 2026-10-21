class_name LandmarkVoxels
extends BuildingVoxels
## A landmark's voxels: its baked shell (tools/landmarks/bake.py, from a Blender model) in place of
## a generated facade, on the same grid (RES cells per sim unit, cells local to the footprint), so
## BuildingMesher and BuildingView draw and break it chunk by chunk like any building. Each voxel's
## .kvox flags hold the faces it shows (open to the air outside the model); nothing else is drawn.
## Voxels in the shape's "ground" colours (a pitch) are also laid flat on the ground (`ground`),
## drawn always, so the ground under them keeps their colour once their chunks are broken.

## How near (per channel, 0-255) a voxel's colour must be to a ground colour.
const GROUND_MATCH := 24
## Rubble colours: greys (channels within this of each other) and reds (red this far above both).
const RUBBLE_GREY := 0.12
const RUBBLE_RED := 0.3

## Parsed .kvox per path: every view of a landmark shares one read.
static var _cache: Dictionary = {}
static var _lock := Mutex.new()

var ground := VoxelBuilder.new()
## Sim-unit plan column -> a few of the model's own wall greys and seat reds there (never its
## pitch, banner or lamp colours): the tint of the rubble its sections leave (LandmarkRubble).
var rubble_colors: Dictionary = {}


func _init(p_building: RampageSim.Building, base: Color) -> void:
	super(p_building, base, {}, false)
	var shape: Dictionary = Content.landmarks().get(b.landmark, {})
	var model := _read(str(shape.get("kvox", "")))
	if not model.frames.is_empty():
		vox = model.frames[0]
	var keys: Array = shape.get("ground", [])
	for cell: Vector3i in vox.colors:
		var c: Color = vox.colors[cell]
		for key: String in keys:
			var g := Color(key)
			var off := Vector3(absf(c.r - g.r), absf(c.g - g.g), absf(c.b - g.b)) * 255.0
			if maxf(off.x, maxf(off.y, off.z)) <= GROUND_MATCH:
				ground.put_color(Vector3i(cell.x, 0, cell.z), c)
		var grey := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < RUBBLE_GREY
		var red := c.r > c.g + RUBBLE_RED and c.r > c.b + RUBBLE_RED
		if not (grey or red) or absi(hash(cell)) % 6 != 0:
			continue
		var column := Vector2i(floori(float(cell.x) / RES), floori(float(cell.z) / RES))
		var found: Array = rubble_colors.get(column, [])
		if found.size() < 8:
			found.append(c)
			rubble_colors[column] = found


func face_mask(cell: Vector3i) -> int:
	return Num.i(vox.flags.get(cell, 0))


## A landmark's baked voxels by id (read once, shared with its views); empty if none.
static func voxels(id: String) -> VoxelBuilder:
	var shape: Dictionary = Content.landmarks().get(id, {})
	var model := _read(str(shape.get("kvox", "")))
	return VoxelBuilder.new() if model.frames.is_empty() else model.frames[0]


static func _read(path: String) -> Kvox:
	_lock.lock()
	if not _cache.has(path):
		_cache[path] = Kvox.read(path)
	var out: Kvox = _cache[path]
	_lock.unlock()
	return out
