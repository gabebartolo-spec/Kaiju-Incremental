class_name ArenaEdge
extends MultiMeshInstance3D
## Where the kaiju's walk ends (director 2026-10-20: "the edge of the play area needs to be
## indicated somehow (not too loud) so players dont continuously try to destroy indestructible
## buildings"): a row of small orange bollards on the pavement just past the arena's edge
## (sim.arena_half + "out"), the city cordoning off the kaiju; none over the river's water, on a
## street that crosses the edge (no car drives through one) or in a street tree's trunk. A
## painted line read as a lane marking (lead check, dusk/night captures). Cosmetic; tuning
## "arena_edge".

## How far either side of the bollard line a street, tree or water counts (m): only these
## are tested per bollard, so a stage-4 arena stays cheap (critic on #114).
const BAND := 4.0

## Each bollard's footprint centre on the ground (tests read these: headless MultiMesh
## transforms read back empty).
var posts: Array[Vector3] = []


## trees: the street trees' trunk spots (ArenaEdge.trees_of(decor)).
func _init(sim: RampageSim, trees: Array[Vector2] = []) -> void:
	var cfg: Dictionary = Content.tuning()["arena_edge"]
	posts = spots(sim, trees)
	var size: Array = cfg["size"]
	var box := Vector3(Num.f(size[0]), Num.f(size[1]), Num.f(size[0]))
	var mesh := BoxMesh.new()
	mesh.size = box
	var mat := StandardMaterial3D.new()
	var color := Color(str(cfg["color"]))
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = Num.f(cfg["glow"])  # still reads at night, never shines
	mat.roughness = 0.8
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = posts.size()
	for n: int in posts.size():
		mm.set_instance_transform(
			n, Transform3D(Basis.IDENTITY, posts[n] + Vector3(0, box.y * 0.5, 0))
		)
	multimesh = mm
	name = "ArenaEdge"


## Where the bollards stand: every "spacing" m round the square at arena_half + "out", minus
## any over the water, on a street or within "tree_clear" of a trunk. Pure.
static func spots(sim: RampageSim, trees: Array[Vector2]) -> Array[Vector3]:
	var cfg: Dictionary = Content.tuning()["arena_edge"]
	var half := sim.arena_half + Num.f(cfg["out"])
	var step := Num.f(cfg["spacing"])
	var clear := Num.f(cfg["tree_clear"])
	var plan := CityGen.map(sim.city)
	var water := CityRiver.channels(plan, sim.city)
	var roads := _roads(plan, sim.city, half)
	var near := trees.filter(func(tr: Vector2) -> bool: return absf(_ring(tr) - half) < BAND)
	var out: Array[Vector3] = []
	for side: int in 4:
		var along := Vector3.RIGHT if side % 2 == 0 else Vector3.BACK
		var sign := 1.0 if side < 2 else -1.0
		var edge := Vector3(0, 0, half * sign) if side % 2 == 0 else Vector3(half * sign, 0, 0)
		var t := -half
		while t <= half:
			var at := edge + along * t
			t += step
			var ground := Vector2(at.x, at.z)
			if water.any(func(r: Rect2) -> bool: return r.has_point(ground)):
				continue
			if on_road(ground, roads):
				continue
			if near.any(func(tr: Vector2) -> bool: return tr.distance_to(ground) < clear):
				continue
			out.append(at)
	return out


## The street trees' trunk spots CityDecor planted (none without decor).
static func trees_of(decor: CityDecor) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if decor != null:
		for spots_in: Array in decor._tree_cells.values():
			for spot: Vector2 in spots_in:
				out.append(spot)
	return out


## The streets near the bollard line as [from, to, half width + a little] (alleys too: a
## bollard never blocks one).
static func _roads(plan: Dictionary, city: Dictionary, half: float) -> Array:
	var nodes: Array = plan["nodes"]
	var outer := Rect2(-half - BAND, -half - BAND, (half + BAND) * 2.0, (half + BAND) * 2.0)
	var inner := outer.grow(-BAND * 2.0)
	var out := []
	for street: Dictionary in plan["streets"]:
		var from: Vector2 = nodes[Num.i(street["from"])]
		var to: Vector2 = nodes[Num.i(street["to"])]
		var box := Rect2(from, Vector2.ZERO).expand(to).grow(0.5)
		if outer.intersects(box) and not inner.encloses(box):
			out.append([from, to, CityGen.width_of(str(street["kind"]), city) * 0.5 + 0.4])
	return out


static func on_road(p: Vector2, roads: Array) -> bool:
	for road: Array in roads:
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < Num.f(road[2]):
			return true
	return false


static func _ring(p: Vector2) -> float:
	return maxf(absf(p.x), absf(p.y))
