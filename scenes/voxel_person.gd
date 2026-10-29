class_name VoxelPerson
extends RefCounted
## Voxel people for the streets: civilians and police officers, 11 cells tall (about two metres
## at the city's scale of one floor per unit), facing -Z, feet on y = 0. One baked mesh per
## outfit and pose; StreetLife draws every (outfit, pose) pair as one MultiMesh.
## Presentation only.

enum Pose { WALK_A, WALK_B, RUN_A, RUN_B, AIM }

const POSES := 5
## Civilian outfits, then the police uniform last.
const OUTFITS: Array[Dictionary] = [
	{"shirt": "8a3a32", "pants": "2f3440", "hair": "2a1f18", "skin": "e0b48e"},
	{"shirt": "c9c2b0", "pants": "3b3a36", "hair": "1a1714", "skin": "8d5a3b"},
	{"shirt": "3f5f7a", "pants": "57503f", "hair": "6a4a2a", "skin": "f0caa8"},
	{"shirt": "c08a2e", "pants": "2a2a2e", "hair": "3a2a20", "skin": "c58c5f"},
	{"shirt": "4f6a46", "pants": "4a4a50", "hair": "b8a888", "skin": "e0b48e"},
	{"shirt": "6a4a6e", "pants": "1f2630", "hair": "1a1714", "skin": "a06a46"},
	{"shirt": "1f2a44", "pants": "18202f", "hair": "101418", "skin": "c58c5f", "cop": true},
]
const COP := 6

## Rooftop defenders (D-063): armed citizens in their street clothes, and soldiers in drab with
## a helmet (the "hair" cell row).
const ROOFTOP_OUTFITS: Array[Dictionary] = [
	{"shirt": "8a3a32", "pants": "2f3440", "hair": "2a1f18", "skin": "e0b48e"},
	{"shirt": "c9c2b0", "pants": "3b3a36", "hair": "1a1714", "skin": "8d5a3b"},
	{"shirt": "4a5233", "pants": "3d4230", "hair": "39402a", "skin": "c58c5f"},
	{"shirt": "3f5f7a", "pants": "57503f", "hair": "6a4a2a", "skin": "f0caa8"},
	{"shirt": "4a5233", "pants": "3d4230", "hair": "39402a", "skin": "e0b48e"},
]


static func mesh(outfit: int, pose: int, voxel: float) -> ArrayMesh:
	var o: Dictionary = OUTFITS[outfit]
	var v := VoxelBuilder.new()
	v.salt = outfit * POSES + pose
	var cop: bool = o.get("cop", false)
	_body(v, pose, cop)
	return _bake(v, o, voxel)


## A figure in any outfit ({shirt, pants, hair, skin} hex colours): a stadium's players (D-078).
static func dressed(outfit: Dictionary, pose: int, voxel: float) -> ArrayMesh:
	var v := VoxelBuilder.new()
	v.salt = 53 + pose
	_body(v, pose, false)
	return _bake(v, outfit, voxel)


## A stadium spectator (director 2026-10-18): seated facing -Z, hips on y = 0 and shins down
## the seat's front to the row below, hands in the lap; 9 cells tall in all.
static func seated(outfit: Dictionary, voxel: float) -> ArrayMesh:
	var v := VoxelBuilder.new()
	v.salt = 61
	for x: int in [-2, 1]:
		v.box(Vector3i(x, -2, -3), Vector3i(x, -1, -3), "pants")  # shins
		v.put(Vector3i(x, -3, -3), "shoe")
		v.put(Vector3i(x, -3, -4), "shoe")
	v.box(Vector3i(-2, 0, -3), Vector3i(1, 0, 0), "pants")  # thighs and seat
	v.box(Vector3i(-2, 1, -1), Vector3i(1, 3, 0), "shirt")  # torso
	v.box(Vector3i(-1, 4, -1), Vector3i(0, 4, -1), "skin")  # face
	v.box(Vector3i(-1, 4, 0), Vector3i(0, 4, 0), "hair")
	v.box(Vector3i(-1, 5, -1), Vector3i(0, 5, 0), "hair")
	for x: int in [-3, 2]:
		v.box(Vector3i(x, 2, 0), Vector3i(x, 3, 0), "shirt")  # upper arms
		v.put(Vector3i(x, 1, -1), "shirt")
		v.put(Vector3i(x, 1, -2), "skin")  # hands on the knees
	return _bake(v, outfit, voxel)


## A rooftop defender (D-063): the aiming pose with a rifle in place of the pistol, its barrel
## two cells wide and running three cells past the hands.
static func rifleman(outfit: int, voxel: float) -> ArrayMesh:
	var v := VoxelBuilder.new()
	v.salt = 97 + outfit
	_body(v, Pose.AIM, false)
	v.box(Vector3i(-1, 8, -7), Vector3i(0, 8, -4), "gun")
	v.box(Vector3i(-1, 9, -4), Vector3i(0, 9, -3), "gun")  # receiver against the hands
	return _bake(v, ROOFTOP_OUTFITS[outfit], voxel, true)


## detail: in the city's surface family (rooftop squads, flat surfaces P2).
static func _bake(v: VoxelBuilder, o: Dictionary, voxel: float, detail := false) -> ArrayMesh:
	var palette := {
		"shirt": Color(str(o["shirt"])),
		"pants": Color(str(o["pants"])),
		"hair": Color(str(o["hair"])),
		"skin": Color(str(o["skin"])),
		"shoe": Color("1a1a1a"),
		"gun": Color("161616"),
		"belt": Color("0e0e0e"),
	}
	# The body is symmetric about cell x = -0.5 and z = -0.5: centre it on the origin.
	return v.bake(palette, voxel, Vector3(voxel * 0.5, 0, voxel * 0.5), 0.0, detail)


static func _body(v: VoxelBuilder, pose: int, cop: bool) -> void:
	var stride: int = [1, -1, 2, -2, 1][pose]  # left foot's z offset (-z is forward)
	for leg: Vector2i in [Vector2i(-2, stride), Vector2i(1, -stride)]:  # (x, foot z)
		var x := leg.x
		var f := leg.y
		v.put(Vector3i(x, 0, f), "shoe")
		v.put(Vector3i(x, 0, f - 1), "shoe")  # toes point forward
		v.put(Vector3i(x, 1, f), "pants")
		v.put(Vector3i(x, 2, signi(f) if absi(f) > 1 else 0), "pants")  # knee
		v.box(Vector3i(x, 3, 0), Vector3i(x, 4, 0), "pants")
	v.box(Vector3i(-2, 5, -1), Vector3i(1, 5, 0), "belt" if cop else "pants")  # hips
	v.box(Vector3i(-2, 6, -1), Vector3i(1, 8, 0), "shirt")  # torso
	v.box(Vector3i(-1, 9, -1), Vector3i(0, 9, -1), "skin")  # face
	v.box(Vector3i(-1, 9, 0), Vector3i(0, 9, 0), "hair")
	v.box(Vector3i(-1, 10, -1), Vector3i(0, 10, 0), "hair")  # hair, or the officer's cap
	if cop:
		v.box(Vector3i(-1, 10, -2), Vector3i(0, 10, -2), "hair")  # cap brim
	match pose:
		Pose.RUN_A, Pose.RUN_B:  # arms flung up in panic
			for x: int in [-3, 2]:
				v.box(Vector3i(x, 8, 0), Vector3i(x, 10, 0), "shirt")
				v.put(Vector3i(x, 11, 0), "skin")
		Pose.AIM:  # both hands forward on a pistol
			for side: Vector2i in [Vector2i(-3, 1), Vector2i(2, -1)]:  # (shoulder x, inward step)
				v.put(Vector3i(side.x, 8, -1), "shirt")
				v.put(Vector3i(side.x + side.y, 8, -2), "shirt")
				v.put(Vector3i(side.x + side.y * 2, 8, -3), "skin")
			v.box(Vector3i(-1, 8, -4), Vector3i(0, 8, -4), "gun")
			v.put(Vector3i(-1, 9, -4), "gun")
		_:  # arms swing against the legs
			for arm: Vector2i in [Vector2i(-3, -signi(stride)), Vector2i(2, signi(stride))]:
				v.box(Vector3i(arm.x, 7, 0), Vector3i(arm.x, 8, 0), "shirt")
				v.put(Vector3i(arm.x, 6, arm.y), "shirt")
				v.put(Vector3i(arm.x, 5, arm.y), "skin")
