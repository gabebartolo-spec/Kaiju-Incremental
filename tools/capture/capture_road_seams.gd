extends SceneTree
## Roads suite R6, the look half (director 2026-10-26: "some weird spots where two roads met, like
## a seam between them rather than a seamless join"): the city's ground (CityGround, as the game
## draws it, road paint hidden) rendered straight down over every junction in view
## (tools/capture/road_joins.gd), and at each join the mean luminance of a strip either side of
## the join line compared. The same step measured between neighbouring strips further along the
## same road is the road's own texture; a join may step no more than LIMIT.
## LIMIT (luma 0..1; 8-bit: 9 levels): a plain road's own neighbour-strip steps (seeds 7301,
## 1234, 98765, stages 1-3, 64k pairs) are 0.016 at the 99th percentile; a join may step a little
## over twice that. On the merge of #208 (before RoadJunctions) 5% of the 9,788 joins stepped
## more than 0.035 (p99 0.045, max 0.083: a kerb gutter band across a road's mouth, the seam the
## director saw); with junction boxes the joins match the road's own texture (p99 0.017, max 0.031).
## Needs a renderer: the off-screen no_focus override.cfg on this PC, or CI (xvfb).
##   godot --path . --resolution 768x768 --script tools/capture/capture_road_seams.gd --
##     --seeds=7301,1234 --stages=1,2,3 --out=<dir> (a failing junction's shot is saved there)
## Exit code 1 when any join steps past LIMIT.

const Kit := preload("res://tools/capture/capture_kit.gd")
const Joins := preload("res://tools/capture/road_joins.gd")
const LIMIT := 0.035
const STRIP := 0.5  # a strip's depth either side of a join line (m)
const STEP := 0.05  # sample spacing in a strip (m)
const REF_REACH := 8.0  # the road's own steps: this far along an arm, half its length at most
const VIEW := 24.0  # the top-down shot's width (m)
const BANK := 1.5  # a join this near the river is left out (quays, parapets in its strips) (m)
const HIGH := 30.0  # the camera's height (m), inside the ground detail's near fade

var _cam: Camera3D
var _refs: Array[float] = []
var _steps: Array[float] = []
var _by_what := {}  # join kind -> Array[float] of its steps
var _worst: Array[Dictionary] = []
var _joins := 0
var _limit := LIMIT


func _initialize() -> void:
	if not Kit.window_ok():
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var a := Kit.args(
		{"seeds": "7301,1234,98765", "stages": "1,2,3", "out": "user://road_seams", "limit": LIMIT}
	)
	_limit = Num.f(a["limit"])
	DirAccess.make_dir_recursive_absolute(str(a["out"]))
	root.size = Vector2i(768, 768)
	_light()
	for tier: String in str(a["stages"]).split(","):
		for map_seed: String in str(a["seeds"]).split(","):
			await _city(int(tier), int(map_seed), str(a["out"]))
	print("R6 luma: %d joins, %d past %.3f" % [_joins, _worst.size(), _limit])
	print("  join steps: %s" % _quantiles(_steps))
	for what: String in _by_what:
		var raw: Array = _by_what[what]
		var list: Array[float] = []
		list.assign(raw)
		print("    %s: %s" % [what, _quantiles(list)])
	print("  the road's own steps: %s" % _quantiles(_refs))
	quit(1 if _worst else 0)


## "p50 x p90 x p95 x p99 x max x" of values.
static func _quantiles(values: Array[float]) -> String:
	if values.is_empty():
		return "none"
	values.sort()
	var out := ""
	for q: float in [0.5, 0.9, 0.95, 0.99]:
		out += "p%d %.3f " % [roundi(q * 100.0), values[int(q * (values.size() - 1))]]
	return out + "max %.3f (n %d)" % [values[-1], values.size()]


func _light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70.0, 30.0, 0.0)
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = VIEW
	_cam.near = 1.0
	_cam.far = HIGH * 2.0
	root.add_child(_cam)
	_cam.make_current()


func _city(tier: int, map_seed: int, out: String) -> void:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city: Dictionary = base["city"]
	city["map_seed"] = map_seed
	var cfg: Dictionary = CityGrowth.tuning_for(base, tier)["city"]
	var ground := CityGround.new(cfg)
	root.add_child(ground)
	_hide_paint(ground)
	var joins := Joins.new(ground.plan, cfg)
	var reach := CityBand.extent(cfg)
	var water := CityRiver.channels(ground.plan, cfg)
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var by_node := {}
	for join: Dictionary in joins.joins:
		var at: Vector2 = nodes[Num.i(join["node"])]
		if maxf(absf(at.x), absf(at.y)) > reach or at.y < ground.coast:
			continue
		if _wet(join, water) or Num.f(join["free"]) < STRIP:
			continue  # over the river, or the arm ends in the next junction within a strip
		if not by_node.has(join["node"]):
			by_node[join["node"]] = []
		var list: Array = by_node[join["node"]]
		list.append(join)
	for n: int in by_node:
		var c: Vector2 = nodes[n]
		_cam.look_at_from_position(Vector3(c.x, HIGH, c.y), Vector3(c.x, 0.0, c.y), Vector3.FORWARD)
		await Kit.frames(self, 3)
		var shot := root.get_texture().get_image()
		var bad := false
		for join: Dictionary in by_node[n]:
			bad = _measure(shot, join, "stage %d seed %d" % [tier, map_seed]) or bad
		if bad:
			shot.save_png(
				out.path_join("seam_s%d_%d_%d_%d.png" % [tier, map_seed, roundi(c.x), roundi(c.y)])
			)
	ground.free()


## True when the join's strips or its reference strips come within BANK of a river channel.
func _wet(join: Dictionary, water: Array[Rect2]) -> bool:
	var p: Vector2 = join["p"]
	var along: Vector2 = join["along"]
	var e: Vector2 = join["e"]
	var normal: Vector2 = join["n"]
	var lean := 1.0 / along.dot(normal)
	var half := Num.f(join["half"])
	for w: Rect2 in water:
		var bank := w.grow(BANK)
		for d: float in [-STRIP, REF_REACH]:
			for s: float in [-half, 0.0, half]:
				if bank.has_point(p + along * (d * lean) + e * s):
					return true
	return false


func _hide_paint(ground: CityGround) -> void:
	for child: Node in ground.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null:
			continue
		var mat := mmi.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		var force: Variant = mat.get_shader_parameter("force_kind") if mat else null
		if force != null and Num.f(force) >= 0.0:
			mmi.visible = false


## Measures one join in shot; true when it steps past the limit (LIMIT; --limit=) (printed).
func _measure(shot: Image, join: Dictionary, label: String) -> bool:
	_joins += 1
	var step := absf(_strip(shot, join, -STRIP, 0.0) - _strip(shot, join, 0.0, STRIP))
	_steps.append(step)
	var what := str(join["what"])
	if not _by_what.has(what):
		_by_what[what] = []
	var list: Array = _by_what[what]
	list.append(step)
	var free := Num.f(join["free"])
	var d := STRIP * 2.0
	while d + STRIP * 2.0 <= minf(free * 0.5, REF_REACH):
		_refs.append(
			absf(_strip(shot, join, d, d + STRIP) - _strip(shot, join, d + STRIP, d + STRIP * 2.0))
		)
		d += STRIP
	if step <= _limit:
		return false
	var p: Vector2 = join["p"]
	_worst.append(join)
	print("R6 seam: luma step %.3f at (%.1f, %.1f), %s, %s" % [step, p.x, p.y, join["what"], label])
	return true


## Mean luminance of the strip from d0 to d1 (m) out along the join's normal, the whole sampled
## length of its line, moved along the arm so it stays on the arm's carriageway.
func _strip(shot: Image, join: Dictionary, d0: float, d1: float) -> float:
	var p: Vector2 = join["p"]
	var e: Vector2 = join["e"]
	var along: Vector2 = join["along"]
	var normal: Vector2 = join["n"]
	var lean := 1.0 / along.dot(normal)
	var half := Num.f(join["half"])
	var size := Vector2(shot.get_size())
	var sum := 0.0
	var count := 0
	var d := d0 + STEP * 0.5
	while d < d1:
		var s := -half
		while s <= half:
			var w := p + along * (d * lean) + e * s
			var px := Vector2i(Kit.image_point(self, _cam, Vector3(w.x, 0.0, w.y), size))
			if Rect2i(Vector2i.ZERO, shot.get_size()).has_point(px):
				sum += shot.get_pixelv(px).get_luminance()
				count += 1
			s += STEP
		d += STEP
	return sum / maxf(count, 1.0)
