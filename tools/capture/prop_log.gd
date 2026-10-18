extends RefCounted
## Per-prop trample log for capture_green --log-props (the motion critic's third round on #55
## asked for evidence per tree, not another clip): for every decor prop in an area, the movie
## frame its base first lies under the kaiju's body box, the frame it went down, the closest
## the box came to it, and where it stood on screen (1280x720) when the box first reached it.

var _rows := {}  # prop group index -> its row
var _start := 0
var _scale := 1.0  # screen pixels of the log per viewport pixel


func _init(decor: CityDecor, area: Rect2, viewport_height: float) -> void:
	_start = Engine.get_process_frames()
	_scale = 720.0 / viewport_height
	var groups: Array[Dictionary] = decor._props._groups
	for i: int in groups.size():
		var at: Vector3 = groups[i]["at"]
		if area.has_point(Vector2(at.x, at.z)):
			_rows[i] = {
				"at": at,
				"tree": groups[i].get("fells", false),
				"inside": -1,
				"down": -1,
				"near": INF,
				"screen": Vector2(-1, -1),
			}


## One sample: call every physics frame of the walk.
func sample(decor: CityDecor, camera: Camera3D) -> void:
	var kaiju := decor._kaiju
	if kaiju == null:
		return
	var frame := Engine.get_process_frames() - _start
	var body := kaiju.global_transform
	var into := body.affine_inverse()
	var size := body.basis.get_scale().x
	var foot: Rect2 = decor._foot
	var groups: Array[Dictionary] = decor._props._groups
	for i: int in _rows:
		var row: Dictionary = _rows[i]
		var at: Vector3 = row["at"]
		var local := into * Vector3(at.x, body.origin.y, at.z)
		var p := Vector2(local.x, local.z)
		var off := p.clamp(foot.position, foot.end).distance_to(p) * size
		row["near"] = minf(Num.f(row["near"]), off)
		if off == 0.0 and Num.i(row["inside"]) < 0:
			row["inside"] = frame
			row["screen"] = camera.unproject_position(at) * _scale
		if groups[i].get("crushed", false) and Num.i(row["down"]) < 0:
			row["down"] = frame


## The table, the props the box reached first; then the ones it came within 1 m of.
func report() -> String:
	var lines: Array[String] = ["prop  kind   x      z      inside  down   near_m  screen720"]
	var keys: Array = _rows.keys()
	keys.sort_custom(
		func(a: int, b: int) -> bool: return Num.f(_rows[a]["near"]) < Num.f(_rows[b]["near"])
	)
	for i: int in keys:
		var row: Dictionary = _rows[i]
		if Num.f(row["near"]) > 1.0 and Num.i(row["down"]) < 0:
			continue
		var at: Vector3 = row["at"]
		var screen: Vector2 = row["screen"]
		lines.append(
			(
				"%-5d %-6s %-6.1f %-6.1f %-7d %-6d %-7.2f (%d,%d)"
				% [
					i,
					"tree" if row["tree"] else "other",
					at.x,
					at.z,
					row["inside"],
					row["down"],
					row["near"],
					roundi(screen.x),
					roundi(screen.y)
				]
			)
		)
	return "\n".join(lines)
