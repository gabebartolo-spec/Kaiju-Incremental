extends RefCounted
## One seeded, headless rampage feeding CitySound (tests/run_city_sound_tests.gd, and the
## tools/capture/capture_city_sound.gd measurement): a real RampageSim played by the scripted
## player (walk to the nearest standing building, signature when ready, as tests/lib/sim_suite.gd)
## with a real StreetLife beside it, a fixed DT per frame and no clock. Every `SAMPLE_EVERY`
## frames it records the phase and each bed's level, so a test can read how the sound went.
## Seeds "city", "army" and "civilians" 0.

const DT := 1.0 / 60.0
const SAMPLE_EVERY := 60  # frames: one sample a second
## Upgrades owned at each city (capture_kit.gd STAGE_LEVELS): the baby, then the adolescent.
const BABY := {"claws": 2, "hide": 2}
## A baby late in its city, most nodes before the first evolution bought: the
## wider young city (D-135) holds about twice the people, and the ruin the sound design waits for
## (destruction and people fled, both as shares) takes a kaiju this strong, not the first-run one.
const LATE_BABY := {"claws": 5, "hide": 5, "rage": 5, "quake": 2}
const ADOLESCENT := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}

var sim: RampageSim
var street: StreetLife
var sound: CitySound
## One row per sample: {"t": seconds, "phase": float, "levels": {bed: dB}, "fled": int,
## "destroyed": float}.
var samples: Array[Dictionary] = []
var _holder: Node3D
var _target := Vector2(INF, INF)
var _frame := 0


## tier: the city's growth step (1..3); levels: the upgrades owned.
func _init(tree: SceneTree, tier: int, levels: Dictionary) -> void:
	var table: Dictionary = Content.section("display")["graphics"]
	var row: Dictionary = table["high"]
	GraphicsPresets.start_run(row)
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), levels, "reptilian")
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
	_holder.add_child(street)
	street.set_process(false)  # step() runs its frames, at DT
	sound = CitySound.new(sim, street, null)
	_holder.add_child(sound)
	sound.set_process(false)


## One frame: the scripted player moves, the street lives, the driver follows.
func step() -> void:
	if _frame % 15 == 0:
		_target = sim.nearest_standing(sim.kaiju_pos)
	var move := Vector2.ZERO
	if _target.x < INF and not sim.stomp_reaches(_target):
		move = (_target - sim.kaiju_pos).normalized()
	sim.step(DT, move, sim.ability_ready_in <= 0.0)
	sim.events.clear()
	street._process(DT)
	sound.advance(DT)
	if _frame % SAMPLE_EVERY == 0:
		samples.append(
			{
				"t": _frame * DT,
				"phase": sound.phase,
				"levels": sound.levels.duplicate(),
				"fled": street.fled,
				"destroyed": sim.destruction()
			}
		)
	_frame += 1


## Runs `seconds` of play.
func run(seconds: float) -> void:
	for _i: int in roundi(seconds / DT):
		step()


## Frees the nodes it added.
func finish() -> void:
	_holder.queue_free()


## True when the beds follow D-155: the panic beds (crowd trim, sirens) rise to a peak in the
## first `early` share of the samples and have fallen at least `drop_db` below it by the end, and
## the ruin beds (gunfire, fire, wind) end louder than they began. `series` is `samples`.
static func panic_then_quiet(series: Array[Dictionary], early: float, drop_db: float) -> bool:
	if series.size() < 4:
		return false
	var cut := maxi(1, floori(series.size() * early))
	for bed: String in ["crowd", "city_siren"]:
		var peak_at := 0
		for i: int in series.size():
			if series[i]["levels"][bed] > series[peak_at]["levels"][bed]:
				peak_at = i
		var last: float = series[series.size() - 1]["levels"][bed]
		if peak_at > cut or last > series[peak_at]["levels"][bed] - drop_db:
			return false
	for bed: String in ["city_gunfire", "city_fire", "city_wind"]:
		if series[series.size() - 1]["levels"][bed] <= series[0]["levels"][bed]:
			return false
	return true
