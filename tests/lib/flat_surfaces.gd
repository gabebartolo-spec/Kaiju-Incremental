extends RefCounted
## No flat-colour surface in the city (director 2026-10-25: "flat textureless colour blocks need to
## go. ive told you like 6 times you better take a note"; #80 2026-10-21: "all surfaces must be
## textured and visually beautiful"). Builds the real city (a Rampage and its CityView), walks every
## MeshInstance3D and MultiMeshInstance3D surface and its override material, and fails
##   - a StandardMaterial3D with no albedo texture and no detail texture;
##   - a missing material (the engine's flat white);
##   - a ShaderMaterial whose shader neither samples a texture nor includes surface_detail.
## Visual-effect families (fire, smoke, rain, particles, sky, light shafts, UI) are exempt by node
## group (EXEMPT_GROUP) or by being a GPU/CPU particle or a node under a Control.
##
## KNOWN_FLAT is the one list of surface types not yet fixed, each tagged with the phase that fixes
## it. The list may only shrink: NO NEW ENTRY may ever be added (lead 2026-10-25). A new surface
## has to be textured (or include surface_detail.gdshaderinc) to land. A type is "<owner>:<kind>":
## the nearest scripted ancestor's class name and what is flat about it.

const ChunkCheck := preload("res://tests/lib/chunk_check.gd")
const DETAIL_INCLUDE := "surface_detail.gdshaderinc"
## Physics frames his death may take to reach the burst (about 3.2 s in data at 60 fps, with room).
const DEATH_FRAMES := 600
## Nodes in this group are visual effects, exempt from the rule.
const EXEMPT_GROUP := "vfx_exempt"

## Types still flat, by phase. P2 rooftops (flat black stripe, window panels); P3 trees,
## lamps, cars, people, gondolas; the sky belongs to the atmosphere lead. Delete lines as they are
## fixed; never add one. One row per entry (surface, owner, phase, next step) in docs/ROADMAP.md,
## "Flat surfaces programme".
## The cap on the list's size: it only ever goes DOWN. Lower it whenever an entry is removed; a
## test fails when KNOWN_FLAT has more entries than this (a new flat type may never be added).
const KNOWN_FLAT_MAX := 20
const KNOWN_FLAT: Dictionary = {
	# P0 (this phase; each is deleted when its surface is textured)
	"CitySkyline:std": "P3 lamp heads (glow)",
	"CitySkyline:shader:facade.gdshader": "P2 far towers and roof gear, P3 lattice tower",
	# facade_far.gdshader's twin with the engine fog (FarHaze, city far_fog on; comment #37)
	"CitySkyline:shader:facade_far_fogged.gdshader": "P2 far towers, P3 lattice tower",
	# P2 rooftops and building faces
	"BuildingStream:shader:facade.gdshader": "P2 building faces",
	"BuildingView:shader:voxel.gdshader": "P2 building faces",
	"RooftopView:shader:voxel.gdshader": "P2 rooftops",
	"RooftopView:std": "P2 rooftops",
	# P3 trees, lamps, props, cars, people, aircraft, crowds, debris, the kaiju
	"Aircraft:std": "P3 aircraft",
	"DebrisField:std": "P3 debris chunks",
	"CityDecor:shader:voxel.gdshader": "P3 trees, lamps, props",
	"Traffic:shader:voxel.gdshader": "P3 cars",
	"StreetLife:shader:voxel.gdshader": "P3 people",
	"Police:shader:voxel.gdshader": "P3 police",
	"StadiumMatch:shader:voxel.gdshader": "P3 stadium",
	"StadiumMatch:std": "P3 stadium",
	"StadiumCrowd:shader:crowd.gdshader": "P3 crowd",
	"ArenaEdge:std": "P3 arena bollards",
	"KaijuRig:shader:voxel.gdshader": "P3 the kaiju's own skin pipeline",
	"VoxelSkin:shader:voxel_skin.gdshader": "P3 the kaiju's own skin pipeline",
	"VoxelSkin:shader:voxel_skin_fill.gdshader": "P3 the kaiju's own skin pipeline",
}
## Effect families exempt by owner class (their nodes carry no group; VFX never reads as a
## surface): fire and smoke keepers, shockwaves, the breath beam, the claw sweep, the aim wedge, the
## flash of a shot landing on the hide (HideHit, under a tenth of a second).
const EXEMPT_OWNERS: Array[String] = [
	"Fx", "ShaderKeep", "BreathBeam", "AbilityFx", "BreathAim", "HideHit"
]


## Every flat surface under `root` as {type, node, count}, one per type.
static func scan(root: Node) -> Dictionary:
	var found := {}
	for node: Node in _walk(root):
		if node is GeometryInstance3D and not _exempt(node):
			for flat: String in _flat_kinds(node as GeometryInstance3D):
				var type := "%s:%s" % [_owner_name(node), flat]
				if not found.has(type):
					found[type] = {"node": node.get_path(), "count": 0}
				found[type]["count"] += 1
	return found


static func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out


static func _exempt(node: Node) -> bool:
	if node is GPUParticles3D or node is CPUParticles3D or _owner_name(node) in EXEMPT_OWNERS:
		return true
	var up: Node = node
	while up != null:
		if up.is_in_group(EXEMPT_GROUP) or up is Control:
			return true
		up = up.get_parent()
	return false


## The class name of the nearest ancestor (or the node itself) with a script.
static func _owner_name(node: Node) -> String:
	var up: Node = node
	while up != null:
		var script: Script = up.get_script()
		if script != null:
			var named := script.get_global_name()
			return str(named) if named != &"" else script.resource_path.get_file()
		up = up.get_parent()
	return "scene"


## What is flat about this node's surfaces: "std" (untextured standard material), "shader:<file>"
## (a shader with no texture and no surface_detail) or "none" (no material at all).
static func _flat_kinds(node: GeometryInstance3D) -> Array[String]:
	var out: Array[String] = []
	var mats: Array[Material] = []
	if node.material_override != null:
		mats.append(node.material_override)
	else:
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			mesh = (node as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			return out
		for i: int in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(i)
			if node is MeshInstance3D:
				m = (node as MeshInstance3D).get_active_material(i)
			mats.append(m)
	for m: Material in mats:
		var kind := _flat_kind(m)
		if kind != "" and not out.has(kind):
			out.append(kind)
	return out


static func _flat_kind(m: Material) -> String:
	if m == null:
		return "none"
	if m is StandardMaterial3D:
		var s := m as StandardMaterial3D
		if s.albedo_texture == null and s.detail_albedo == null:
			return "std"
		return ""
	if m is ShaderMaterial:
		var shader := (m as ShaderMaterial).shader
		if shader == null:
			return "shader:none"
		var code := _with_includes(shader.code)
		if code.contains(DETAIL_INCLUDE) or _samples_texture(code):
			return ""
		return "shader:" + shader.resource_path.get_file()
	return ""  # a procedural or other special material: not a flat colour block


## The shader's code with every file it includes (and theirs), so an include of the surface
## family counts.
static func _with_includes(code: String, depth: int = 0) -> String:
	if depth > 4:
		return code
	var out := code
	for line: String in code.split("\n"):
		var at := line.find("#include")
		if at >= 0 and not line.strip_edges().begins_with("//"):
			var path := line.substr(at + 8).strip_edges().trim_prefix('"').get_slice('"', 0)
			if FileAccess.file_exists(path):
				out += "\n" + _with_includes(FileAccess.get_file_as_string(path), depth + 1)
	return out


static func _samples_texture(code: String) -> bool:
	for call: String in ["texture(", "textureLod(", "texelFetch(", "textureGrad("]:
		if code.contains(call):
			return true
	return false


## A gone building's heap, a toppled tower's strip and a wall chunk, as a rampage leaves them, so
## the rubble field is scanned too.
static func _add_ruins(rampage: Rampage) -> void:
	var city: CityView = rampage._city
	var stream: BuildingStream = city.get("_stream")
	var view: BuildingView = stream.view.call(0)
	var voxels := view.voxels
	var yard: RuinYard = city.ruins()
	yard._attach(Ruin.build_plan(voxels, Seeds.make("ruin", 0)))
	yard._attach(Ruin.strip_plan(voxels, Vector3(0, 0, 0), Vector3(6, 0, 0), 3.0))
	yard._add(Ruin.chunk(voxels, Vector3(1, 1, 1), 5))


## Every landmark's view, built now, so the scan covers them wherever the kaiju starts (it rises
## from the bay, D-373, and the stream meshes the buildings nearest it first).
static func _add_landmarks(rampage: Rampage) -> void:
	var city: CityView = rampage._city
	var stream: BuildingStream = city.get("_stream")
	for n: int in rampage.sim.buildings.size():
		if rampage.sim.buildings[n].landmark != "":
			stream.view(n)


## Runs the real sim until the first train is on the viaduct (rail.first_s after the kaiju's rise
## from the river) and its cars are drawn, so the trains are in the scan (debt row 25: the cars
## rendered flat and a scan 30 frames in never saw one). True when RailView holds a train's cars.
static func _await_train(tree: SceneTree, rampage: Rampage) -> bool:
	var rail: Rail = rampage.sim.rail
	var rise := Num.f(Content.section("emerge")["max_seconds"])
	var ticks := ceili((rise + Num.f(rail.cfg["first_s"]) + 2.0) * Engine.physics_ticks_per_second)
	for i: int in ticks:
		if not rail.trains.is_empty():
			break
		await tree.physics_frame
	for i: int in 2:
		await tree.process_frame
	var view: RailView = rampage.get("_rail")
	if view == null:
		return false
	var cars: Dictionary = view.get("_cars")
	return not cars.is_empty()


## The check: build the real city, run it until a train runs, scan it, fail every flat type not
## on KNOWN_FLAT, and fail a KNOWN_FLAT entry that no longer exists (so the list shrinks as types
## are fixed).
static func run(tree: SceneTree, check_fn: Callable) -> void:
	Content.set_time("noon")
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var rampage := Rampage.new()
	rampage.setup(species, stats, CityGrowth.layout(Content.tuning(), 2, Seeds.make("city", 0)), 0)
	tree.root.add_child(rampage)
	await rampage.wait_loaded()
	for i: int in 30:
		await tree.process_frame
	check_fn.call(await _await_train(tree, rampage), "a train runs on the viaduct in the scan")
	_add_ruins(rampage)
	check_fn.call(
		rampage._city.ruins().get_child_count() >= 3,
		"the rubble field (heap, strip, chunk) is in the scan"
	)
	_add_landmarks(rampage)
	var found := scan(rampage)
	var fresh: Array[String] = []
	for type: String in found:
		if not KNOWN_FLAT.has(type):
			fresh.append("%s x%d (%s)" % [type, found[type]["count"], found[type]["node"]])
	check_fn.call(fresh.is_empty(), "no flat-colour surface in the city: %s" % [fresh])
	check_fn.call(
		KNOWN_FLAT.size() <= KNOWN_FLAT_MAX,
		"KNOWN_FLAT only shrinks: %d entries, cap %d" % [KNOWN_FLAT.size(), KNOWN_FLAT_MAX]
	)
	var gone: Array[String] = []
	for type: String in KNOWN_FLAT:
		if not found.has(type):
			gone.append(type)
	check_fn.call(gone.is_empty(), "KNOWN_FLAT lists only types still flat; remove: %s" % [gone])
	print("FLAT types found: %d" % found.size())
	for type: String in found:
		print("FLAT %s x%d %s" % [type, found[type]["count"], found[type]["node"]])
	await _death(tree, rampage, check_fn)
	rampage.queue_free()
	await tree.process_frame


## His death too (director 2026-10-27, "i dont like the pale blocks that come out of the
## explosion": the burst's stone debris and shards were plain untextured boxes): ends the run, plays
## the overload to the burst (DeathView, DeathOverload) and scans what is flying. Same rule: no
## flat type that is not on KNOWN_FLAT.
static func _death(tree: SceneTree, rampage: Rampage, check_fn: Callable) -> void:
	rampage.sim.end("ended")
	var view: DeathView = rampage.find_child("DeathView", false, false)
	for i: int in DEATH_FRAMES:
		if view.burst:
			break
		await tree.physics_frame
	check_fn.call(view.burst, "his death reaches the burst (debris and shards are in the scan)")
	var found := scan(view)  # what his death adds: the stone debris and the shards
	var fresh: Array[String] = []
	for type: String in found:
		if not KNOWN_FLAT.has(type):
			fresh.append("%s x%d (%s)" % [type, found[type]["count"], found[type]["node"]])
	var pieces := _walk(view).filter(func(n: Node) -> bool: return n is GeometryInstance3D)
	check_fn.call(
		pieces.size() >= 2, "the debris and the shards are in the scan: %d" % pieces.size()
	)
	check_fn.call(fresh.is_empty(), "no flat-colour surface in his death: %s" % [fresh])
	ChunkCheck.check_view(view, check_fn)  # D-323: jagged chunks of many sizes, never a box
	for type: String in found:
		print("FLAT death %s x%d %s" % [type, found[type]["count"], found[type]["node"]])
