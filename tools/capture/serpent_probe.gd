extends SceneTree
## The serpent clip's route without the city or a window (tools/capture/capture_serpent.gd's stick
## script, pre-roll included): the drawn body's joints, heights and widths and the sim's centreline
## every `--every` frames, written as JSON for the screen-term read checks (straight runs through
## the turns, the S's swing about the centreline, tube self-intersections in the coil).
##   godot --headless --path . --script tools/capture/serpent_probe.gd -- --out=<file.json>

const Kit := preload("res://tools/capture/capture_kit.gd")
const Capture := preload("res://tools/capture/capture_serpent.gd")
const DT := 1.0 / 60.0

var _args := Kit.args(
	{"seconds": 9.4, "every": 6, "out": "user://serpent_probe.json", "route": "clip"}
)


## The stick: the clip's, or (--route=stop) the suite's stop mid-turn (pre-rolled north, east
## asked for 40 frames, then let go).
func _stick(t: float) -> Vector2:
	if str(_args["route"]) == "stop":
		return Vector2(1, 0) if t < 40.0 * DT else Vector2.ZERO
	return Capture.stick_at(t)


func _initialize() -> void:
	var cfg := Content.section("serpent")
	var steps := int(Capture.PREROLL_S / DT)
	var way := Vector2(1, 0)
	var start := Vector2.ZERO
	if str(_args["route"]) == "stop":
		way = Vector2(0, -1)
	else:
		var trial := SerpentBody.new(cfg, Vector2.ZERO, way)
		for _i: int in steps:
			trial.step(DT, way)
		start = Capture.START - Vector2(trial.pos.x, 0.0)
	var body := SerpentBody.new(cfg, start, way)
	var drawn := SerpentStandIn.new(cfg)
	for _i: int in steps:
		body.step(DT, way)
		drawn.update(body, DT)
	var frames: Array = []
	var every := Num.i(_args["every"])
	for f: int in int(Num.f(_args["seconds"]) / DT) + 1:
		if f % every == 0:
			frames.append(_frame(f * DT, body, drawn))
		body.step(DT, _stick(f * DT))
		drawn.update(body, DT)
	var file := FileAccess.open(str(_args["out"]), FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": frames}))
	file.close()
	print("serpent probe: %d frames to %s" % [frames.size(), _args["out"]])
	drawn.free()
	quit()


func _frame(t: float, body: SerpentBody, drawn: SerpentStandIn) -> Dictionary:
	var seg := body.length() / Num.i(body.cfg["segments"])
	var joints: Array = []
	var lifts: Array = []
	var widths: Array = []
	var heights: Array = []
	for j: int in drawn.joints.size():
		joints.append([drawn.joints[j].x, drawn.joints[j].y])
		lifts.append(drawn.lifts[j])
		widths.append(drawn.width_at(j * seg))
		heights.append(drawn.height_at(j * seg))
	var centre: Array = []
	for k: int in int(body.length() * 1.2):
		var c := body.centre_at(k)
		centre.append([c.x, c.y])
	return {
		"t": t,
		"speed": body.speed,
		"spin": body.spin,
		"joints": joints,
		"lifts": lifts,
		"widths": widths,
		"heights": heights,
		"centre": centre,
		"drawn_head": [drawn._weave.drawn.head.x, drawn._weave.drawn.head.y],
		"sigma_lag": body.trail.head_s - drawn._weave._sigma,
		"off": drawn._weave._off,
		"ramp": drawn._weave._ramp,
	}
