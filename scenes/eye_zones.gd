class_name EyeZones
extends RefCounted
## Where a croc's eyes are in its baked skin (D-165, the blink): the eyes are painted into the
## cubes' colours, so the cubes inside a round (a tube along the body's width) round each eye (rig
## units, mirrored across the body's middle; "croc_idle" tuning "eyes", by skin name) get the eye
## flag, and the skin around them gives the lid's colour: what the eye turns to as the lid shuts.

## The skin that colours the lid lies this far (in eye radii) from the eye's centre, no nearer than
## the eye itself.
const SHELL := 1.7
## An eye cube lies at least this far to its side of the body's middle (rig units).
const MIN_SIDE := 0.25

var _zones: Array[Vector4] = []  # a left eye's centre (its x unused) and radius
var _dark := 1.0  # a cube is an eye only when its colour is no brighter than this (luminance)
var _sum := Vector3.ZERO
var _count := 0


## The zones for the skin named `base_name` ("reptilian_baby"); none for another body.
func _init(base_name: String) -> void:
	var eyes: Dictionary = Content.section("croc_idle")["eyes"]
	if not eyes.has(base_name):
		return
	var row: Dictionary = eyes[base_name]
	var at: Array = row["at"]
	_zones.append(Vector4(Num.f(at[0]), Num.f(at[1]), Num.f(at[2]), Num.f(row["r"])))
	_dark = Num.f(row["dark"])


## True for a cube inside an eye; a cube in the shell round one gives its colour to the lid.
func claim(centre: Vector3, colour: Color) -> bool:
	for zone: Vector4 in _zones:
		for side: float in [-1.0, 1.0]:
			if centre.x * side < MIN_SIDE:
				continue
			var d := Vector2(centre.y - zone.y, centre.z - zone.z).length()  # along the eye's depth
			if d <= zone.w and colour.get_luminance() <= _dark:
				return true
			if d <= zone.w * SHELL:
				_sum += Vector3(colour.r, colour.g, colour.b)
				_count += 1
	return false


## The lid's colour (sRGB): the mean of the skin round the eyes.
func lid_colour() -> Vector3:
	if _count == 0:
		return Vector3.ZERO
	return _sum / float(_count)
