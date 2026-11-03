class_name BuildingVoxels
extends RefCounted
## Builds one building's fine voxels from its sim footprint: RES cells per sim unit, so each
## sim layer (one floor) is RES cells tall and each unit of facade is one bay RES cells wide.
## Facades have depth: windows sit one cell back in their reveals behind proud sills and
## lintels; piers, spandrels, mullions and transoms frame them. Four archetypes: office
## (ribbon windows over spandrel bands, AC plant), brick residential (punched windows, balconies
## with railings, water tower), glass tower (flush curtain wall, mast with beacon), stone classic
## (pilasters, cornices and string courses, stepped roof). Ground floors are shopfronts under a
## sign band and an awning. A side shared with a neighbour carries the same facade (build 2 note
## 22), so it shows when the neighbour falls; some shops hang a vertical neon sign off a street face
## (Tokyo). Hollow shell plus a floor slab per floor, so a broken building shows its floors.
## The layout is BuildingLayout's, the same one the sim's BuildingCells packs; this class adds
## the palette and lights a share of the windows (Look "window_lit").

const RES := 8
const VOXEL := 1.0 / RES
const OFFICE := BuildingLayout.OFFICE
const BRICK := BuildingLayout.BRICK
const GLASS := BuildingLayout.GLASS
const STONE := BuildingLayout.STONE
const AWNINGS: Array[Color] = [Color("7d4636"), Color("3f5a4a"), Color("6a5a3a"), Color("4a4f66")]
const NEON: Array[Color] = [Color("ff4f8b"), Color("4fd8ff"), Color("ffb347"), Color("8dff6a")]
const SIGN_BANDS: Array[Color] = [
	Color("2a2f3a"), Color("5a2a26"), Color("2e4a3a"), Color("3a3a3a")
]
const SIGN_CHANCE := BuildingLayout.SIGN_CHANCE
## Sides, as the outward step in cells: -x, +x, -z, +z.
const SIDES := BuildingLayout.SIDES

var vox := VoxelBuilder.new()
var palette: Dictionary = {}
var b: RampageSim.Building
## Side -> floors of it a neighbour covers (no sign hangs off that side).
var _party: Dictionary = {}


## party: side (from SIDES) -> floors of that side a touching neighbour covers. facade: false
## leaves `vox` empty for a subclass to fill (LandmarkVoxels).
func _init(
	p_building: RampageSim.Building, base: Color, party: Dictionary = {}, facade: bool = true
) -> void:
	b = p_building
	_party = party
	_make_palette(base)
	if not facade:
		return
	vox.cells = BuildingLayout.new(b, RES, party, _lit_share()).cells


## Which faces of `cell` BuildingMesher draws, one bit per BuildingMesher.NEIGHBOURS entry; -1:
## any face open to air, with the standing building's hollow counted as solid.
func face_mask(_cell: Vector3i) -> int:
	return -1


func archetype() -> int:
	return b.style % 4


## World position of cell (0, 0, 0)'s centre column (its floor 0's: under the street for a
## bridge piece, Building.base).
func origin() -> Vector3:
	return Vector3(b.x - b.w * 0.5 + VOXEL * 0.5, float(b.base), b.z - b.d * 0.5 + VOXEL * 0.5)


func _make_palette(base: Color) -> void:
	var lit := Look.color("window_lit_color")
	lit.a = WindowPalette.TAG if Look.value("window_glow") > 0.0 else 1.0
	var sill := base.lightened(0.28)
	var shop_lit := Color("ffd9a0")
	shop_lit.a = lit.a
	palette = {
		"wall": base,
		"pillar": base.darkened(0.1),
		"trim": base.lightened(0.16),
		"sill": sill,
		"window": Look.color("window"),
		"frame": base.darkened(0.3),
		"lit": lit,
		"glass": Look.color("window").lerp(base, 0.3).lightened(0.1),
		"mullion": base.darkened(0.45),
		"spandrel": base.darkened(0.18),
		"party": base.darkened(0.06),
		"shop": Color("1e2429"),
		"shop_lit": shop_lit,
		"awning": AWNINGS[posmod(roundi(b.x + b.z * 3.0), AWNINGS.size())],
		"band": SIGN_BANDS[posmod(roundi(b.x * 7.0 + b.z), SIGN_BANDS.size())],
		"rail": sill,  # D-303: balcony railings take the sill tone
		"slab": Color("8a8780"),
		"roof": Look.color("roof"),
		"gear": Color("a9aaa4"),
		"vent": Color("3a3c3e"),
		"pipe": Color("6b6f72"),
		"tank": Color("6a5040"),
		"heater": Color("e6e8e4"),  # D-352: the white solar water heater
		"heater_hi": Color("f8faf6"),
		"solar": Color("1b2538"),
		"beacon": Color(1.0, 0.25, 0.2, 0.0),
		"sign_frame": Color("1c1e22"),
	}
	for i: int in NEON.size():
		var neon := NEON[i]
		neon.a = 0.0
		palette["neon%d" % i] = neon


## The share of windows lit (Look "window_lit"); a test view overrides it to 0.
func _lit_share() -> float:
	return Look.value("window_lit")
