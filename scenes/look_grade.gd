class_name LookGrade
extends RefCounted
## The colour grade (director D-163: "Cool shadows, warm fire"): one 3D lookup table on the
## Environment's colour correction, built from the look's numbers (data/looks.json "grade_*", each time of
## day may override them). Shadows lean cool (blue-teal), highlights a touch warm, and anything already
## warm (flames, embers, fire-lit walls) is guarded from the cool shift and nudged more orange, so fire
## and the cool city pull apart. Every graphics preset gets it; a preset may drop the blur, never this.
## Strength 0 builds no table at all (today's picture).

## Keys of the look this reads: each is a number except the two tints, which are hex colours.
const AMOUNT := "grade_amount"
const SHADOW := "grade_shadow"
const WARM := "grade_warm"
const SHADOW_TO := "grade_shadow_to"
const WARM_FROM := "grade_warm_from"
const GUARD := "grade_guard"
const LIFT := "grade_lift"
const FIRE_BOOST := "grade_fire_boost"
const SIZE := "grade_lut_size"

const LUMA := Vector3(0.2126, 0.7152, 0.0722)

## Finished tables by the numbers that made them: a rampage after the first reuses the table.
static var _cache: Dictionary = {}


## Puts the look's grade on `env` (no table when the look's strength is 0).
static func apply(env: Environment) -> void:
	var amount := Look.value(AMOUNT)
	if amount <= 0.0:
		return
	var sig := _signature()
	if not _cache.has(sig):
		_cache[sig] = _build()
	env.adjustment_color_correction = _cache[sig]


## One graded colour (sRGB, display-referred, after the tonemap): the whole grade in one place, so a
## test can feed it a shadow, a flame and a highlight.
static func grade(c: Color) -> Color:
	var amount := Look.value(AMOUNT)
	var lum := c.r * LUMA.x + c.g * LUMA.y + c.b * LUMA.z
	# Warm colours (red well above blue) are fire or fire-lit: the cool shift leaves them be.
	var warmth := clampf((c.r - c.b) / maxf(Look.value(GUARD), 0.001), 0.0, 1.0)
	var shadow_w := (1.0 - smoothstep(0.0, Look.value(SHADOW_TO), lum)) * (1.0 - warmth) * amount
	var high_w := smoothstep(Look.value(WARM_FROM), 1.0, lum) * (1.0 - warmth) * amount
	var cool := _tint(Look.color(SHADOW))
	var warm := _tint(Look.color(WARM))
	var out := Vector3(c.r, c.g, c.b)
	out *= Vector3.ONE.lerp(cool, shadow_w)
	out *= Vector3.ONE.lerp(warm, high_w)
	# A cool lift in the darkest tones, so black is not neutral grey.
	out += Vector3(cool.x - 1.0, cool.y - 1.0, cool.z - 1.0) * Look.value(LIFT) * shadow_w
	# Fire: warm colours get more orange (red up, blue down), never past the guard's limit.
	var boost := warmth * Look.value(FIRE_BOOST) * amount
	out.x *= 1.0 + boost
	out.z *= 1.0 - boost
	return Color(clampf(out.x, 0.0, 1.0), clampf(out.y, 0.0, 1.0), clampf(out.z, 0.0, 1.0), 1.0)


## A tint as a multiplier of the same brightness (its luminance is 1), so grading never darkens.
static func _tint(c: Color) -> Vector3:
	var lum := c.r * LUMA.x + c.g * LUMA.y + c.b * LUMA.z
	return Vector3(c.r, c.g, c.b) / maxf(lum, 0.001)


static func _signature() -> String:
	var parts: Array[String] = []
	for key: String in [AMOUNT, SHADOW_TO, WARM_FROM, GUARD, LIFT, FIRE_BOOST, SIZE]:
		parts.append(str(Look.value(key)))
	parts.append(str(Content.look().get(SHADOW, "")))
	parts.append(str(Content.look().get(WARM, "")))
	return ",".join(parts)


## The table: a texel's value is the grade of the colour at the texel's centre (the end texels hold
## pure black and pure white), so the table reads back the grade itself between the centres.
static func _build() -> ImageTexture3D:
	var n := maxi(int(Look.value(SIZE)), 8)
	var layers: Array[Image] = []
	for b: int in n:
		var img := Image.create(n, n, false, Image.FORMAT_RGBAH)
		for g: int in n:
			for r: int in n:
				img.set_pixel(r, g, grade(Color(_at(r, n), _at(g, n), _at(b, n))))
		layers.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBAH, n, n, n, false, layers)
	return tex


static func _at(i: int, n: int) -> float:
	if i == 0:
		return 0.0
	if i == n - 1:
		return 1.0
	return (float(i) + 0.5) / float(n)
