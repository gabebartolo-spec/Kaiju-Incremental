extends "res://tests/lib/runner.gd"
## Landmark cells suite: the sim's fine grid of a landmark (LandmarkCells, D-094 WP6) is the grid
## the view draws (LandmarkVoxels) cell for cell, the same every time, in the chunks the sim
## builds; a ring's arcs (the stadium) shed a whole section on the fine grid as they do on chunks;
## a landmark gets its grid on its first hit (CellPromoter). Not wired into the rampage (WP7).
## Seeded by design: the model is baked data and nothing here draws a random number.
##   godot --headless --path . --script tests/run_landmarkcells_tests.gd

## Per landmark: [cells, digest] (first 16 hex digits of the grid's SHA-256 with its dims).
const PINNED := {
	"stadium": [95493, "94482793d0eef362"],
	"wheel": [61577, "84994f8dff691b8c"],
}
## Stadium material counts [wall, seat, pitch, other].
const PINNED_CLASSES: Array = [61528, 24066, 7864, 2035]
## The stadium section a foot hit brings down: [cells, digest of its cells].
const PINNED_SECTION: Array = [1820, "2a1f5d63b106c629"]
## LandmarkCells compiles before RampageSim (a const resolves first). Reached the other way, through
## Landmarks.building() and RampageSim.Building, the engine never frees the two scripts' cycle and
## the exit leaks 31 scripts (debt row 2): loading the grid script first keeps the exit clean.
const _CELLS := preload("res://sim/landmark_cells.gd")
const L := preload("res://tests/lib/landmark_cells_lib.gd")
const MODULES: Array[String] = [
	"res://sim/cell_grid.gd", "res://sim/landmark_cells.gd", "res://sim/cell_promoter.gd"
]
const CLASSES: Array[String] = [
	"landmark_wall", "landmark_seat", "landmark_pitch", "landmark_other"
]


func suite_name() -> String:
	return "Landmarkcells"


func run_checks() -> void:
	await _t("_check_materials")
	await _t("_check_matches_view")
	await _t("_check_pinned")
	await _t("_check_deterministic")
	await _t("_check_no_islands")
	await _t("_check_arcs_foot_hit")
	await _t("_check_arcs_small_hit")
	await _t("_check_arcs_all")
	await _t("_check_promotion")
	await _t("_check_no_clock_or_rng")


## The landmark as the city builds it: its baked chunks, its arcs from the city tuning.
func _landmark(id: String) -> RampageSim.Building:
	var shape: Dictionary = Content.landmarks()[id]
	var entry := {
		"x": 0.0,
		"z": 0.0,
		"w": shape["w"],
		"d": shape["d"],
		"h": shape["h"],
		"tier": 1,
		"style": 0,
		"landmark": id,
		"chunks": shape["chunks"],
		"rubble_bonus": 1.5,
	}
	for spec: Dictionary in Content.section("city")["landmarks"]:
		if str(spec["id"]) == id and spec.has("arcs"):
			entry["arcs"] = spec["arcs"]
	return Landmarks.building(entry, 1.0)


func _check_materials() -> void:
	var ids := CellGrid.material_ids()
	check(CLASSES.all(func(k: String) -> bool: return ids.has(k)), "the landmark_ materials exist")
	var used := {}
	for id: String in ["stadium", "wheel"]:
		var g := LandmarkCells.new(_landmark(id))
		for i: int in g.cells.size():
			used[g.cells[i]] = true
	used.erase(0)
	var listed: bool = used.keys().all(func(k: int) -> bool: return ids.values().has(k))
	check(
		listed and used.size() == 4,
		"the two landmarks use the four classes (%d used)" % used.size()
	)


## Cell for cell the view's voxels (LandmarkVoxels): the same cells, each in its colour's class,
## each in a chunk the sim built, and the same chunks as the view's.
func _check_matches_view() -> void:
	var ids := CellGrid.material_ids()
	for id: String in ["stadium", "wheel"]:
		var b := _landmark(id)
		var g := LandmarkCells.new(b)
		var view := LandmarkVoxels.new(b, Color.GRAY)
		var shape: Dictionary = Content.landmarks()[id]
		var ground: Array = shape.get("ground", [])
		var bad := absi(g.count() - view.vox.colors.size())
		var stray := 0
		var seen := {}
		for cell: Vector3i in view.vox.colors:
			var colour: Color = view.vox.colors[cell]
			var want := Num.i(ids[L.class_of(colour, ground)])
			bad += 0 if g.at(cell) == want else 1
			stray += 0 if b.frame.alive(L.chunk(cell)) else 1
			seen[L.chunk(cell)] = true
		var mine := {}
		for i: int in g.cells.size():
			if g.cells[i] != 0:
				mine[L.chunk(L.cell(g, i))] = 1
		check(
			bad == 0 and stray == 0 and mine.size() == seen.size() and g.count() > 10000,
			(
				"%s matches the view: %d cells, %d off, %d outside the sim's chunks, %d/%d chunks"
				% [id, g.count(), bad, stray, mine.size(), seen.size()]
			)
		)


func _check_pinned() -> void:
	var tally := [0, 0, 0, 0]
	for id: String in ["stadium", "wheel"]:
		var g := LandmarkCells.new(_landmark(id))
		var have: Array = [g.count(), L.digest(g)]
		var want: Array = PINNED[id]
		check(want == have, "%s pinned at %s (got %s)" % [id, want, have])
		if id == "stadium":
			for k: int in 4:
				tally[k] = g.cells.count(Num.i(CellGrid.material_ids()[CLASSES[k]]))
	check(
		tally == PINNED_CLASSES, "stadium classes pinned at %s (got %s)" % [PINNED_CLASSES, tally]
	)


## The fixture rule: before any carve a landmark is one part joined to the ground under
## VoxelSupport's real rule. The raw shell was not (stadium 157 loose parts / 49,443 cells, wheel
## 56 / 53,348, joined only by an edge or corner); `bake.py --connect` adds the missing cells to
## the baked file, which the view and the sim both read.
func _check_no_islands() -> void:
	for id: String in ["stadium", "wheel"]:
		var g := LandmarkCells.new(_landmark(id))
		var frame := VoxelFrame.new(Vector3i.ONE, g.res, Content.materials())
		var adopted := frame.adopt(g.dims, g.offset, g.cells)
		var parts := 0
		var cut := 0
		if adopted:
			for part: PackedInt32Array in VoxelSupport.new(frame).islands():
				parts += 1
				cut += part.size()
		check(
			adopted and parts == 0 and cut == 0,
			"%s has no island before any carve (%d parts, %d cells cut off)" % [id, parts, cut]
		)


func _check_deterministic() -> void:
	var same := true
	for id: String in ["stadium", "wheel"]:
		var a := LandmarkCells.new(_landmark(id))
		var b := LandmarkCells.new(_landmark(id))
		same = same and a.cells == b.cells and a.dims == b.dims and a.offset == b.offset
	check(same, "both landmarks build the same grid twice")


## The foot chunk of the stadium's rim (the chunk test's).
func _foot(b: RampageSim.Building) -> Vector3i:
	var foot := Vector3i(b.w / 2, 0, b.d - 1)
	while foot.z > 0 and not b.frame.alive(foot):
		foot.z -= 1
	return foot


## Loses the cells of one chunk; returns how many it held.
func _lose_chunk(g: LandmarkCells, chunk: Vector3i) -> int:
	var before := g.count()
	g.clear_chunk(chunk)
	return before - g.count()


func _section_digest(cells: Array[Vector3i]) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(cells))
	return ctx.finish().hex_encode().substr(0, 16)


## A hit at the foot of the rim brings its arc down outward over the stub, as one section that
## is the chunk Structure's section for the same hit; a hit on the pitch brings nothing down.
func _check_arcs_foot_hit() -> void:
	var b := _landmark("stadium")
	var g := LandmarkCells.new(b)
	var foot := _foot(b)
	var arc := b.frame.arcs.arc_at(foot.x, foot.z)
	var lost := _lose_chunk(g, foot)
	var parts := g.shed()
	var part: Dictionary = parts[0] if parts.size() == 1 else {}
	var section: Array[Vector3i] = part.get("cells", [] as Array[Vector3i])
	var stub := b.frame.arcs.stub * g.res
	var pivot: Vector3 = part.get("pivot", Vector3.ZERO)
	var ok: bool = (
		str(part.get("kind", "")) == "topple"
		and part.get("dir", Vector2i.ZERO) == Vector2i(0, 1)
		and section.all(func(c: Vector3i) -> bool: return c.y >= stub and g.arc_of(c) == arc)
		and is_equal_approx(pivot.y, stub)
	)
	check(
		ok and section.size() >= 100,
		(
			"a foot hit (%d cells lost) sheds its arc outward above the %d-cell stub: %d cells"
			% [lost, stub, section.size()]
		)
	)
	# The chunk Structure's answer to the same hit.
	var twin := _landmark("stadium")
	twin.frame.damage(foot, 1.0e6)
	var chunk_part: Array[Vector3i] = twin.frame.settle()[0]["cells"]
	var chunks := {}
	for c: Vector3i in chunk_part:
		chunks[c] = true
	var inside := section.all(func(c: Vector3i) -> bool: return chunks.has(L.chunk(c)))
	var mine := {}
	for c: Vector3i in section:
		mine[L.chunk(c)] = true
	# A chunk of the Structure's section that holds no model cell has none to shed.
	var occupied := {}
	var whole := LandmarkCells.new(_landmark("stadium"))
	for i: int in whole.cells.size():
		if whole.cells[i] != 0 and chunks.has(L.chunk(L.cell(whole, i))):
			occupied[L.chunk(L.cell(whole, i))] = true
	check(
		inside and mine.size() == occupied.size() and mine.size() >= 20,
		(
			"the section is the chunk Structure's: %d chunks of its %d (%d hold model cells)"
			% [mine.size(), chunks.size(), occupied.size()]
		)
	)
	var have: Array = [section.size(), _section_digest(section)]
	check(
		have == PINNED_SECTION,
		"the foot-hit section pinned at %s (got %s)" % [PINNED_SECTION, have]
	)
	for c: Vector3i in section:
		g.clear_cell(c)
	check(g.shed().is_empty(), "once cleared the arc does not shed again")
	var pitch := _lose_chunk(g, Vector3i(b.w / 2, 0, b.d / 2))
	check(g.shed().is_empty(), "a hit on the pitch (%d cells) brings nothing down" % pitch)


## Under arc_shed_cells lost, an arc stays up; the threshold cell tips it.
func _check_arcs_small_hit() -> void:
	var b := _landmark("stadium")
	var g := LandmarkCells.new(b)
	var foot := _foot(b)
	var need := Num.i(Content.section("destruction")["arc_shed_cells"])
	var cleared := 0
	var early := false
	var tipped := false
	for z: int in range(foot.z * g.res, (foot.z + 1) * g.res):
		for y: int in range(g.res):
			for x: int in range(foot.x * g.res, (foot.x + 1) * g.res):
				var cell := Vector3i(x, y, z)
				if g.at(cell) == 0 or tipped:
					continue
				g.clear_cell(cell)
				cleared += 1
				var parts := g.shed()
				if cleared < need and not parts.is_empty():
					early = true
				if cleared == need and parts.size() == 1:
					tipped = true
	check(
		cleared >= need and not early and tipped,
		"%d lost cells tip the arc, none fewer (%d cleared, early %s)" % [need, cleared, early]
	)


## Enough loss in every arc (the lowest arc_shed_cells cells of each) brings every arc down:
## nothing but the corner masts is left above the stub (no sliver of wall outside the arcs),
## the chunk test's rule on cells.
func _check_arcs_all() -> void:
	var b := _landmark("stadium")
	var g := LandmarkCells.new(b)
	var need := Num.i(Content.section("destruction")["arc_shed_cells"])
	var hit := {}
	var sections := 0
	var first: Array[Vector3i] = []
	for i: int in g.cells.size():
		var arc := g.arc_of(L.cell(g, i)) if g.cells[i] != 0 else -1
		if arc >= 0 and hit.get(arc, 0) < need:
			hit[arc] = hit.get(arc, 0) + 1
			first.append(L.cell(g, i))
	for c: Vector3i in first:
		g.clear_cell(c)
	for part: Dictionary in g.shed():
		sections += 1
		for c: Vector3i in part["cells"]:
			g.clear_cell(c)
	var stub := b.frame.arcs.stub * g.res
	var left := 0
	for i: int in g.cells.size():
		if g.cells[i] != 0:
			var c := L.cell(g, i)
			left += 1 if c.y >= stub and g.arc_of(c) >= 0 else 0
	check(
		sections == hit.size() and left == 0,
		(
			"%d arcs hit, %d sections shed, %d arc cells left above the stub"
			% [hit.size(), sections, left]
		)
	)


## A landmark has no grid until its first hit; the first hit makes it with the chunks already
## lost emptied and no new loss for its arcs; later hits get the same grid.
func _check_promotion() -> void:
	var p := CellPromoter.new()
	var b := _landmark("stadium")
	check(not p.promoted(1) and p.grid(1) == null, "no landmark grid before the first hit")
	var foot := _foot(b)
	var held := _lose_chunk(LandmarkCells.new(_landmark("stadium")), foot)
	b.frame.remove(foot)
	var g := p.on_hit(1, b)
	check(
		g is LandmarkCells and p.promoted(1) and p.grid(1) == g,
		"the first hit makes a LandmarkCells"
	)
	check(
		held > 0 and g.count() == LandmarkCells.new(_landmark("stadium")).count() - held,
		"the lost chunk's %d cells are empty in the new grid" % held
	)
	check(
		(g as LandmarkCells).shed().is_empty(),
		"a loss the chunks already settled is not a new loss for the arcs"
	)
	check(p.on_hit(1, b) == g and p.grids.size() == 1, "a second hit keeps the same grid")
	var wheel := p.on_hit(2, _landmark("wheel")) as LandmarkCells
	check(wheel != null and wheel.arcs == null, "the wheel gets a grid without arcs")
	check(wheel.shed().is_empty(), "a landmark without arcs never sheds")


func _check_no_clock_or_rng() -> void:
	var bad := L.forbidden(
		'var t := Time.get_ticks_msec()\nvar r := randi() # Look.\nload("res://scenes/x.gd")'
	)
	check(
		bad.size() == 3,
		"the grep catches a clock, an RNG call and a scenes/ path (%d)" % bad.size()
	)
	for path: String in MODULES:
		var hits := L.forbidden(FileAccess.get_file_as_string(path))
		check(
			FileAccess.file_exists(path) and hits.is_empty(),
			"%s reads no clock or RNG: %s" % [path, hits]
		)
