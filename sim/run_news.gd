class_name RunNews
extends RefCounted
## The rampage's big moments, as sim events the HUD turns into a threat meter and news crawl
## lines (D-259: "A small threat icon", news crawl "On big events"). Pure sim; it decides nothing.
##
## The threat level (1-5) is the army's own escalation read out: how far the tanks' spawn rate
## has climbed from tuning "army" start_interval toward min_interval as the city falls
## (RampageSim.escalation). Tuning "threat" level_at: the share of that climb each level 2..5
## starts at. Each step it appends:
##   {"type": "threat_up", "level"}  the level rose
##   {"type": "landmark_felled", "landmark"}  a landmark lost RunTally's felled share
##   {"type": "towers_toppled", "count"}  the toppled towers reached a tower_counts row

const LOWEST := 1

## The current threat level, LOWEST..LOWEST + level_at.size().
var level := LOWEST
## How far toward the next level the army's escalation is, 0-1 (1 at the top level).
var progress := 0.0
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
	for i: int in sim.buildings.size():
		if sim.buildings[i].landmark != "":
			_standing.append(i)


## How far the army has escalated, 0 (a city caught unaware) to 1 (spawning as fast as it can).
static func army_share(sim: RampageSim) -> float:
	var start := Num.f(sim.army["start_interval"])
	var span := maxf(0.001, start - Num.f(sim.army["min_interval"]))
	return clampf(Num.f(sim.army["escalation_per_chunk"]) * sim.escalation() / span, 0.0, 1.0)


## The threat level for an army escalated to `share` (army_share).
static func level_for(share: float, level_at: Array) -> int:
	var n := LOWEST
	for at: Variant in level_at:
		if share >= Num.f(at):
			n += 1
	return n


## The share of the way from this level's row to the next one's, 0-1; 1 at the top level.
static func progress_for(share: float, level_at: Array) -> float:
	var n := level_for(share, level_at)
	if n > level_at.size():
		return 1.0
	var from := 0.0 if n == LOWEST else Num.f(level_at[n - 2])
	var to := Num.f(level_at[n - 1])
	return clampf((share - from) / maxf(0.001, to - from), 0.0, 1.0)


## Appends this step's big moments to `events`.
func step(events: Array[Dictionary]) -> void:
	var at: Array = _cfg["level_at"]
	var share := army_share(_sim)
	var now := level_for(share, at)
	progress = progress_for(share, at)
	if now > level:
		level = now
		events.append({"type": "threat_up", "level": level})
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
