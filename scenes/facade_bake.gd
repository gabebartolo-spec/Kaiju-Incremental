class_name FacadeBake
extends RefCounted
## Every plain building's real facade (D-415: its stand-in box shows the windows its voxels
## show, so the stream swap is invisible), baked at load into one atlas. Per building a strip,
## one texel per facade cell: the four sides in BuildingLayout.SIDES order (-x and +x run along
## z, -z and +z along x), floor up, each texel the colour of the front-most voxel there, as its
## mesh draws it (Look.jitter, 8-bit; alpha the glow flag, a lit window's WindowPalette.TAG).
## The cells are laid out on workers; the atlas is kept on disk (user://), keyed by everything
## it is made from, so a second load of the same city reads it back. Presentation only.

const FORMAT := 1
const CACHE_DIR := "user://facade_cache"
## The layers a facade texel looks through, front-most first (BuildingLayout._face: -2 and -1
## stand proud of the wall plane 0, 1 is the recessed glass).
const LAYERS: Array[int] = [-2, -1, 0, 1]
const ATLAS_WIDTH := 4096
const MAX_SIZE := 16384

## Per building n: the atlas x, y of its strip's corner at 2n, 2n + 1; -1 with no strip.
var origin := PackedInt32Array()
var atlas: Image
var _buildings: Array[RampageSim.Building]
var _colors: Array[Color]
var _party: Array[Dictionary]
var _plain: Array[int] = []
var _strips: Array[PackedByteArray] = []
var _task := -1
var _key := ""
var _cached := false


func _init(
	buildings: Array[RampageSim.Building], colors: Array[Color], party: Array[Dictionary]
) -> void:
	_buildings = buildings
	_colors = colors
	_party = party
	origin.resize(buildings.size() * 2)
	origin.fill(-1)
	for n: int in buildings.size():
		if plain(buildings[n]):
			_plain.append(n)


## Whether building `b` takes a baked facade: a plain building (BuildingView.voxels_of's
## BuildingVoxels), never a landmark, hazard, rail or bridge.
static func plain(b: RampageSim.Building) -> bool:
	return (
		not b.is_rail()
		and not b.is_bridge()
		and b.landmark == ""
		and b.model == ""
		and b.hazard == ""
	)


## Whether no city's facade is baked yet: the first load bakes and takes longer (D-415), so the
## loading screen says so.
static func first_load() -> bool:
	return (
		Content.section("render_opt").get("facade_bake", true) == true
		and DirAccess.get_files_at(CACHE_DIR).is_empty()
	)


## Starts the bake: the cache read, or every plain building's strip, on the workers.
func start() -> void:
	_key = _cache_key()
	if FileAccess.file_exists(_cache_path()):
		_cached = true
		_task = WorkerThreadPool.add_task(_read_cache)
		return
	_strips.resize(_plain.size())
	_task = WorkerThreadPool.add_group_task(_bake_one, _plain.size())


## Waits for the bake, packs the atlas (and writes it to the cache). Null atlas: nothing baked.
func finish() -> void:
	if _task < 0:
		return
	wait()
	if not _cached:
		_pack()
		_write_cache()
	_strips.clear()


## Waits for the workers without packing (leaving the tree before finish_initial).
func wait() -> void:
	if _task < 0:
		return
	if _cached:
		WorkerThreadPool.wait_for_task_completion(_task)
	else:
		WorkerThreadPool.wait_for_group_task_completion(_task)
	_task = -1


func _bake_one(k: int) -> void:
	var n := _plain[k]
	var b := _buildings[n]
	var vox := BuildingVoxels.new(b, _colors[n], _party[n])
	_strips[k] = strip(vox)


## The facade strip of a plain building's voxels: RGBA8 bytes, 2 (w + d) * res wide, height *
## res tall, row 0 at the ground.
static func strip(vox: BuildingVoxels) -> PackedByteArray:
	var b := vox.b
	var res := BuildingVoxels.RES
	var w := b.w * res
	var d := b.d * res
	var h := b.height * res
	var width := 2 * (w + d)
	var bytes := PackedByteArray()
	bytes.resize(width * h * 4)
	var cells: Dictionary = vox.vox.cells
	var at := 0
	for side: Vector2i in BuildingLayout.SIDES:
		var length := d if side.x != 0 else w
		for p: int in length:
			for y: int in h:
				var color := _front(cells, vox.palette, side, p, y, w, d, b.style)
				var i := ((y * width) + at + p) * 4
				bytes[i] = roundi(clampf(color.r, 0.0, 1.0) * 255.0)
				bytes[i + 1] = roundi(clampf(color.g, 0.0, 1.0) * 255.0)
				bytes[i + 2] = roundi(clampf(color.b, 0.0, 1.0) * 255.0)
				bytes[i + 3] = roundi(clampf(color.a, 0.0, 1.0) * 255.0)
		at += length
	return bytes


## The colour the facade shows at (p, y) of `side`: its front-most voxel's, jittered as its mesh
## is; the wall colour where no layer holds a voxel.
static func _front(
	cells: Dictionary,
	palette: Dictionary,
	side: Vector2i,
	p: int,
	y: int,
	w: int,
	d: int,
	salt: int
) -> Color:
	for layer: int in LAYERS:
		var cell := _cell(side, p, y, layer, w, d)
		var key: Variant = cells.get(cell)
		if key != null and palette.has(key):
			var base: Color = palette[key]
			return Look.jitter(base, cell, salt)
	return palette["wall"]


## BuildingLayout._at for a building w x d cells.
static func _cell(side: Vector2i, p: int, y: int, layer: int, w: int, d: int) -> Vector3i:
	if side.x < 0:
		return Vector3i(layer, y, p)
	if side.x > 0:
		return Vector3i(w - 1 - layer, y, p)
	if side.y < 0:
		return Vector3i(p, y, layer)
	return Vector3i(p, y, d - 1 - layer)


## Shelves the strips into the atlas, in building order.
func _pack() -> void:
	if _plain.is_empty():
		return
	var res := BuildingVoxels.RES
	var width := ATLAS_WIDTH
	for n: int in _plain:
		width = maxi(width, 2 * (_buildings[n].w + _buildings[n].d) * res)
	var x := 0
	var y := 0
	var row := 0
	for n: int in _plain:
		var b := _buildings[n]
		var sw := 2 * (b.w + b.d) * res
		if x + sw > width:
			x = 0
			y += row
			row = 0
		x += sw
		row = maxi(row, b.height * res)
	var height := y + row
	assert(height <= MAX_SIZE, "facade atlas too tall: widen ATLAS_WIDTH")
	atlas = Image.create(width, height, false, Image.FORMAT_RGBA8)
	x = 0
	y = 0
	row = 0
	for k: int in _plain.size():
		var n := _plain[k]
		var b := _buildings[n]
		var sw := 2 * (b.w + b.d) * res
		var sh := b.height * res
		if x + sw > width:
			x = 0
			y += row
			row = 0
		var img := Image.create_from_data(sw, sh, false, Image.FORMAT_RGBA8, _strips[k])
		atlas.blit_rect(img, Rect2i(0, 0, sw, sh), Vector2i(x, y))
		origin[n * 2] = x
		origin[n * 2 + 1] = y
		x += sw
		row = maxi(row, sh)


## Building n's strip corner in the atlas; x < 0 when it has none.
func corner(n: int) -> Vector2i:
	if atlas == null or n * 2 + 1 >= origin.size():
		return Vector2i(-1, -1)
	return Vector2i(origin[n * 2], origin[n * 2 + 1])


## Everything the atlas is made from: the format, the layout and palette scripts, the look the
## colours read, and every plain building with its colour and party walls.
func _cache_key() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var look := []
	for name: String in ["window_lit", "color_noise", "window_glow"]:
		look.append(Look.value(name))
	for name: String in ["window", "window_lit_color", "roof"]:
		look.append(Look.color(name))
	var scripts := []
	for path: String in [
		"res://sim/building_layout.gd",
		"res://scenes/building_voxels.gd",
		"res://scenes/facade_bake.gd"
	]:
		scripts.append(FileAccess.get_md5(path))
	ctx.update(
		var_to_bytes(
			[FORMAT, ProjectSettings.get_setting("application/config/version"), scripts, look]
		)
	)
	for n: int in _plain:
		var b := _buildings[n]
		ctx.update(var_to_bytes([b.x, b.z, b.w, b.d, b.height, b.style, _colors[n], _party[n]]))
	return ctx.finish().hex_encode()


func _cache_path() -> String:
	return "%s/%s.bin" % [CACHE_DIR, _key]


func _read_cache() -> void:
	var file := FileAccess.open_compressed(
		_cache_path(), FileAccess.READ, FileAccess.COMPRESSION_ZSTD
	)
	if file == null:
		return
	var got: Variant = file.get_var()
	if typeof(got) != TYPE_ARRAY:
		return
	var head: Array = got
	if head.size() != 4 or head[0] != FORMAT:
		return
	var width: int = head[1]
	var height: int = head[2]
	origin = head[3]
	var bytes := file.get_buffer(width * height * 4)
	atlas = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)


func _write_cache() -> void:
	if atlas == null:
		return
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var file := FileAccess.open_compressed(
		_cache_path(), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD
	)
	if file == null:
		return
	file.store_var([FORMAT, atlas.get_width(), atlas.get_height(), origin])
	file.store_buffer(atlas.get_data())
