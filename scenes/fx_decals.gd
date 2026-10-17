class_name FxDecals
extends RefCounted
## Marks the powers leave on the city, as projected Decals so they lie on the street, on rubble
## heaps and on ruins alike (never on the kaiju: its voxels are on KaijuModel.BODY_LAYER, outside
## the decal mask). Textures are drawn once, in code, from seeded noise: a soot mask (albedo)
## and glowing cracks or scrapes (emission). Presentation only.

enum Shape { DISC, WEDGE, SCRAPE }

const SIZE := 192
const SOOT := Color(0.03, 0.027, 0.024)
## Decals reach this far above and below their centre, enough to cover a rubble heap.
const DEPTH := 14.0
const CITY_LAYER := 1

static var _cache: Dictionary = {}


## A mark of `shape` (wedge points along local -Z), `size` across, centred on `at`. Its cracks
## glow `tint` at `energy`, cool over the first 60% of `seconds`, then the soot fades.
static func spawn(parent: Node3D, at: Vector3, shape: Shape, look: Dictionary) -> Decal:
	var size := Num.f(look["size"])
	var seconds := Num.f(look["seconds"])
	var cracks := Num.i(look.get("cracks", 9))
	var half := Num.f(look.get("half_angle", 0.5))
	var decal := Decal.new()
	decal.size = Vector3(size, DEPTH, size)
	decal.position = at + Vector3(0, DEPTH * 0.2, 0)
	decal.texture_albedo = _texture(shape, cracks, half, false)
	decal.texture_emission = _texture(shape, cracks, half, true)
	decal.emission_energy = Num.f(look.get("energy", 2.0))
	var tint: Color = look.get("tint", Color.WHITE)
	decal.modulate = tint
	decal.albedo_mix = Num.f(look.get("soot", 1.0))
	decal.normal_fade = 0.35
	decal.cull_mask = CITY_LAYER
	parent.add_child(decal)
	var tween := decal.create_tween()
	tween.tween_property(decal, "emission_energy", 0.0, seconds * 0.6)
	tween.tween_property(decal, "albedo_mix", 0.0, seconds * 0.4)
	tween.tween_callback(decal.queue_free)
	return decal


## Whether the textures spawn() needs for `shape` and `look` are already drawn (first use of an
## undrawn mark costs ~0.1-0.2 s of per-pixel drawing; AbilityFx prewarms the ones a run uses).
static func is_drawn(shape: Shape, look: Dictionary) -> bool:
	var cracks := Num.i(look.get("cracks", 9))
	var half := Num.f(look.get("half_angle", 0.5))
	return _cache.has(_key(shape, cracks, half, false)) and _cache.has(_key(shape, cracks, half, true))


static func _key(shape: Shape, cracks: int, half: float, glow: bool) -> String:
	return "%d/%d/%.2f/%s" % [shape, cracks, half, glow]


static func _texture(shape: Shape, cracks: int, half: float, glow: bool) -> ImageTexture:
	var key := _key(shape, cracks, half, glow)
	if _cache.has(key):
		return _cache[key]
	var noise := FastNoiseLite.new()
	noise.seed = 7 + shape
	noise.frequency = 0.03
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			image.set_pixel(x, y, _pixel(shape, cracks, half, glow, x, y, noise))
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


static func _pixel(
	shape: Shape, cracks: int, half: float, glow: bool, x: int, y: int, noise: FastNoiseLite
) -> Color:
	var p := Vector2(x, y) / (SIZE - 1) * 2.0 - Vector2.ONE
	var r := p.length()
	var ang := atan2(p.x, -p.y)  # 0 points at the top row (local -Z)
	var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
	var edge := (n - 0.5) * 0.3
	var mask := 1.0 - smoothstep(0.55, 1.0, r + edge)
	if shape == Shape.WEDGE:
		mask *= (1.0 - smoothstep(half * 0.8, half * 1.1, absf(ang) + edge * 0.3))
		mask *= smoothstep(0.02, 0.12, r)
	elif shape == Shape.SCRAPE:
		mask = smoothstep(0.62, 0.7, r + edge * 0.3) * (1.0 - smoothstep(0.9, 0.98, r))
	var line := _scratch(r, n) if shape == Shape.SCRAPE else _crack(ang, r, cracks, noise)
	if shape == Shape.WEDGE:  # a molten streak down the middle, where the beam ran
		line = maxf(line, exp(-ang * ang * 40.0) * (1.0 - r) * 0.8)
	line *= mask
	if glow:
		return Color(line, line, line, 1.0)
	var soot := SOOT * (0.6 + 0.8 * n)
	return Color(soot.r, soot.g, soot.b, clampf(mask * (0.65 + 0.35 * n) + line * 0.5, 0.0, 1.0))


## Jagged radial cracks, wide enough to read from the gameplay camera.
static func _crack(ang: float, r: float, cracks: int, noise: FastNoiseLite) -> float:
	var lane_f := ang * cracks / TAU
	var wander := noise.get_noise_2d(r * 60.0, floorf(lane_f) * 17.0) * 0.6
	var lane := fposmod(lane_f + wander * r, 1.0)
	var to_crack := 0.5 - absf(lane - 0.5)
	var width := 0.04 + 0.05 * r
	return (1.0 - smoothstep(width * 0.4, width, to_crack)) * smoothstep(0.05, 0.18, r)


## Concentric gouges, as if dragged round by tentacles.
static func _scratch(r: float, n: float) -> float:
	var ring := fposmod(r * 26.0 + n * 0.8, 1.0)
	return 1.0 - smoothstep(0.06, 0.12, absf(ring - 0.5))
