class_name CreationInjector
extends Node3D
## The lab's injector (D-207; the director 2026-10-25: "injector rotates to the croc vial, drains
## it, moves to dish and puts croc gene into dish", then the same from the Special K canister, "i do
## NOT want the vials magically flying over to the dish"; "Use image A whole"). The Tripo injector
## in the set's blocks, split into a static post and a carriage (the boom and the syringe head)
## that rises on the post and turns about it, like a lab pick-and-place arm. A trip (t 0..1): rise,
## turn to the source, lower the needle into it, draw, rise, turn back, lower into the agar,
## dispense, park. The node stands at the post's axis; every size and share is in tuning
## "creation" "lab" "injector" and "trips".

## Where the needle tip is this tick, in the world (tests read it).
var tip := Vector3.ZERO
## The syringe head's glass, filled as it draws (its colour set by the trip's source).
var barrel: CreationLiquid
var _carriage: Node3D
var _tip_local := Vector3.ZERO


func _ready() -> void:
	var cfg := _cfg()
	var vox := CreationSet.read("injector")
	var pv: Array = cfg["pivot"]
	var pivot := Vector3i(Num.i(pv[0]), 0, Num.i(pv[1]))
	var post := VoxelBuilder.new()
	var carriage := VoxelBuilder.new()
	var glass := {}
	for cell: Vector3i in vox.colors:
		var col: Color = vox.colors[cell]
		var at := cell - pivot
		if not _on_carriage(cell, cfg):
			post.put_color(at, col)
		elif _in_barrel(cell, col, cfg):
			glass[at] = col
		else:
			carriage.put_color(at, col)
	_extend_post(post, Num.i(cfg["profile_y"]), Num.i(cfg["split_y"]), Num.i(cfg["post_extend"]))
	var voxel := Num.f(CreationSet.cfg()["voxel"])
	var glow := Num.f(CreationSet.cfg()["glow"])
	var post_node := Node3D.new()
	add_child(post_node)
	post.inset = CreationSet.gapless()
	post_node.add_child(post.build({}, voxel, glow, Vector3.ZERO))
	_carriage = Node3D.new()
	add_child(_carriage)
	carriage.inset = CreationSet.gapless()
	_carriage.add_child(carriage.build({}, voxel, glow, Vector3.ZERO))
	barrel = CreationLiquid.new(glass, CreationSet.color("special_k"), 0.0)
	_carriage.add_child(barrel.node)
	# It casts no shadow: under the key lamp the head's shadow lay on the agar as a blot.
	for mmi: Node in find_children("*", "MultiMeshInstance3D", true, false):
		(mmi as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tc: Array = cfg["tip"]
	var tip_cell := Vector3i(Num.i(tc[0]), Num.i(tc[1]), Num.i(tc[2])) - pivot
	_tip_local = Vector3(tip_cell) * voxel + Vector3(0.0, voxel * 0.5, 0.0)
	# The base plate reaches out on the head's side: it is turned away from the dish.
	var away := Vector2(position.x, position.z)
	post_node.rotation.y = atan2(-away.y, away.x)
	_pose(aim(Vector3.ZERO), lift_for(Num.f(cfg["park_tip"])))


static func _cfg() -> Dictionary:
	return CreationSet.cfg()["injector"]


static func _on_carriage(cell: Vector3i, cfg: Dictionary) -> bool:
	return cell.x >= Num.i(cfg["split_x"]) or cell.y >= Num.i(cfg["split_y"])


## The head's glass: the bright cells inside the barrel's ring and height.
static func _in_barrel(cell: Vector3i, col: Color, cfg: Dictionary) -> bool:
	var b: Dictionary = cfg["barrel"]
	var c: Array = b["centre"]
	var ys: Array = b["y"]
	if cell.y < Num.i(ys[0]) or cell.y > Num.i(ys[1]) or col.v < Num.f(b["min_light"]):
		return false
	var d := Vector2(cell.x - Num.f(c[0]), cell.z - Num.f(c[1]))
	return d.length() <= Num.f(b["radius"])


## The post's column, its cross-section at `profile` repeated from `from` for `cells` up, so the
## carriage has a post to ride when it rises.
static func _extend_post(post: VoxelBuilder, profile: int, from: int, cells: int) -> void:
	var ring: Array[Vector3i] = []
	for cell: Vector3i in post.colors:
		if cell.y == profile:
			ring.append(cell)
	for y: int in range(from, from + cells):
		for cell: Vector3i in ring:
			var col: Color = post.colors[cell]
			post.put_color(Vector3i(cell.x, y, cell.z), col)


## How far the needle reaches from the post's axis (metres).
static func reach() -> float:
	var cfg := _cfg()
	var tc: Array = cfg["tip"]
	var pv: Array = cfg["pivot"]
	var d := Vector2(Num.f(tc[0]) - Num.f(pv[0]), Num.f(tc[2]) - Num.f(pv[1]))
	return d.length() * Num.f(CreationSet.cfg()["voxel"])


## The carriage's turn that puts the needle over `target` (the lab's space, the dish at its origin).
func aim(target: Vector3) -> float:
	var d := target - position
	return atan2(-d.z, d.x) - atan2(-_tip_local.z, _tip_local.x)


## The carriage's rise that puts the needle tip at height `h` (metres above the bench).
func lift_for(h: float) -> float:
	return h - _tip_local.y


## Which phase of a trip (tuning "trips" `key`) progress t is in: 0 rise, 1 turn to the source,
## 2 lower, 3 draw, 4 rise, 5 turn back, 6 lower, 7 dispense, 8 park.
static func phase(t: float, key: String) -> int:
	var shares: Array = CreationSet.cfg()["trips"][key]
	var acc := 0.0
	for i: int in shares.size():
		acc += Num.f(shares[i])
		if t < acc:
			return i
	return shares.size() - 1


## One trip (t 0..1) to `source` and back to the dish, on the shares of tuning "trips" `key`.
## heights: the needle's depth in the source, the swing height and the depth in the dish. Returns
## (draw, dispense) progress, each 0..1, for the liquids.
func trip(t: float, key: String, source: Vector3, heights: Vector3) -> Vector2:
	var shares: Array = CreationSet.cfg()["trips"][key]
	var poses := _poses(source, heights)
	var acc := 0.0
	var end := 0
	var progress := PackedFloat32Array()
	progress.resize(shares.size())
	var pose := poses[0]
	var placed := false
	for i: int in shares.size():
		var share := Num.f(shares[i])
		if share <= 0.0:
			continue
		var k := clampf((t - acc) / share, 0.0, 1.0)
		progress[i] = k
		if not placed and t <= acc + share:
			var e := smoothstep(0.0, 1.0, k)
			var a := poses[i]
			var b := poses[i + 1]
			pose = Vector2(lerp_angle(a.x, b.x, e), lerpf(a.y, b.y, e))
			placed = true
		acc += share
		end = i + 1
	if not placed:
		pose = poses[end]
	_pose(pose.x, pose.y)
	return Vector2(progress[3], progress[7])


## The trip's poses (turn, rise) at each phase's end, from the park over the dish.
func _poses(source: Vector3, heights: Vector3) -> Array[Vector2]:
	var home := aim(Vector3.ZERO)
	var there := aim(source)
	var up := lift_for(heights.y)
	var down := lift_for(heights.x)
	var dish := lift_for(heights.z)
	var park := lift_for(Num.f(_cfg()["park_tip"]))
	return [
		Vector2(home, park),
		Vector2(home, up),
		Vector2(there, up),
		Vector2(there, down),
		Vector2(there, down),
		Vector2(there, up),
		Vector2(home, up),
		Vector2(home, dish),
		Vector2(home, dish),
		Vector2(home, park),
	]


## The needle rises out of the agar to its park over the dish (k 0..1).
func rest(k: float, dish_tip: float) -> void:
	var e := smoothstep(0.0, 1.0, k)
	_pose(aim(Vector3.ZERO), lerpf(lift_for(dish_tip), lift_for(Num.f(_cfg()["park_tip"])), e))


func _pose(yaw: float, lift: float) -> void:
	_carriage.rotation.y = yaw
	_carriage.position.y = lift
	tip = position + Vector3(0.0, lift, 0.0) + _tip_local.rotated(Vector3.UP, yaw)
