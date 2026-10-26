class_name WindowPalette
extends RefCounted
## Lived-in windows (render plan item 6, D-242: windows carry the night, restrained): each lit
## window takes one colour from the look's "window_lit_palette" (mostly warm rooms, some cooler
## offices, a rare blue TV or bare bulb) and its own brightness from "window_lit_gain", instead
## of one cream grid. The pick is a hash of the window the layout lit as a whole (BuildingLayout:
## a bay by a floor; a curtain wall's panel two bays by half a floor), keyed on the building's
## own grid in model space, so the same window keeps its colour when the building is promoted to
## its cell grid (CellView has no UV2) and while a lifted piece falls. Look key
## "window_palette_on" (default on) switches it; off draws today's single colour.
## window_palette.gdshaderinc is the GPU side; window_key() and pick() here are its replica (the
## cell mesh suite holds the two to the same answer).

## Colours the shader holds (window_palette.gdshaderinc WINDOW_PALETTE_MAX).
const MAX := 8
## A lit window's colour alpha: the glow flag (alpha below 0.5 glows) plus a tag the shader can
## tell from neon, beacons and signs (alpha 0). Vertex colours are 8-bit, so it is exact.
const TAG := 1.0 / 255.0
## The hash's mixing constants (lowbias32, Chris Wellons), also in window_palette.gdshaderinc.
const MIX_A := 2146121005
const MIX_B := 2221713035
const MASK := 0xFFFFFFFF
## Half-open lit units: a point is moved this share of a voxel toward the building's min corner
## first, so a window's edge on a pier or mullion line never reads as the next unit.
const EDGE := 0.5


static func on() -> bool:
	return Look.value("window_palette_on") > 0.5


## The palette as linear colours and each entry's cumulative share (the last is 1).
static func colours() -> PackedVector3Array:
	var out := PackedVector3Array()
	for entry: Array in _entries():
		var c := Color(str(entry[0])).srgb_to_linear()
		out.append(Vector3(c.r, c.g, c.b))
	return out


static func weight_ends() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var total := 0.0
	for entry: Array in _entries():
		total += Num.f(entry[1])
		out.append(total)
	return out


## The brightness range [low, high] a window's gain is drawn from.
static func gain() -> Vector2:
	var raw: Array = Content.look().get("window_lit_gain", [1.0, 1.0])
	return Vector2(Num.f(raw[0]), Num.f(raw[1]))


static func _entries() -> Array:
	var raw: Array = Content.look().get("window_lit_palette", [])
	return raw.slice(0, MAX)


## Window colours on one building's material: its lit-window span and grid alignment
## (unit_of, align_of), so a few shared materials can serve a whole city.
static func apply(mat: ShaderMaterial, b: RampageSim.Building) -> void:
	apply_common(mat)
	var unit := unit_of(b)
	mat.set_shader_parameter("window_unit", unit)
	mat.set_shader_parameter("window_align", align_of(b, unit))
	mat.set_shader_parameter("window_voxel", BuildingVoxels.VOXEL)


## The palette uniforms alone (the far stand-ins pick per lit facade cell instead).
static func apply_common(mat: ShaderMaterial) -> ShaderMaterial:
	var cols := colours()
	var ends := weight_ends()
	mat.set_shader_parameter("window_palette_on", on() and not cols.is_empty())
	cols.resize(MAX)
	ends.resize(MAX)
	mat.set_shader_parameter("window_palette", cols)
	mat.set_shader_parameter("window_weight_end", ends)
	mat.set_shader_parameter("window_palette_size", mini(_entries().size(), MAX))
	mat.set_shader_parameter("window_gain", gain())
	return mat


## (bays, floors) one lit window spans above the ground floor (BuildingLayout's lit rolls).
static func unit_of(b: RampageSim.Building) -> Vector2:
	var plain := b.landmark == "" and b.hazard == "" and not b.is_rail()
	if plain and b.style % 4 == BuildingLayout.GLASS:  # BuildingVoxels.archetype()
		return Vector2(2.0, 0.5)  # BuildingLayout._lit_panel: two bays by half a floor
	return Vector2.ONE


## Where the city's lit-window grid starts for this building: its min corner (x, z) modulo
## the unit's width, so the world grid's units are its own bays (lots sit on whole units).
static func align_of(b: RampageSim.Building, unit: Vector2) -> Vector2:
	return Vector2(fposmod(b.x - b.w * 0.5, unit.x), fposmod(b.z - b.d * 0.5, unit.x))


## The lit window a point on a window face falls in, as the shader computes it: a world grid
## cell, so each window is its own key city-wide. p: a point on the face (model space, = world
## for a standing building); n: the face's outward normal.
static func window_key(p: Vector3, n: Vector3, align: Vector2, unit: Vector2) -> Vector3i:
	var voxel := BuildingVoxels.VOXEL
	var at := p - n * (voxel * 0.5) - Vector3.ONE * (voxel * EDGE)
	var u := Vector2.ONE if at.y < 1.0 else unit
	return Vector3i(
		floori((at.x - align.x) / u.x), floori(at.y / u.y), floori((at.z - align.y) / u.x)
	)


## The window's 32-bit hash (window_palette.gdshaderinc window_hash).
static func window_hash(key: Vector3i) -> int:
	var h := _mix(key.x & MASK)
	h = _mix(h ^ (key.y & MASK))
	return _mix(h ^ (key.z & MASK))


## [palette index, gain] for a hash (window_palette.gdshaderinc window_pick).
static func pick(h: int) -> Array:
	var u := float(h & 0xFFFF) / 65536.0
	var ends := weight_ends()
	var index := 0
	for i: int in ends.size() - 1:
		if u >= ends[i]:
			index = i + 1
	var g := gain()
	return [index, lerpf(g.x, g.y, float(h >> 16) / 65535.0)]


static func _mix(x: int) -> int:
	x ^= x >> 16
	x = _mul(x, MIX_A)
	x ^= x >> 15
	x = _mul(x, MIX_B)
	return x ^ (x >> 16)


## 32-bit wrapping multiply in 64-bit GDScript ints (both factors below 2^32).
static func _mul(a: int, b: int) -> int:
	var lo := a * (b & 0xFFFF)
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK
