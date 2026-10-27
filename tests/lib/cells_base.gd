extends "res://tests/lib/runner.gd"
## Shared set-up for the Cells suite (tests/run_cells_tests.gd): a building built from a fixture
## row, the digest of its grid, the sim grid compared with the view's voxels (unlit, then lit),
## and the grep for forbidden calls. It defines no test function, so it adds none to the suite's
## count.

## Text that must not appear in the module (comments stripped): RNG, clock, engine, view.
const FORBIDDEN: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"Seeds.",
	"Time.",
	"OS.",
	"Engine.",
	"Look.",
	"Node",
	"await ",
]


## The view with no window lit: every voxel carries its material's palette key.
class UnlitVoxels:
	extends BuildingVoxels

	func _lit_share() -> float:
		return 0.0


func _building(f: Array) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = f[1]
	b.z = f[2]
	b.w = f[3]
	b.d = f[4]
	b.height = f[5]
	b.tier = f[6]
	b.style = f[7]
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	return b


func _party(f: Array) -> Dictionary:
	var party: Dictionary = f[8]
	return party


func _digest(g: BuildingCells) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([g.dims, g.offset]))
	ctx.update(g.cells)
	return ctx.finish().hex_encode().substr(0, 16)


## Mismatched cells between the unlit view's voxels and the sim grid (0 = the same grid): each
## view voxel's palette key is exactly its sim cell's material name.
func _mismatches(b: RampageSim.Building, party: Dictionary) -> int:
	var g := BuildingCells.new(b, party)
	var vox := UnlitVoxels.new(b, Color.GRAY, party)
	var ids := BuildingCells.material_ids()
	var bad := absi(g.count() - vox.vox.cells.size())
	for cell: Vector3i in vox.vox.cells:
		if g.at(cell) != Num.i(ids.get(str(vox.vox.cells[cell]), -1)):
			bad += 1
	return bad


## [cells where the lit view is not the unlit one, of them not a lit pane over a window,
## mullion, glass or shop cell]; the two views must hold the same cells.
func _lit_changes(b: RampageSim.Building, party: Dictionary) -> Array[int]:
	var lit := BuildingVoxels.new(b, Color.GRAY, party).vox.cells
	var unlit := UnlitVoxels.new(b, Color.GRAY, party).vox.cells
	var changed := 0
	var bad := absi(lit.size() - unlit.size())
	for cell: Vector3i in unlit:
		var was := str(unlit[cell])
		var now := str(lit.get(cell, ""))
		if now == was:
			continue
		changed += 1
		var pane := now == "lit" and was in ["window", "mullion", "glass"]
		if not pane and not (now == "shop_lit" and was == "shop"):
			bad += 1
	return [changed, bad]


## The structural chunk (one sim unit, one floor) a building-local cell is in.
func _chunk(cell: Vector3i, r: int) -> Vector3i:
	return Vector3i(floori(float(cell.x) / r), floori(float(cell.y) / r), floori(float(cell.z) / r))


## Chunks (one sim unit, one floor) holding any cell in one grid and none in the other.
func _chunk_mismatches(b: RampageSim.Building, party: Dictionary) -> int:
	var g := BuildingCells.new(b, party)
	var vox := BuildingVoxels.new(b, Color.GRAY, party)
	var r := g.res
	var view := {}
	for cell: Vector3i in vox.vox.cells:
		view[_chunk(cell, r)] = 1
	var sim := {}
	for i: int in g.cells.size():
		if g.cells[i] != 0:
			var plan := g.dims.x * g.dims.z
			var c := Vector3i(i % g.dims.x, i / plan, (i / g.dims.x) % g.dims.z) + g.offset
			sim[_chunk(c, r)] = 1
	var bad := 0
	for c: Vector3i in view:
		bad += 0 if sim.has(c) else 1
	for c: Vector3i in sim:
		bad += 0 if view.has(c) else 1
	return bad


## Lines of `text` holding a forbidden call, comments stripped.
func _forbidden(text: String) -> Array[String]:
	var hits: Array[String] = []
	for line: String in text.split("\n"):
		var code := line.get_slice("#", 0)
		for token: String in FORBIDDEN:
			if code.contains(token):
				hits.append("%s: %s" % [token, line.strip_edges()])
	return hits
