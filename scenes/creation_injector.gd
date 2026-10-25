class_name CreationInjector
extends Node3D
## The lab's injector (D-207; the director 2026-10-25: "injector rotates to the croc vial, drains
## it, moves to dish and puts croc gene into dish", then the same from the Special K canister, "i do
## NOT want the vials magically flying over to the dish"; "Use image A whole"). The Tripo injector
## in the set's blocks, split into a static post and a carriage (the boom and the syringe head)
## that rises on the post, turns about it and slides in and out through it (so the needle reaches
## every vial, not only those at the boom's own length), like a lab pick-and-place arm. A trip
## (t 0..1): rise,
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
	_seat(post)
	var voxel := Num.f(CreationSet.cfg()["voxel"])
	var glow := Num.f(CreationSet.cfg()["glow"])
	var post_node := Node3D.new()
	add_child(post_node)
	post.inset = CreationSet.gapless()
	post_node.add_child(post.build({}, voxel, glow, Vector3.ZERO))
	var tc: Array = cfg["tip"]
	var tip_cell := Vector3i(Num.i(tc[0]), Num.i(tc[1]), Num.i(tc[2])) - pivot
	tip_cell = _lengthen(carriage, tip_cell, Num.i(cfg["needle"]))
	_carriage = Node3D.new()
	add_child(_carriage)
	carriage.inset = CreationSet.gapless()
	_carriage.add_child(carriage.build({}, voxel, glow, Vector3.ZERO))
	barrel = CreationLiquid.new(glass, CreationSet.color("special_k"), 0.0)
	_carriage.add_child(barrel.node)
	_no_shadows()
	_tip_local = Vector3(tip_cell) * voxel + Vector3(0.0, voxel * 0.5, 0.0)
	# The base plate reaches out on the head's side: it is turned away from the dish.
	var away := Vector2(position.x, position.z)
	post_node.rotation.y = atan2(-away.y, away.x)
	_pose(aim(Vector3.ZERO), lift_for(Num.f(cfg["park_tip"])))


## It casts no shadow: under the key lamp the head's shadow lay on the agar as a blot.
func _no_shadows() -> void:
	for mmi: Node in find_children("*", "MultiMeshInstance3D", true, false):
		(mmi as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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


## Drops the post's blocks that would sit inside the cradle's rim (post_seat metres from the dish's
## axis), so the foot stands clear of it instead of fusing into it.
func _seat(post: VoxelBuilder) -> void:
	var voxel := Num.f(CreationSet.cfg()["voxel"])
	var seat := Num.f(_cfg()["post_seat"])
	var away := Vector2(position.x, position.z)
	var turn := atan2(-away.y, away.x)
	for cell: Vector3i in post.colors.keys():
		var w := Vector3(cell.x, 0, cell.z).rotated(Vector3.UP, turn) * voxel
		if Vector2(position.x + w.x, position.z + w.z).length() < seat:
			post.cells.erase(cell)
			post.colors.erase(cell)


## The model's needle is a short stub that hid in the ports: it goes on `cells` further down in
## thin steel (a cross, then one block at the point). Returns the new tip cell.
static func _lengthen(carriage: VoxelBuilder, tip: Vector3i, cells: int) -> Vector3i:
	var steel := CreationSet.color("needle")
	for i: int in range(1, cells + 1):
		var at := tip - Vector3i(0, i, 0)
		carriage.put_color(at, steel)
		if i <= cells - 3:
			for d: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				carriage.put_color(at + d, steel)
	return tip - Vector3i(0, cells, 0)


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


## How far the boom slides out (metres, back if negative) to put the needle over `target`.
func slide_for(target: Vector3) -> float:
	return Vector2(target.x - position.x, target.z - position.z).length() - reach()


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
	var pose: Vector3 = poses[0]
	var placed := false
	for i: int in shares.size():
		var share := Num.f(shares[i])
		if share <= 0.0:
			continue
		var k := clampf((t - acc) / share, 0.0, 1.0)
		progress[i] = k
		if not placed and t <= acc + share:
			var last := i == shares.size() - 1 or _rest_zero(shares, i + 1)
			var e := k * k if last else smoothstep(0.0, 1.0, k)
			var a := poses[i]
			var b := poses[i + 1]
			pose = Vector3(lerp_angle(a.x, b.x, e), lerpf(a.y, b.y, e), lerpf(a.z, b.z, e))
			placed = true
		acc += share
		end = i + 1
	if not placed:
		pose = poses[end]
	_pose(pose.x, pose.y, pose.z)
	return Vector2(progress[3], progress[7])


static func _rest_zero(shares: Array, from: int) -> bool:
	for j: int in range(from, shares.size()):
		if Num.f(shares[j]) > 0.0:
			return false
	return true


## The trip's poses (turn, rise, slide) at each phase's end, from the park over the dish; the boom
## slides as it turns.
func _poses(source: Vector3, heights: Vector3) -> Array[Vector3]:
	var home := aim(Vector3.ZERO)
	var there := aim(source)
	var up := lift_for(heights.y)
	var down := lift_for(heights.x)
	var dish := lift_for(heights.z)
	var park := lift_for(Num.f(_cfg()["park_tip"]))
	var out := slide_for(source)
	return [
		Vector3(home, park, 0.0),
		Vector3(home, up, 0.0),
		Vector3(there, up, out),
		Vector3(there, down, out),
		Vector3(there, down, out),
		Vector3(there, up, out),
		Vector3(home, up, 0.0),
		Vector3(home, dish, 0.0),
		Vector3(home, dish, 0.0),
		Vector3(home, park, 0.0),
	]


## The needle rises out of the agar to its park over the dish (k 0..1).
func rest(k: float, dish_tip: float) -> void:
	var e := smoothstep(0.0, 1.0, k)
	_pose(aim(Vector3.ZERO), lerpf(lift_for(dish_tip), lift_for(Num.f(_cfg()["park_tip"])), e))


func _pose(yaw: float, lift: float, slide := 0.0) -> void:
	var out := (
		Vector3(_tip_local.x, 0.0, _tip_local.z).normalized().rotated(Vector3.UP, yaw) * slide
	)
	_carriage.rotation.y = yaw
	_carriage.position = Vector3(0.0, lift, 0.0) + out
	tip = position + _carriage.position + _tip_local.rotated(Vector3.UP, yaw)
