extends RefCounted
## What bench_frames.gd and ablate.gd share (Phase 0 render baseline, docs/research/2026-10-26-render-baseline.md):
## the seeded adult-city run (stage, time, weather, preset) with a recorded route replayed on it,
## the route's tally of what it did, and percentiles. Tools only; no game code.

const Kit := preload("res://tools/capture/capture_kit.gd")

## What the user args set, for both tools (Kit.args takes each default's type).
const DEFAULTS := {
	"stage": 3,
	"time": "night",
	"weather": "clear",
	"graphics": "medium",
	"route": "replay",
	"route-file": "",
	"vsync": false,
	"set": "",
	"tune": "",
}

var rampage: Rampage
var city: CityView
var route: Array = []
var steps := 0
## The route's tally, read off the sim as it plays (a route must show these, plan section 2).
var tally := {"stomps": 0, "swipes": 0, "breaths": 0, "beams": 0, "falls": 0}
var _breath_ready := 0.0
var _ult_ready := 0.0


## Percentile `p` (0..1) of a sorted array (nearest rank).
static func pct(sorted: Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return Num.f(sorted[clampi(ceili(p * sorted.size()) - 1, 0, sorted.size() - 1)])


static func over(values: Array, limit: float) -> int:
	var n := 0
	for v: Variant in values:
		if Num.f(v) > limit:
			n += 1
	return n


## Builds the run: preset, time, weather, city, rampage, waits for the stream, lets the kaiju rise
## and arms the replay. Returns false (with the reason printed) when it cannot.
func start(tree: SceneTree, a: Dictionary) -> bool:
	# A bench on a stale native DLL measures the slow GDScript fallback: log what is loaded.
	var dll := ProjectSettings.globalize_path("res://native/bin")
	for f: String in DirAccess.get_files_at("res://native/bin"):
		if f.ends_with(".dll"):
			var when := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time("res://native/bin/" + f))
			print("BENCH native %s/%s modified %s" % [dll, f, when])
	var settle := ClassDB.class_exists("KaijuSettle")
	print("BENCH ClassDB KaijuSettle=%s" % settle)
	if not settle and not OS.has_environment("BENCH_ALLOW_STALE_DLL"):
		printerr("BENCH native DLL lacks KaijuSettle: refusing to measure (BENCH_ALLOW_STALE_DLL=1 overrides)")
		return false
	PlayerSettings.graphics = str(a["graphics"])
	for pair: String in str(a["tune"]).split(",", false):
		var tv := pair.split("=")  # section.key=value
		var path := tv[0].split(".")
		Content.section(path[0])[path[1]] = float(tv[1])
	var stage := Num.i(a["stage"])
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[stage - 1], "reptilian")
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	rampage = Rampage.new()
	rampage.setup(Content.species_def("reptilian"), stats, layout, 0)
	Content.set_time(str(a["time"]))
	Content.set_weather(str(a["weather"]))
	var look := Content.look()
	for pair: String in str(a["set"]).split(",", false):
		var kv := pair.split("=")
		look[kv[0]] = float(kv[1]) if kv[1].is_valid_float() else kv[1]
	tree.root.add_child(rampage)
	rampage.set_physics_process(false)
	city = rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await tree.process_frame
	for _i: int in 10:
		await tree.process_frame
	rampage.set_physics_process(true)
	for child: Node in rampage.get_children():  # the aim wedge is a play aid, not the picture
		if child is BreathAim:
			child.set_physics_process(false)
			child.set_process(false)
			(child as BreathAim).visible = false
	if str(a["route"]) == "replay":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(a["route-file"])))
		if not parsed is Array:
			printerr("BENCH no route at %s" % a["route-file"])
			return false
		route = parsed
	rampage.scripted = _scripted
	while rampage.sim.emerge.active:
		await tree.physics_frame
	return true


## Replays the recorded input of this step (capture_one_look.gd's format: move x, y, signature,
## held, ultimate), then tallies what the sim did.
func _scripted(sim: RampageSim) -> Dictionary:
	if sim.emerge.active:
		return {}
	_tally(sim)
	var at: Array = route[mini(steps, route.size() - 1)]
	steps += 1
	return {
		"move": Vector2(Num.f(at[0]), Num.f(at[1])),
		"signature": Num.f(at[2]) > 0.5,
		"held": Num.f(at[3]) > 0.5,
		"ultimate": Num.f(at[4]) > 0.5,
	}


func _tally(sim: RampageSim) -> void:
	tally["stomps"] = rampage.stomp_ring_at.size()
	tally["falls"] = sim.next_fall_id
	if sim.powers != null and sim.powers.swipe != null:
		tally["swipes"] = sim.powers.swipe.swipes
	if sim.ability_ready_in > _breath_ready + 0.5:
		tally["breaths"] += 1
	_breath_ready = sim.ability_ready_in
	if sim.ultimate_ready_in > _ult_ready + 0.5:
		tally["beams"] += 1
	_ult_ready = sim.ultimate_ready_in


## Every node of `type` under the root, found by class name.
static func nodes_of(tree: SceneTree, type: String) -> Array[Node]:
	return tree.root.find_children("*", type, true, false)
