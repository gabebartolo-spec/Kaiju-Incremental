extends RefCounted
## Lit windows on the stand-in boxes hold whole (director 2026-10-31 on his clip: a lit window
## flashed black bars for a frame). facade.gdshaderinc picks each window lit or dark by a hash of
## the box's seed (INSTANCE_CUSTOM.w). Passed to the pixel as an interpolated varying, the seed
## wobbles by a rounding error across the wall, and the hash (seed in, chaos out) re-rolls the
## window per pixel row: bars that move with the camera. Headless has no GPU, so this:
##  - off: redoes the shader's hash in 32-bit floats and shows that a one-ulp seed wobble flips
##    at least MIN_FLIPS of the windows lit <-> dark (the bars);
##  - on: the shader passes the seed (and the roof height) as flat varyings, one value per box,
##    so no wobble reaches the hash.
## Seeded by design: fixed seeds and windows, no random numbers.

const SEEDS := 64
const PAIRS := 16
const STOREYS := 16
## A lit share as the city's (render plan: about a third of the windows lit at dusk).
const SHARE := 0.35
const MIN_FLIPS := 1
const SHADER_LINES: Array[String] = ["varying flat vec4 v_custom;", "varying flat float v_top;"]

var _check: Callable


## check: the runner's check.
func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var flips := 0
	for s: int in SEEDS:
		var bseed := _f32(float(s) * 0.6180339 + 0.137)
		var wobble := _next_up(bseed)
		for i: int in PAIRS:
			for j: int in STOREYS:
				var a := _lit(i, j, bseed) < SHARE
				var b := _lit(i, j, wobble) < SHARE
				if a != b:
					flips += 1
	_check.call(
		flips >= MIN_FLIPS,
		(
			"off: a one-ulp seed wobble flips %d of %d windows (the bars)"
			% [flips, SEEDS * PAIRS * STOREYS]
		)
	)
	var src := FileAccess.get_file_as_string("res://scenes/facade.gdshaderinc")
	for line: String in SHADER_LINES:
		_check.call(src.contains(line), "on: the facade shader holds `%s`" % line)


## The shader's lit hash for a window block (pair, storey) in 32-bit floats:
## hash3(vec3(floor(cell / 2), floor(y4 / 4), bseed * 31)).
static func _lit(pair: int, storey: int, bseed: float) -> float:
	var px := _fract(_f32(float(pair) * _f32(0.1031)))
	var py := _fract(_f32(float(storey) * _f32(0.1030)))
	var pz := _fract(_f32(_f32(bseed * 31.0) * _f32(0.0973)))
	# p += dot(p, p.yxz + 33.33)
	var dx := _f32(px * _f32(py + 33.33))
	var dy := _f32(py * _f32(px + 33.33))
	var d := _f32(_f32(dx + dy) + _f32(pz * _f32(pz + 33.33)))
	return _fract(_f32(_f32(_f32(px + d) + _f32(py + d)) * _f32(pz + d)))


static func _f32(x: float) -> float:
	return PackedFloat32Array([x])[0]


static func _fract(x: float) -> float:
	return _f32(x - floorf(x))


## The next 32-bit float above x (x > 0).
static func _next_up(x: float) -> float:
	var bytes := PackedFloat32Array([x]).to_byte_array()
	bytes.encode_u32(0, bytes.decode_u32(0) + 1)
	return bytes.to_float32_array()[0]
