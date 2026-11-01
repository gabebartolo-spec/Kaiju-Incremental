extends RefCounted
## The UI suite's title-beach checks (tests/run_ui_tests.gd; director 2026-11-02, "meant to be a
## beach"): the bottom of the title picture is the play area's sand sloping into the bay, its
## waterline wandering along the shore (tuning title shore "beach_wander"), not a straight quay
## edge, and the bay laps up it with the game's own lap (tuning water lap). The same waterline
## check on a beach with no wander (the old straight edge) fails, so it can fail.

const COAST_Z := -145.0
const SHORE_Z := -335.0
## The least spread (m, along z) of the waterline over the shore, for it to read as a beach.
const WANDER_MIN := 4.0

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	var cfg: Dictionary = Content.section("title")["shore"]
	var straight := cfg.duplicate()
	straight["beach_wander"] = 0.0
	var flat := _waterline_spread(_shore(straight))
	check.call(flat < WANDER_MIN, "a beach with no wander has a straight waterline (%.1f m)" % flat)
	var shore := _shore(cfg)
	var spread := _waterline_spread(shore)
	check.call(
		spread >= WANDER_MIN,
		(
			"the title beach's waterline wanders along the shore (%.1f m >= %.1f)"
			% [spread, WANDER_MIN]
		)
	)
	var lap: Dictionary = Content.section("water")["lap"]
	var water: Node3D = shore._tide[0]
	var rest := water.position.y
	shore._process(Num.f(lap["period"]) / 4.0)  # the lap's crest
	check.call(
		is_equal_approx(water.position.y - rest, Num.f(lap["height"])),
		"the bay laps up the title beach (%.2f m at the crest)" % (water.position.y - rest)
	)
	for node: Node in t.root.get_children():
		if node is TitleShore:
			node.free()


## A title shore on `cfg`, built and still (its lap is stepped by hand, no clock).
func _shore(cfg: Dictionary) -> TitleShore:
	var title := Content.section("title")
	var variant: Dictionary = title["variants"][str(title["variant"])]
	var shore := TitleShore.new(
		cfg,
		{
			"shore_z": SHORE_Z,
			"coast_z": COAST_Z,
			"cam": Vector3.ZERO,
			"fires": PackedFloat32Array([0.0]),
			"ripple": title["ripple"],
			"water": variant["water"]
		}
	)
	shore.process_mode = Node.PROCESS_MODE_DISABLED
	t.root.add_child(shore)
	return shore


## How far the sand's waterline (where it dips under the bay's rest level) runs in and out along
## the shore (m): its farthest z less its nearest.
func _waterline_spread(shore: TitleShore) -> float:
	var sand: MeshInstance3D = null
	for node: Node in shore.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).material_override != null:
			sand = node
	var verts: PackedVector3Array = sand.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var columns: Dictionary[float, Array] = {}  # x: the column's points, any order
	for v: Vector3 in verts:
		if not columns.has(v.x):
			columns[v.x] = []
		columns[v.x].append(v)
	var lo := INF
	var hi := -INF
	for points: Array in columns.values():
		points.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.z > q.z)  # near first
		for k: int in points.size() - 1:
			var a: Vector3 = points[k]
			var b: Vector3 = points[k + 1]
			if a.y >= TitleShore.WATER_Y and b.y < TitleShore.WATER_Y:
				var z := lerpf(a.z, b.z, inverse_lerp(a.y, b.y, TitleShore.WATER_Y))
				lo = minf(lo, z)
				hi = maxf(hi, z)
				break
	return hi - lo
