class_name CrowdBuild
extends RefCounted
## What StadiumCrowd is made of, read off the baked stadium once: where the seats are, what the
## fans wear, and the buffer of their seat transforms. Pure functions of the model and
## data/tuning.json "crowd"; split out of StadiumCrowd for gdlint's 400-line file cap.

## A kit shirt this unsaturated (and bright) reads as an empty seat from above.
const PALE := 0.25
## Floats per instance: the 3x4 transform, then the custom data (fall start, flee time, landing
## height, linger; crowd.gdshader).
const STRIDE := 16


## Seats: the model's seat-coloured voxels open to the sky, one per `spacing` square of plan,
## shuffled and capped at "max".
static func seats(
	vox: VoxelBuilder, cfg: Dictionary, rng: RandomNumberGenerator
) -> Array[Vector3i]:
	var keys: Array = cfg["seats"]
	var near := Num.f(cfg["seat_match"]) / 255.0
	var spacing := float(Num.i(cfg["spacing"]))
	var pick: Dictionary = {}
	for cell: Vector3i in vox.colors:
		if vox.colors.has(cell + Vector3i.UP):
			continue
		var c: Color = vox.colors[cell]
		var seat := false
		for key: String in keys:
			var s := Color(key)
			seat = seat or maxf(absf(c.r - s.r), maxf(absf(c.g - s.g), absf(c.b - s.b))) <= near
		var key := Vector2i(floori(cell.x / spacing), floori(cell.z / spacing))
		if seat and not pick.has(key):
			pick[key] = cell
	var out: Array[Vector3i] = []
	for cell: Vector3i in pick.values():
		out.append(cell)
	for i: int in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := out[i]
		out[i] = out[j]
		out[j] = swap
	return out.slice(0, mini(out.size(), Num.i(cfg["max"])))


## Every (shirt, skin) outfit: the kits' colours then the neutral shirts, on street trousers
## and hair. A pale kit shirt (cricket whites) reads as an empty grey seat from above, so its
## fans wear the kit's trim (its "hair" colour: caps and helmets) instead.
static func outfits(kits: Array, neutral: Array) -> Array[Dictionary]:
	var shirts: Array[String] = []
	for kit: Dictionary in kits:
		var shirt := Color(str(kit["shirt"]))
		shirts.append(str(kit["hair"]) if shirt.s < PALE and shirt.v > 0.7 else str(kit["shirt"]))
	for n: Dictionary in neutral:
		shirts.append(str(n["shirt"]))
	var out: Array[Dictionary] = []
	for i: int in shirts.size():
		var street: Dictionary = neutral[i % neutral.size()]
		for skin: String in StadiumMatch.SKINS:
			out.append(
				{"shirt": shirts[i], "pants": street["pants"], "hair": street["hair"], "skin": skin}
			)
	return out


## A full buffer of `count` instances, the fans' first, each facing `centre`, feet at its seat,
## no fall begun (custom data zero).
static func transforms(group: Array, count: int, centre: Vector2) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(count * STRIDE)
	var i := 0
	for fan: StadiumCrowd.Fan in group:
		var facing := (centre - Vector2(fan.pos.x, fan.pos.z)).normalized()
		var c := -facing.y  # the yaw that turns -Z onto the facing
		var s := -facing.x
		buf[i] = c
		buf[i + 2] = s
		buf[i + 3] = fan.pos.x
		buf[i + 5] = 1.0
		buf[i + 7] = fan.pos.y
		buf[i + 8] = -s
		buf[i + 10] = c
		buf[i + 11] = fan.pos.z
		i += STRIDE
	return buf
