extends RefCounted
## A seeded StreetLife run driven frame by frame, headless (tests/run_street_tests.gd): a city of
## `tier` with a graphics preset's civilians, an adult croc walking a straight line from its start
## toward the centre, a stomp crush every STOMP_EVERY frames and a falling-section brace every
## BRACE_EVERY, a fixed DT per frame (no clock). Seeds "city", "army" and "civilians" 0.

const DT := 1.0 / 60.0
const WALK := 4.0  # the kaiju's pace along its line, m/s
const STOMP_EVERY := 42  # frames: the 0.7 s stomp rhythm
const BRACE_EVERY := 150
const BRACE_FROM := 6.0  # the braced strip runs this far ahead of the kaiju ...
const BRACE_TO := 16.0  # ... to this far, BRACE_RADIUS wide, landing in BRACE_SECONDS
const BRACE_RADIUS := 3.0
const BRACE_SECONDS := 1.0
const ADULT := {"evolve1": 1, "evolve2": 1}

var street: StreetLife
var sim: RampageSim
var _holder: Node3D
var _start: Vector2
var _dir: Vector2
var _reach: float
var _frame := 0


## buffered: render_opt.people_buffers for this run (the default is the data's).
func _init(tree: SceneTree, tier: int, preset: String, buffered: bool = true) -> void:
	var table: Dictionary = Content.section("display")["graphics"]
	var row: Dictionary = table[preset]
	GraphicsPresets.start_run(row)
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), ADULT, "reptilian")
	)
	var base := Content.tuning()
	sim = RampageSim.new(
		stats,
		CityGrowth.tuning_for(base, tier),
		CityGrowth.layout(base, tier, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	_holder = Node3D.new()
	tree.root.add_child(_holder)
	var fx := Fx.new()
	_holder.add_child(fx)
	street = StreetLife.new(sim, fx, Seeds.make("civilians", 0))
	street.people_buffers = buffered
	_holder.add_child(street)
	street.set_process(false)  # step() runs its frames, at DT
	_start = sim.kaiju_pos
	_dir = (Vector2.ZERO - _start).normalized()
	sim.facing = _dir
	_reach = street.tune("stomp_catch") * sim.body_scale()


## One frame: the kaiju moves on, a stomp or a brace when due, then the street's own frame.
func step() -> void:
	sim.kaiju_pos = _start + _dir * WALK * DT * _frame
	var k := sim.kaiju_pos
	if _frame % STOMP_EVERY == STOMP_EVERY - 1:
		street.crush(Vector3(k.x, 0.0, k.y), _reach)
	if _frame % BRACE_EVERY == BRACE_EVERY - 1:
		street.brace(k + _dir * BRACE_FROM, k + _dir * BRACE_TO, BRACE_RADIUS, BRACE_SECONDS)
	street._process(DT)
	_frame += 1


## Everyone's state in order, the three random streams and the totals, as one SHA-256 (hex).
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for column: Variant in [
		street.pos,
		street.heading,
		street.outfit,
		street.from_node,
		street.to_node,
		street.fleeing,
		street.cop,
		street.phase,
		street.side,
		street.pace,
		street.pinned_until
	]:
		ctx.update(var_to_bytes(column))
	var totals := PackedInt64Array(
		[
			street._rng.state,
			street.police._rng.state,
			street.traffic._rng.state,
			street.fled,
			street.killed,
			street.police.shots
		]
	)
	ctx.update(totals.to_byte_array())
	return ctx.finish().hex_encode()


## Frees the city and puts the player's graphics counts back. The sim and its parts count each
## other, so a dropped sim is never freed (SimTeardown, D-179): the game's owners dispose it
## (scenes/rampage.gd, title_backdrop.gd), and so does this one, or every replay leaks its city.
func finish() -> void:
	_holder.free()
	sim.dispose()
	GraphicsPresets.start_run(PlayerSettings.graphics_row())
