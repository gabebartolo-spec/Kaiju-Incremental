class_name RunNews
extends RefCounted
## The rampage's big moments, as sim events the HUD turns into a threat meter and news crawl
## lines (D-259: "A small threat icon", news crawl "On big events"). Pure sim; it decides nothing.
##
## The threat level (1-5) is the city's own, tuning "threat" "level" (a growth stage overrides
## it), fixed for the whole run (D-437): it sets where the army starts, the share of its spawn
## ramp from "army" start_interval toward min_interval that "level_at" gives that level
## (alert_chunks); destruction climbs the army on from there, the level never moves. Each step:
##   {"type": "landmark_felled", "landmark"}  a landmark lost RunTally's felled share
##   {"type": "towers_toppled", "count"}  the toppled towers reached a tower_counts row

const LOWEST := 1

## The city's threat level, LOWEST..LOWEST + level_at.size().
var level := LOWEST
var _sim: RampageSim
var _cfg: Dictionary
## Indices of the landmarks still standing (not yet reported felled).
var _standing: Array[int] = []
var _felled_share := 0.0
var _towers := 0


func _init(sim: RampageSim, tuning: Dictionary) -> void:
	_sim = sim
	_cfg = tuning.get("threat", Content.section("threat"))
	var results: Dictionary = tuning.get("results", Content.section("results"))
	_felled_share = Num.f(results["landmark_felled_share"])
	level = Num.i(_cfg["level"])
	for i: int in sim.buildings.size():
		if sim.buildings[i].landmark != "":
			_standing.append(i)


## Chunks of escalation that put `army` at the city's own threat level from the start (D-437):
## the share of its spawn ramp where that level begins (tuning "threat" level, level_at).
static func alert_chunks(army: Dictionary, tuning: Dictionary) -> int:
	var cfg: Dictionary = tuning.get("threat", Content.section("threat"))
	var at: Array = cfg["level_at"]
	var n := Num.i(cfg["level"])
	if n <= LOWEST:
		return 0
	var span := Num.f(army["start_interval"]) - Num.f(army["min_interval"])
	return ceili(Num.f(at[n - 2]) * span / Num.f(army["escalation_per_chunk"]))


## Appends this step's big moments to `events`.
func step(events: Array[Dictionary]) -> void:
	for i: int in _standing.duplicate():
		var b := _sim.buildings[i]
		if RunTally.felled(b.start_chunks, b.frame.alive_count, _felled_share):
			_standing.erase(i)
			events.append({"type": "landmark_felled", "landmark": b.landmark})
	var toppled := _sim.collapse.toppled
	if toppled == _towers:
		return
	var counts: Array = _cfg["tower_counts"]
	for count: Variant in counts:
		if _towers < Num.i(count) and toppled >= Num.i(count):
			events.append({"type": "towers_toppled", "count": Num.i(count)})
	_towers = toppled
