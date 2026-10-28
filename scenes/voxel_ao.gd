class_name VoxelAO
extends RefCounted
## Baked voxel ambient occlusion and material finish (render plan item 12, looks R2 + R5): the
## depth of recessed frames, sills and bitten holes at a scale half-resolution SSAO cannot see.
## Every face corner of a building voxel gets a level from the three cells round it in the face's
## air layer (0fps, "Ambient occlusion for Minecraft-like worlds"): both sides closed = 0, else
## 3 - sides - corner. The meshers (BuildingMesher, CellMesher, the native KaijuMesher, CarveMesh)
## each test occupancy with their own face-culling rule and store UV = (level / 3, finish class);
## a quad is split along its brighter diagonal so the shading is not lopsided. The shader
## (building_common.gdshaderinc) turns them into AO, roughness and specular from the look.

## Finish classes, in the order the shader's finish arrays hold them (data/materials.json
## "finish"; looks "finish_roughness" and "finish_specular" are keyed by these names).
const FINISHES: Array[String] = ["rough", "glass", "metal"]
## A corner's AO by level (0 = closed .. 3 = open), stored in UV.x.
const LEVEL_VALUE: Array[float] = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]
## Per corner q in the meshers' order (c - u - v, c + u - v, c + u + v, c - u + v): the ring bits
## (see ring_of) of its two side cells and its corner cell.
const CORNER_BITS: Array = [[0, 2, 4], [1, 2, 5], [1, 3, 6], [0, 3, 7]]
## The two splits of a quad's corners 0..3: along 0-2 (the meshers' own) and along 1-3.
const SPLIT_02: Array[int] = [0, 2, 1, 0, 3, 2]
const SPLIT_13: Array[int] = [0, 3, 1, 1, 3, 2]
## Bit set in a table() entry when the quad splits along 1-3.
const FLIP := 256
## Materials the view draws under another key (BuildingCells: a lit window is a "window").
const DRAWN_AS: Dictionary = {"lit": "window", "shop_lit": "shop"}

## Ring bits (0..255) -> the four corner levels (2 bits each, corner 0 lowest) | FLIP.
static var _table: PackedInt32Array = _make_table()


## A corner's level from its two side cells and its corner cell (true = occupied).
static func level(side1: bool, side2: bool, corner: bool) -> int:
	if side1 and side2:
		return 0
	return 3 - int(side1) - int(side2) - int(corner)


## The 8 steps from the air cell in front of a face with outward step `d`, in its plane: bit 0
## -U, 1 +U, 2 -V, 3 +V, 4 -U-V, 5 +U-V, 6 +U+V, 7 -U+V, where U and V are the directions of the
## meshers' corner vectors u and v (u = a x n, v = n x u; a = up, or right for a floor or roof).
static func ring_of(d: Vector3i) -> Array[Vector3i]:
	var nf := Vector3(d)
	var a := Vector3.UP if d.y == 0 else Vector3.RIGHT
	var u := Vector3i(a.cross(nf).sign())
	var v := Vector3i(nf.cross(Vector3(u)).sign())
	return [-u, u, -v, v, -u - v, u - v, u + v, -u + v] as Array[Vector3i]


## The corner levels and split of a face whose ring cells are `bits` (see ring_of).
static func table(bits: int) -> int:
	return _table[bits]


## UV of corner q of a face: (its AO, its finish class).
static func uv(levels: int, q: int, finish: int) -> Vector2:
	return Vector2(LEVEL_VALUE[(levels >> (q * 2)) & 3], finish)


static func _make_table() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(256)
	for bits: int in 256:
		var lv: Array[int] = []
		for q: int in 4:
			var at: Array = CORNER_BITS[q]
			var s1: int = at[0]
			var s2: int = at[1]
			var c: int = at[2]
			lv.append(level(bits & (1 << s1) != 0, bits & (1 << s2) != 0, bits & (1 << c) != 0))
		var packed := lv[0] | (lv[1] << 2) | (lv[2] << 4) | (lv[3] << 6)
		out[bits] = packed | (FLIP if lv[1] + lv[3] > lv[0] + lv[2] else 0)
	return out


## Palette key -> finish class (data/materials.json "finish"; a lit window is its material's).
## Built per call: the meshers run on worker threads.
static func finish_table() -> Dictionary:
	var out := {}
	for m: Dictionary in Content.materials():
		out[str(m["name"])] = maxi(0, FINISHES.find(str(m.get("finish", "rough"))))
	for key: String in DRAWN_AS:
		out[key] = out.get(DRAWN_AS[key], 0)
	return out


## Material id (a grid cell's byte) -> finish class, 256 entries.
static func finish_by_id() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for m: Dictionary in Content.materials():
		out[Num.i(m["id"])] = maxi(0, FINISHES.find(str(m.get("finish", "rough"))))
	return out


## finish_by_id() plus the two look ids past the materials table that draw a window lit
## (CellMesher.LIT, SHOP_LIT): the finish of what the cell is drawn as, as BuildingMesher keys it.
static func finish_by_look(lit: int, shop_lit: int) -> PackedByteArray:
	var out := finish_by_id()
	var drawn := finish_table()
	out[lit] = Num.i(drawn["lit"])
	out[shop_lit] = Num.i(drawn["shop_lit"])
	return out


## The look's AO strength, 0 when "voxel_ao_on" is off.
static func strength() -> float:
	return Look.value("voxel_ao_strength") if Look.value("voxel_ao_on") > 0.0 else 0.0


## The look's AO and finish onto a building material (building_common.gdshaderinc's uniforms).
## Off, the uniforms leave the surface exactly as before the item.
static func apply(mat: ShaderMaterial) -> void:
	var ao := strength()
	mat.set_shader_parameter("ao_strength", ao)
	var affect := Look.value("voxel_ao_light_affect") if ao > 0.0 else 0.0
	mat.set_shader_parameter("ao_light_affect", affect)
	var on := Look.value("finish_on") > 0.0
	mat.set_shader_parameter("finish_on", on)
	if on:
		mat.set_shader_parameter("finish_roughness", _by_class("finish_roughness"))
		mat.set_shader_parameter("finish_specular", _by_class("finish_specular"))


static func _by_class(key: String) -> PackedFloat32Array:
	var row: Dictionary = Content.look().get(key, {})
	var out := PackedFloat32Array()
	for name: String in FINISHES:
		out.append(Num.f(row.get(name, 0.0)))
	return out
