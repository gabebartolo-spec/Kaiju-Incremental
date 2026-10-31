class_name OceanWaves
extends Node
## The bay's open-sea waves (director 2026-11-01: "copy a proven ocean"): GodotOceanWaves by Ethan
## Truong (MIT, scenes/ocean/LICENSE_GodotOceanWaves.txt), copied: a JONSWAP/TMA wave spectrum
## with Hasselmann directional spreading (Tessendorf, "Simulating Ocean Water"; Horvath, "Empirical
## Directional Wave Spectra for Computer Graphics") turned into displacement and normal maps by a
## Stockham FFT on the GPU each update, in cascades of different tile sizes, with foam where the
## surface folds (the Jacobian). The compute shaders (scenes/ocean/*.glsl) are the source's as
## they are; this is its wave_generator.gd, water.gd and render_context.gd in one typed node.
## water.gdshader reads the maps on every bay sheet (ocean_*). Numbers: tuning water.ocean (the
## source demo's three cascades), shrunk to the bay by Froude scale (lengths, fetch and depth by
## scale, wind by its root: the same sea, scale times as tall and long). Presentation only:
## nothing reads it back. Without a RenderingDevice (headless, the dummy renderer) it does
## nothing and the sheets keep the old swell.

const DIR := "res://scenes/ocean/"
const G := 9.81
const DEPTH := 20.0
## The source seeds its cascades' spectra from this ("This seed gives big waves!").
const SEED := 1234
const SEED_RANGE := 10000

var _rd: RenderingDevice
var _cfg: Dictionary
var _cascades: Array[Dictionary] = []
var _map := 256
var _scale := 1.0
var _owned: Array[RID] = []  # freed last first
var _pipes: Dictionary = {}  # name -> Pipe
var _disp := Texture2DArrayRD.new()
var _normals := Texture2DArrayRD.new()
var _scales := PackedVector4Array()
var _time := 0.0
var _next := 0.0
var _left := 0  # cascades of this update still to run (one a frame, as the source)


## One compute pipeline: its uniform sets, in set order, and its work groups.
class Pipe:
	var pipeline: RID
	var sets: Array[RID] = []
	var groups: Vector3i


func _init() -> void:
	_cfg = Content.section("water")["ocean"]
	_map = Num.i(_cfg["map_size"])
	_scale = Num.f(_cfg["scale"])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var list: Array = _cfg["cascades"]
	for i: int in list.size():
		var c: Dictionary = list[i]
		var seed := Vector2i(
			rng.randi_range(-SEED_RANGE, SEED_RANGE), rng.randi_range(-SEED_RANGE, SEED_RANGE)
		)
		# the source's time offset per cascade, so they never line up
		_cascades.append({"cfg": c, "seed": seed, "time": 120.0 + PI * i, "spectrum": true})
		var tile := Num.f(c["tile"]) * _scale
		_scales.append(
			Vector4(1.0 / tile, 1.0 / tile, Num.f(c["displacement"]), Num.f(c["normal"]))
		)


func _ready() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null or _cascades.is_empty():
		return
	_build()
	_bind.call_deferred()  # the ground's sheets are in the tree by then


func _process(delta: float) -> void:
	if _pipes.is_empty():
		return
	var rate := Num.f(_cfg["updates_per_second"])
	if _time >= _next:
		var step := 1.0 / rate + (_time - _next)
		_next = _time + 1.0 / rate
		_update(step)
	_time += delta
	if _left > 0:
		_left -= 1
		var list := _rd.compute_list_begin()
		_cascade(list, _left)
		_rd.compute_list_end()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _rd == null:
		return
	_disp.texture_rd_rid = RID()
	_normals.texture_rd_rid = RID()
	for i: int in range(_owned.size() - 1, -1, -1):
		if _owned[i].is_valid():
			_rd.free_rid(_owned[i])


## Hands every bay sheet the maps (WaterSurface marks them "ocean").
func _bind() -> void:
	for node: Node in get_tree().get_nodes_in_group(WaterSurface.GROUP):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as ShaderMaterial
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0) as ShaderMaterial
		if mat == null or not mat.get_meta("ocean", false):
			continue
		mat.set_shader_parameter("ocean_on", 1.0)
		mat.set_shader_parameter("ocean_count", _cascades.size())
		mat.set_shader_parameter("ocean_disp", _disp)
		mat.set_shader_parameter("ocean_normals", _normals)
		mat.set_shader_parameter("ocean_scales", _scales)


## The source's per-update step: time and foam rates for every cascade, then one cascade a frame.
func _update(step: float) -> void:
	if _left > 0:  # the last update's cascades not run yet
		var list := _rd.compute_list_begin()
		for i: int in _left:
			_cascade(list, i)
		_rd.compute_list_end()
	for c: Dictionary in _cascades:
		var foam := Num.f(c["cfg"]["foam_amount"])
		c["time"] = Num.f(c["time"]) + step
		# the source's constants: they set the foam parameters on a 0-10 scale
		c["grow"] = step * foam * 7.5
		c["decay"] = step * maxf(0.5, 10.0 - foam) * 1.15
	_left = _cascades.size()


## One cascade: its spectrum (when new), modulated to its time, the inverse FFT, the maps.
func _cascade(list: int, i: int) -> void:
	var c: Dictionary = _cascades[i]
	var cfg: Dictionary = c["cfg"]
	var tile := Num.f(cfg["tile"]) * _scale
	var depth := DEPTH * _scale
	if c["spectrum"]:
		var wind := Num.f(cfg["wind_speed"]) * sqrt(_scale)
		var fetch := Num.f(cfg["fetch_km"]) * 1e3 * _scale
		var alpha := 0.076 * pow(wind * wind / (fetch * G), 0.22)  # JONSWAP (wikiwaves)
		var peak := 22.0 * pow(G * G / (wind * fetch), 1.0 / 3.0)
		var seed: Vector2i = c["seed"]
		var spec := [seed.x, seed.y, tile, tile, alpha, peak, wind]
		# heading: turns the source's winds so its waves run landward here (tuning water.ocean)
		var wind_dir := Num.f(cfg["wind_direction"]) + Num.f(_cfg["heading"])
		spec += [deg_to_rad(wind_dir), depth, Num.f(cfg["swell"])]
		spec += [Num.f(cfg["detail"]), Num.f(cfg["spread"]), i]
		_dispatch(list, "spectrum_compute", spec)
		c["spectrum"] = false
	_dispatch(list, "spectrum_modulate", [tile, tile, depth, Num.f(c["time"]), i])
	# the source: no second transpose (a wave turned a quarter looks the same)
	_dispatch(list, "fft_compute", [i])
	_dispatch(list, "transpose", [i])
	_rd.compute_list_add_barrier(list)
	_dispatch(list, "fft_compute", [i])
	var unpack := [i, Num.f(cfg["whitecap"]), Num.f(c["grow"]), Num.f(c["decay"])]
	_dispatch(list, "fft_unpack", unpack)


## The source's init_gpu: the buffers, maps and pipelines, and the FFT's butterfly factors once.
func _build() -> void:
	var layers := maxi(2, _cascades.size())  # the source's floor of two layers
	var dims := Vector2i(_map, _map)
	var stages := int(log(_map) / log(2))
	var spectrum := _texture(dims, RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, layers, false)
	var butterfly := _own(_rd.storage_buffer_create(stages * _map * 16))
	var fft := _own(_rd.storage_buffer_create(layers * _map * _map * 4 * 2 * 2 * 4))
	var disp := _texture(dims, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, layers, true)
	var normals := _texture(dims, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, layers, true)
	var image := RenderingDevice.UNIFORM_TYPE_IMAGE
	var storage := RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	var group := Vector3i(_map / 16, _map / 16, 1)
	var spec := [_uniform(spectrum, image)]
	var data := [_uniform(fft, storage)]
	var factors := [_uniform(butterfly, storage)]
	var both := [_uniform(butterfly, storage), _uniform(fft, storage)]
	_pipe("spectrum_compute", [spec], group)
	_pipe("spectrum_modulate", [spec, data], group)
	_pipe("fft_butterfly", [factors], Vector3i(_map / 2 / 64, stages, 1))
	_pipe("fft_compute", [both], Vector3i(1, _map, 4))
	_pipe("transpose", [both], Vector3i(_map / 32, _map / 32, 4))
	var maps := [_uniform(disp, image), _uniform(normals, image)]
	_pipe("fft_unpack", [maps, data], group)
	var list := _rd.compute_list_begin()
	_dispatch(list, "fft_butterfly", [])
	_rd.compute_list_end()
	_disp.texture_rd_rid = disp
	_normals.texture_rd_rid = normals


## A compute pipeline from scenes/ocean/<name>.glsl: its uniform sets (each a list of RDUniforms,
## bound in order) and its work groups.
func _pipe(name: String, sets: Array, groups: Vector3i) -> void:
	var file := load(DIR + name + ".glsl") as RDShaderFile
	var shader := _own(_rd.shader_create_from_spirv(file.get_spirv()))
	var pipe := Pipe.new()
	pipe.groups = groups
	for s: int in sets.size():
		var uniforms: Array[RDUniform] = []
		var set_list: Array = sets[s]
		for b: int in set_list.size():
			var u: RDUniform = set_list[b]
			var bound := RDUniform.new()  # one per set: the same buffer sits at different bindings
			bound.uniform_type = u.uniform_type
			bound.binding = b
			bound.add_id(u.get_ids()[0])
			uniforms.append(bound)
		pipe.sets.append(_own(_rd.uniform_set_create(uniforms, shader, s)))
	pipe.pipeline = _own(_rd.compute_pipeline_create(shader))
	_pipes[name] = pipe


static func _uniform(rid: RID, type: RenderingDevice.UniformType) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = type
	u.add_id(rid)
	return u


func _dispatch(list: int, name: String, push: Array) -> void:
	var pipe: Pipe = _pipes[name]
	_rd.compute_list_bind_compute_pipeline(list, pipe.pipeline)
	if not push.is_empty():
		var bytes := _push(push)
		_rd.compute_list_set_push_constant(list, bytes, bytes.size())
	for s: int in pipe.sets.size():
		_rd.compute_list_bind_uniform_set(list, pipe.sets[s], s)
	_rd.compute_list_dispatch(list, pipe.groups.x, pipe.groups.y, pipe.groups.z)


## The source's push constant: 4 bytes a value (Godot 4.7 takes the shader's exact size, so not
## padded to 16 as the source's was).
static func _push(data: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 4)
	for i: int in data.size():
		var v: Variant = data[i]
		if v is int or v is bool:
			bytes.encode_s32(i * 4, Num.i(v))
		else:
			bytes.encode_float(i * 4, Num.f(v))
	return bytes


func _texture(dims: Vector2i, format: int, layers: int, sampled: bool) -> RID:
	var tf := RDTextureFormat.new()
	tf.array_layers = layers
	tf.format = format
	tf.width = dims.x
	tf.height = dims.y
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	# copy-from on all (the source: the spectrum only), so a probe can read the maps back
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	if sampled:
		tf.usage_bits |= (
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
			| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		)
	return _own(_rd.texture_create(tf, RDTextureView.new()))


## Cascade i's displacement map now (x, height, z per pixel, row by row), read back from the GPU
## (a probe's; empty without a RenderingDevice).
func heights(i: int) -> PackedByteArray:
	if _pipes.is_empty():
		return PackedByteArray()
	return _rd.texture_get_data(_disp.texture_rd_rid, i)


## Cascade i's wave time now (s).
func time_of(i: int) -> float:
	return Num.f(_cascades[i]["time"])


func _own(rid: RID) -> RID:
	_owned.append(rid)
	return rid
