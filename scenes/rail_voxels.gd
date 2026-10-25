class_name RailVoxels
extends BuildingVoxels
## A railway piece's voxels (the viaduct, and the station round its stop): RailLayout's cells, the
## very grid the sim carves (BuildingCells packs the same layout), drawn and broken chunk by chunk
## by BuildingMesher and BuildingView like any building. Its materials draw in the railway's
## colours (tuning rail_look); every face open to air is drawn (it has no hollow inside).

## Material name -> rail_look colour key.
const COLORS := {
	"viaduct_concrete": "concrete",
	"viaduct_seam": "seam_concrete",
	"viaduct_parapet": "parapet",
	"viaduct_ballast": "ballast",
	"viaduct_sleeper": "sleeper",
	"viaduct_rail": "rail",
	"viaduct_column": "column",
	"station_platform": "platform",
	"station_edge": "platform_edge",
	"station_canopy": "canopy",
	"station_rib": "canopy_rib",
	"station_sign": "sign",
	"station_stair": "stair",
}
## The glowing ones (alpha 0 in the palette: the shader's glow).
const GLOWS: Array[String] = ["station_sign"]


func _init(p_building: RampageSim.Building, base: Color) -> void:
	super(p_building, base, {}, false)
	var laid: Dictionary = RailLayout.laid(b, Content.section("rail"), RES)[0]
	vox.cells = laid.duplicate()
	var look: Dictionary = Content.section("rail_look")["colors"]
	for name: String in COLORS:
		var c := Color(str(look[COLORS[name]]))
		if name in GLOWS:
			c.a = 0.0
		palette[name] = c


## Every face that meets air (or the ground's top is never drawn below y = 0).
func face_mask(cell: Vector3i) -> int:
	var mask := 0
	for k: int in BuildingMesher.NEIGHBOURS.size():
		var n := cell + BuildingMesher.NEIGHBOURS[k]
		if n.y >= 0 and not vox.cells.has(n):
			mask |= 1 << k
	return mask
