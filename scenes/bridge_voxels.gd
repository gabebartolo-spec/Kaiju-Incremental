class_name BridgeVoxels
extends BuildingVoxels
## A river bridge piece's voxels (D-389): BridgeLayout's cells, the very grid the sim carves
## (BuildingCells packs the same layout), drawn and broken chunk by chunk by BuildingMesher and
## BuildingView like any building, from the riverbed up (origin() is Building.base under the
## street). The deck in the street's asphalt, the parapets and piers in the bank walls' stone
## (CityGround's colours); every face open to air is drawn (it has no hollow inside).

## How much lighter than the pavement the stone is (CityGround's bank walls and parapets).
const STONE_LIFT := 0.12


func _init(p_building: RampageSim.Building, base: Color) -> void:
	super(p_building, base, {}, false)
	var laid: Dictionary = BridgeLayout.laid(b, Content.section("bridge"), RES)[0]
	vox.cells = laid.duplicate()
	var stone := Look.color("lot").lightened(STONE_LIFT)
	palette["bridge_deck"] = Look.color("asphalt")
	palette["bridge_parapet"] = stone
	palette["bridge_pier"] = stone


## Every face that meets air (the riverbed's is never drawn).
func face_mask(cell: Vector3i) -> int:
	var mask := 0
	for k: int in BuildingMesher.NEIGHBOURS.size():
		var n := cell + BuildingMesher.NEIGHBOURS[k]
		if n.y >= 0 and not vox.cells.has(n):
			mask |= 1 << k
	return mask
