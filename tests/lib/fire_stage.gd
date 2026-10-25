extends RefCounted
## The fire suite's adult-city checks, split out to keep the runner small: on the adult city with
## every fire node owned, a few blocks lit by the kaiju spread fire; the same seed replays the
## same fires and biomass (the trace hash); every burnt-out building is down (no burning shell,
## #111) and paid near burn_pay of a smash, never more (D-126); the fire's own bookkeeping a tick
## stays in budget (the collapses it sets off are the destruction engine's, reported apart).
## Player-effect fixture "fire.spread": the same seeded scene without City Ablaze burns nothing.

const DT := 1.0 / 30.0
const SECONDS := 30.0
## Blocks lit at the start, the ones nearest the kaiju.
const LIT := 6
## The fire's own bookkeeping a tick at adult city, at most (usec, headless; FireSpread.step without
## the burn-outs' damage and collapse): the budget.
const BUDGET_USEC := 1000.0
## How far a near burn-out's share of a smash may sit above burn_pay (the conflagration).
const NEAR_PAY := 0.1
const LEVELS := {
	"evolve1": 1,
	"evolve2": 1,
	"r_ablaze": 1,
	"r_alarm": 3,
	"r_front": 2,
	"r_embers": 2,
	"r_firestorm": 1,
}

var _check: Callable


## Checks and prints the line: the adult-city numbers are the evidence (usec, hash, counts).
func _say(ok: bool, says: String) -> void:
	print("FireStage: ", says)
	_check.call(ok, says)


## FireSpread with a stopwatch on its tick and, apart, on its burn-outs giving way (the damage
## and the collapse they set off).
class TimedFire:
	extends FireSpread
	var usec := 0
	var out_usec := 0

	func step(dt: float) -> void:
		var t0 := Time.get_ticks_usec()
		super(dt)
		usec += Time.get_ticks_usec() - t0

	func _crumble(i: int) -> void:
		var t0 := Time.get_ticks_usec()
		super(i)
		out_usec += Time.get_ticks_usec() - t0


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var a := _play(LEVELS)
	var b := _play(LEVELS)
	var trace: PackedStringArray = a["trace"]
	var same: bool = trace == b["trace"] and Num.f(a["rubble"]) == Num.f(b["rubble"])
	var says := "adult: fire spreads past the %d lit blocks to %d" % [LIT, Num.i(a["lit"])]
	says += (
		", and the same seed replays the same %d fire events (hash %d vs %d) and biomass (%.1f vs %.1f)"
		% [trace.size(), hash(trace), hash(b["trace"]), Num.f(a["rubble"]), Num.f(b["rubble"])]
	)
	_say(same and Num.i(a["lit"]) > LIT, says)
	_check_after(a)
	var off_levels := LEVELS.duplicate()
	off_levels.erase("r_ablaze")
	var off := _play(off_levels)
	_say(
		Num.i(off["lit"]) == 0 and Num.i(off["burnt"]) == 0 and Num.i(a["burnt"]) > 0,
		(
			(
				"fire.spread: the same seeded scene burns out %d buildings (biomass %.1f) with City"
				+ " Ablaze and none without (biomass %.1f)"
			)
			% [Num.i(a["burnt"]), Num.f(a["rubble"]), Num.f(off["rubble"])]
		)
	)


func _check_after(a: Dictionary) -> void:
	var share: Array = a["shares"]
	var burn_pay := Num.f(Content.tuning()["powers"]["fire"]["burn_pay"])
	var near_ok := share.all(
		func(x: float) -> bool: return x >= burn_pay - 0.001 and x <= burn_pay + NEAR_PAY
	)
	_say(
		not share.is_empty() and near_ok and Num.f(a["far_max"]) < 1.0,
		(
			(
				"adult: %d near burn-outs pay %.2f..%.2f of a smash (burn_pay %.2f), the far ones at"
				+ " most %.2f: never more than a smash"
			)
			% [share.size(), share.min(), share.max(), burn_pay, Num.f(a["far_max"])]
		)
	)
	_say(
		Num.i(a["shells"]) == 0,
		(
			"adult: every one of %d burnt-out buildings is down, none a burning shell (%d stand)"
			% [Num.i(a["burnt"]), Num.i(a["shells"])]
		)
	)
	var ticks := SECONDS / DT
	var own := (Num.f(a["usec"]) - Num.f(a["out_usec"])) / ticks
	_say(
		own <= BUDGET_USEC,
		(
			(
				"adult (%d buildings): the fire's own bookkeeping costs %.0f usec a tick (budget %.0f);"
				+ " its %d burn-outs' collapses %.0f usec a tick more (%.0f each)"
			)
			% [
				Num.i(a["buildings"]),
				own,
				BUDGET_USEC,
				Num.i(a["burnt"]),
				Num.f(a["out_usec"]) / ticks,
				Num.f(a["out_usec"]) / maxf(1.0, Num.f(a["burnt"]))
			]
		)
	)


## One seeded adult-city run: {"trace": every fire event in order, "rubble", "lit": buildings
## that burned, "burnt": burn-outs, "shares": near burn-outs' pay shares, "far_max", "shells":
## burnt-out buildings still standing, "usec", "out_usec", "buildings"}.
func _play(levels: Dictionary) -> Dictionary:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 1000000.0  # the kaiju must not fall: this watches the fire to the clock
	var adult := CityGrowth.stage_count(Content.tuning())
	var tuning := CityGrowth.tuning_for(Content.tuning(), adult)
	var layout := CityGrowth.layout(Content.tuning(), adult, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	var old := sim.powers.fire
	var fire := TimedFire.new(sim, old.cfg, Seeds.make("fire", 0))
	sim.powers.fire = fire
	var trace := PackedStringArray()
	var lit := {}  # buildings that burned (the lit ones too)
	for i: int in _nearest(sim, LIT):
		fire.ignite(i)
		if fire.state[i] == FireSpread.State.BURNING:
			lit[i] = true
	var shares: Array[float] = []
	var far_max := 0.0
	for step: int in roundi(SECONDS / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, RampageSim.STOMP):
			var kind := str(event["type"])
			if not kind.begins_with("fire_"):
				continue
			trace.append("%d:%s" % [Num.i(event["building"]), kind])
			if kind == "fire_burning":
				lit[event["building"]] = true
			elif kind == "fire_burnt":
				var share := Num.f(event["share"])
				if event["far"] == true:
					far_max = maxf(far_max, share)
				else:
					shares.append(share)
	var shells := 0
	for i: int in sim.buildings.size():
		if fire.state[i] == FireSpread.State.BURNT and sim.buildings[i].frame.alive_count > 0:
			shells += 1
	return {
		"trace": trace,
		"rubble": sim.rubble,
		"lit": lit.size(),
		"burnt": fire.burnt_out,
		"shares": shares,
		"far_max": far_max,
		"shells": shells,
		"usec": fire.usec,
		"out_usec": fire.out_usec,
		"buildings": sim.buildings.size(),
	}


## The `count` standing buildings nearest the kaiju, nearest first.
func _nearest(sim: RampageSim, count: int) -> Array[int]:
	var order: Array[int] = []
	for i: int in sim.buildings.size():
		if sim.buildings[i].frame.alive_count > 0 and sim.buildings[i].landmark == "":
			order.append(i)
	var at := sim.kaiju_pos
	order.sort_custom(
		func(x: int, y: int) -> bool:
			var bx := sim.buildings[x]
			var by := sim.buildings[y]
			return Vector2(bx.x, bx.z).distance_to(at) < Vector2(by.x, by.z).distance_to(at)
	)
	return order.slice(0, count)
