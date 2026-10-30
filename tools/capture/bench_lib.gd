extends RefCounted
## What bench_frames.gd and ablate.gd share (Phase 0 render baseline,
## docs/research/2026-10-26-render-baseline.md):
## the seeded adult-city run (stage, time, weather, preset) with a recorded route replayed on it,
## the route's tally of what it did, and percentiles. Tools only; no game code.

const Kit := preload("res://tools/capture/capture_kit.gd")
## The bulldozer re-picks its building this often (steps), and a building's standing chunks count
## half at this distance (units): big blocks near the path win over the nearest shed.
const BULLDOZE_REPICK := 30
const BULLDOZE_FALLOFF := 25.0
## The bulldozer's camera swings this far each side of its rest (degrees) over this many steps, so
## the stream keeps loading new views as a player panning would.
const BULLDOZE_SWING_DEG := 40.0
const BULLDOZE_SWING_STEPS := 600

## What the user args set, for both tools (Kit.args takes each default's type).
const DEFAULTS := {
	"stage": 3,
	"time": "night",
	"weather": "clear",
	"graphics": "medium",
	"route": "replay",  # or "bulldozer": no file, the kaiju ploughs the biggest blocks (_bulldoze)
	"route-file": "",
	"vsync": false,
	"set": "",
	"tune": "",
	"levels": "",  # extra upgrade levels, "r_beam=1,r_shear=1": the body the route runs with
	"beam-at": 0,  # >0: the ultimate fires on this route step only (the beam scenario), not every time
	"res": "3840x2160",  # the window and viewport size measured (1920x1080 for the 1080p bar, D-339)
}

var rampage: Rampage
var city: CityView
var route: Array = []
var steps := 0
## The route's tally, read off the sim as it plays (a route must show these, plan section 2).
var tally := {"stomps": 0, "swipes": 0, "breaths": 0, "beams": 0, "falls": 0}
var _beam_at := 0
var _breath_ready := 0.0
var _ult_ready := 0.0  # the beam seconds left on the last step
var _bulldozer := false
var _target := -1  # the building the bulldozer heads for (index into sim.buildings)
var _camera_rest := Vector3.ZERO  # the game's camera offset, swung around it by the bulldozer


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
			var when := Time.get_datetime_string_from_unix_time(
				FileAccess.get_modified_time("res://native/bin/" + f)
			)
			print("BENCH native %s/%s modified %s" % [dll, f, when])
	var settle := ClassDB.class_exists("KaijuSettle")
	print("BENCH ClassDB KaijuSettle=%s" % settle)
	if not settle and not OS.has_environment("BENCH_ALLOW_STALE_DLL"):
		printerr(
			"BENCH native DLL lacks KaijuSettle: refusing to measure (BENCH_ALLOW_STALE_DLL=1 overrides)"
		)
		return false
	PlayerSettings.graphics = str(a["graphics"])
	if DisplayServer.get_name() != "headless":  # a bordered window is clamped under the taskbar
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		var wh := str(a["res"]).split("x")
		var res := Vector2i(int(wh[0]), int(wh[1]))
		DisplayServer.window_set_size(res)
		DisplayServer.window_set_position(Vector2i(0, 0))  # on screen: the director watches the runs
		await tree.process_frame
		await tree.process_frame
		print(
			(
				"BENCH window rect %s viewport %s"
				% [
					Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()),
					tree.root.size
				]
			)
		)
		if tree.root.size != res:
			printerr("BENCH viewport is not %s: refusing to measure" % a["res"])
			return false
	for pair: String in str(a["tune"]).split(",", false):
		var tv := pair.split("=")  # section.key[.key...]=value (a number, or text)
		var path := tv[0].split(".")
		var table: Dictionary = Content.section(path[0])
		for k: int in range(1, path.size() - 1):
			table = table[path[k]]
		table[path[path.size() - 1]] = float(tv[1]) if tv[1].is_valid_float() else tv[1]
	var stage := Num.i(a["stage"])
	var owned: Dictionary = Kit.STAGE_LEVELS[stage - 1].duplicate()
	for pair: String in str(a["levels"]).split(",", false):
		var lv := pair.split("=")
		owned[lv[0]] = int(lv[1])
	var stats := Kit.stats("reptilian", owned, "reptilian")
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
	_bulldozer = str(a["route"]) == "bulldozer"
	if str(a["route"]) == "replay":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(a["route-file"])))
		if not parsed is Array:
			printerr("BENCH no route at %s" % a["route-file"])
			return false
		route = parsed
	_beam_at = Num.i(a["beam-at"])
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
	if _bulldozer:
		return _bulldoze(sim)
	var at: Array = route[mini(steps, route.size() - 1)]
	var ultimate := Num.f(at[4]) > 0.5
	if _beam_at > 0:
		ultimate = steps == _beam_at  # one press on a fixed tick, through the real input path
	steps += 1
	return {
		"move": Vector2(Num.f(at[0]), Num.f(at[1])),
		"signature": Num.f(at[2]) > 0.5,
		"held": Num.f(at[3]) > 0.5,
		"ultimate": ultimate,
	}


## A destruction-heavy route read live off the sim (deterministic, so every run is the same): walk
## at the building with the most standing chunks near the path, every power the moment it is ready,
## the glide on autoplay's cycle, the ultimate held (owned with --levels=r_beam=1).
func _bulldoze(sim: RampageSim) -> Dictionary:
	var lost := _target < 0 or sim.buildings[_target].frame.alive_count == 0
	if lost or steps % BULLDOZE_REPICK == 0:
		_target = _biggest_near(sim)
	steps += 1
	if _camera_rest == Vector3.ZERO:
		_camera_rest = rampage.camera_rest
	var swing := sin(TAU * steps / float(BULLDOZE_SWING_STEPS)) * deg_to_rad(BULLDOZE_SWING_DEG)
	rampage.camera_rest = _camera_rest.rotated(Vector3.UP, swing)
	var move := Vector2.ZERO
	if _target >= 0:
		var b: RampageSim.Building = sim.buildings[_target]
		var to := Vector2(b.x, b.z) - sim.kaiju_pos
		if to.length() >= sim.stomp_radius() * 0.5:
			move = to.normalized()
	return {
		"move": move,
		"signature": sim.ability_ready_in <= 0.0,
		"held": steps % RunInput.AUTOPLAY_GLIDE_CYCLE < RunInput.AUTOPLAY_GLIDE_HELD,
		"ultimate": true,
	}


func _biggest_near(sim: RampageSim) -> int:
	var best := -1
	var best_score := 0.0
	for i: int in sim.buildings.size():
		var b: RampageSim.Building = sim.buildings[i]
		if b.frame.alive_count == 0 or not b.in_arena:
			continue
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		var score := b.frame.alive_count / (1.0 + d / BULLDOZE_FALLOFF)
		if score > best_score:
			best_score = score
			best = i
	return best


func _tally(sim: RampageSim) -> void:
	tally["stomps"] = rampage.stomp_ring_at.size()
	tally["falls"] = sim.next_fall_id
	if sim.powers != null and sim.powers.swipe != null:
		tally["swipes"] = sim.powers.swipe.swipes
	if sim.ability_ready_in > _breath_ready + 0.5:
		tally["breaths"] += 1
	_breath_ready = sim.ability_ready_in
	var beam: float = sim.powers.beam_left if sim.powers != null else 0.0
	if beam > 0.0 and _ult_ready <= 0.0:
		tally["beams"] += 1
	_ult_ready = beam


## Every node of `type` under the root, found by class name.
static func nodes_of(tree: SceneTree, type: String) -> Array[Node]:
	return tree.root.find_children("*", type, true, false)
