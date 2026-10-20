class_name ArenaEdge
extends MultiMeshInstance3D
## Where the kaiju's walk ends (director 2026-10-20: "the edge of the play area needs to be
## indicated somehow (not too loud) so players dont continuously try to destroy indestructible
## buildings"): a row of small orange bollards on the pavement just past the arena's edge
## (sim.arena_half + "out"), the city cordoning off the kaiju; none over the river's water or on a
## street that crosses the edge, so no car drives through one. A painted line read as a lane
## marking (lead check, dusk/night captures). Cosmetic; tuning "arena_edge".

## Each bollard's footprint centre on the ground (tests read these: headless MultiMesh
## transforms read back empty).
var posts: Array[Vector3] = []


## trees: the street trees' trunk spots (CityDecor); a bollard never stands in one.
func _init(sim: RampageSim, trees: Array[Vector2] = []) -> void:
	var cfg: Dictionary = Content.tuning()["arena_edge"]
	var half := sim.arena_half + Num.f(cfg["out"])
	var step := Num.f(cfg["spacing"])
	var clear := Num.f(cfg["tree_clear"])
	var size: Array = cfg["size"]
	var box := Vector3(Num.f(size[0]), Num.f(size[1]), Num.f(size[0]))
	var plan := CityGen.map(sim.city)
	var water := CityRiver.channels(plan, sim.city)
	var roads := _roads(plan, sim.city)
	for side: int in 4:
		var along := Vector3.RIGHT if side % 2 == 0 else Vector3.BACK
		var sign := 1.0 if side < 2 else -1.0
		var out := Vector3(0, 0, half * sign) if side % 2 == 0 else Vector3(half * sign, 0, 0)
		var t := -half
		while t <= half:
			var at := out + along * t
			t += step
			var ground := Vector2(at.x, at.z)
			if (
				water.any(func(r: Rect2) -> bool: return r.has_point(ground))
				or _on_road(ground, roads)
			):
				continue
			if trees.any(func(tr: Vector2) -> bool: return tr.distance_to(ground) < clear):
				continue
			posts.append(at)
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


## Every street as [from, to, half width + a little] (alleys too: a bollard never blocks one).
static func _roads(plan: Dictionary, city: Dictionary) -> Array:
	var nodes: Array = plan["nodes"]
	var out := []
	for street: Dictionary in plan["streets"]:
		var from: Vector2 = nodes[Num.i(street["from"])]
		var to: Vector2 = nodes[Num.i(street["to"])]
		out.append([from, to, CityGen.width_of(str(street["kind"]), city) * 0.5 + 0.4])
	return out


static func _on_road(p: Vector2, roads: Array) -> bool:
	for road: Array in roads:
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < Num.f(road[2]):
			return true
	return false
