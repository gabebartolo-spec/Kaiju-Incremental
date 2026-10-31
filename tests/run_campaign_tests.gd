extends "res://tests/lib/runner.gd"
## Campaign suite (Overworld plan row F3, D-418..D-422): the seven continents load through Content
## in the globe's sequence with the ruled names and stages; each conquest offers three bonuses and
## the capital, last, none; the six conquests' Threat shares leave room for mission noise; every
## id is a key the save's campaign can hold. Plan row F4: a picked bonus reaches combat through
## the upgrade path (UpgradeTree), on vs off, with no combat code of its own. Plan row G3: which
## continents are locked, available and conquered follows D-420 and D-422 (Campaign). The hologram
## globe's checks (rows G1..G4) live in run_globe_tests.gd. Seeded, no clock.
##   godot --headless --path . --script tests/run_campaign_tests.gd

const ORDER := [
	"ostia_minor", "carthago", "thule", "silvania", "mons_ferrata", "neptunia", "aurelia"
]
const NAMES := [
	"Ostia Minor", "Carthago", "Thule", "Silvania", "Mons Ferrata", "Neptunia", "Aurelia"
]
const STAGES := [0, 1, 1, 2, 2, 2, 2]  # D-419: young, Behemoth x2, Colossus x3 and the capital
## D-422: conquests and noise cap below 100; only the sixth conquest opens Aurelia.
const THREAT_CAP := 99.0
const SPECIES := "reptilian"
const ATTACK := "bonus_ostia_minor_1"  # the test bonus: stomp_damage +15%


func suite_name() -> String:
	return "Campaign"


func run_checks() -> void:
	await _t("_check_seven_in_order")
	await _t("_check_stages")
	await _t("_check_bonuses_and_capital")
	await _t("_check_threat_shares")
	await _t("_check_save_keys")
	await _t("_check_bonus_scales_stats")
	await _t("_check_bonus_in_combat")
	await _t("_check_states")


func _check_seven_in_order() -> void:
	var rows := Content.continents()
	var ids: Array = rows.map(func(c: Dictionary) -> String: return str(c["id"]))
	var names: Array = rows.map(func(c: Dictionary) -> String: return str(c["name"]))
	check(rows.size() == 7, "Content loads all 7 continents (got %d)" % rows.size())
	check(ids == ORDER, "they come in the globe's sequence, Ostia Minor first (D-420): %s" % [ids])
	check(names == NAMES, "with the ruled names (D-418): %s" % [names])
	check(
		str(Content.continent("thule").get("name", "")) == "Thule", "continent(id) finds one by id"
	)
	check(Content.continent("atlantis").is_empty(), "an unknown id gives {}")


func _check_stages() -> void:
	var stages: Array[int] = []
	for c: Dictionary in Content.continents():
		var stage: int = c["stage"]
		stages.append(stage)
	var growth: Dictionary = Content.tuning()["growth"]
	var ruled: Array = growth["stages"]
	check(stages == STAGES, "each city plays at its ruled growth stage (D-419): %s" % [stages])
	check(
		stages.all(func(s: int) -> bool: return s >= 0 and s < ruled.size()), "every stage exists"
	)


func _check_bonuses_and_capital() -> void:
	var seen := {}
	var capitals: Array[String] = []
	for c: Dictionary in Content.continents():
		var capital: bool = c["capital"]
		var picks: Array = c["bonuses"]
		check(
			picks.size() == (0 if capital else 3),
			"%s offers %d bonuses (D-421)" % [c["id"], picks.size()]
		)
		for pick: Dictionary in picks:
			var b := str(pick["id"])
			check(not seen.has(b), "bonus id %s is offered once" % b)
			check(Content.bonus(b) == pick, "Content.bonus finds %s" % b)
			seen[b] = true
		if capital:
			capitals.append(str(c["id"]))
	check(capitals == ["aurelia"], "Aurelia is the one capital (D-422): %s" % [capitals])
	var last: Dictionary = Content.continents().back()
	var last_capital: bool = last["capital"]
	check(last_capital, "the capital is last")


func _check_threat_shares() -> void:
	var total := 0.0
	for c: Dictionary in Content.continents():
		var capital: bool = c["capital"]
		var share: float = c["threat"]
		if not capital:
			total += share
	check(
		is_equal_approx(total, 80.0),
		"the six conquests add 80 Threat, noise the rest (got %s)" % total
	)
	check(total < THREAT_CAP, "conquests alone stay under the %s cap (D-422)" % THREAT_CAP)


func _check_save_keys() -> void:
	var conquered: Array = []
	var bonuses := {}
	for c: Dictionary in Content.continents():
		var capital: bool = c["capital"]
		var picks: Array = c["bonuses"]
		conquered.append(c["id"])
		if not capital:
			var first: Dictionary = picks[0]
			bonuses[c["id"]] = first["id"]
	var save := SaveFile.campaign()
	save["conquered"] = conquered
	save["bonuses"] = bonuses
	var back: Variant = JSON.parse_string(JSON.stringify(save))
	check(back is Dictionary, "a campaign holding every continent writes as JSON")
	var read: Dictionary = back
	var read_bonuses: Dictionary = read["bonuses"]
	var read_conquered: Array = read["conquered"]
	check(read_conquered == ORDER, "every id round-trips as a save's conquered key")
	check(read_bonuses == bonuses, "each conquest's pick round-trips by its id")


## The stats a run starts with, for a tree with these levels and these picks (continent -> bonus).
func _stats(levels: Dictionary, picked: Dictionary) -> Dictionary:
	var tree := UpgradeTree.new(Content.upgrades(), levels, SPECIES, picked)
	return UpgradeTree.run_stats(Content.section("kaiju"), Content.species_def(SPECIES), tree)


func _check_bonus_scales_stats() -> void:
	var off := _stats({}, {})
	var on := _stats({}, {"ostia_minor": ATTACK})
	var off_hit: float = off["stomp_damage"]
	var on_hit: float = on["stomp_damage"]
	check(
		is_equal_approx(on_hit, off_hit * 1.15),
		"the attack bonus makes the stomp 15%% stronger (%.3f -> %.3f)" % [off_hit, on_hit]
	)
	var off_hp: float = off["hp"]
	var on_hp: float = on["hp"]
	check(is_equal_approx(on_hp, off_hp), "it leaves every other stat alone")
	var bought := {"evolve1": 1}  # +4 stomp_damage for every species
	var up_off := _stats(bought, {})
	var up_on := _stats(bought, {"ostia_minor": ATTACK})
	var up_off_hit: float = up_off["stomp_damage"]
	var up_on_hit: float = up_on["stomp_damage"]
	check(
		up_off_hit != off_hit and is_equal_approx(up_on_hit, up_off_hit * 1.15),
		"it scales the stat after the upgrades bought (%.3f -> %.3f)" % [up_off_hit, up_on_hit]
	)
	var unknown := _stats({}, {"ostia_minor": "no_such_bonus"})
	var unknown_hit: float = unknown["stomp_damage"]
	check(is_equal_approx(unknown_hit, off_hit), "a pick no continent offers changes nothing")


## One stomp through the sim's own strike path (Strikes.stomp, as RampageStomp lands it) on a
## tank under the foot, the save's bonus picked and not: the bonus stomp takes 15% more hp off it.
## A tank's hp drops by exactly the blow (buildings carve against material thresholds, so their
## loss is not proportional to it). No combat code changed.
func _check_bonus_in_combat() -> void:
	var off := _stomp_once({})
	var on := _stomp_once({"ostia_minor": ATTACK})
	check(
		off > 0.0 and is_equal_approx(on, off * 1.15),
		"a stomp in the sim does 15%% more with the attack bonus (%.2f -> %.2f hp)" % [off, on]
	)


func _stomp_once(picked: Dictionary) -> float:
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new(_stats({}, picked), Content.tuning(), empty, Seeds.make("army", 0))
	var tank := RampageSim.Tank.new()
	tank.hp = 1000.0
	tank.cooldown = 1000.0
	sim.tanks.append(tank)
	sim.strikes.stomp(tank.pos, 0.0)
	var lost := 1000.0 - tank.hp
	sim.dispose()
	return lost


## D-420: Ostia Minor alone, then the two lowest unconquered in sequence; D-422: the capital once
## the other six have fallen. Each case: the conquered ids, then the ids that must be available.
func _check_states() -> void:
	var cases := [
		[[], ["ostia_minor"]],
		[["ostia_minor"], ["carthago", "thule"]],
		[["ostia_minor", "carthago"], ["thule", "silvania"]],
		[["ostia_minor", "thule"], ["carthago", "silvania"]],
		[["ostia_minor", "thule", "silvania", "neptunia"], ["carthago", "mons_ferrata"]],
		[ORDER.slice(0, 5), ["neptunia"]],
		[ORDER.slice(0, 6), ["aurelia"]],
		[ORDER, []],
	]
	for c: Array in cases:
		var conquered: Array = c[0]
		var open: Array = c[1]
		var states := Campaign.states(Content.continents(), conquered)
		var wrong: Array[String] = []
		for id: String in ORDER:
			var want := Campaign.State.LOCKED
			if conquered.has(id):
				want = Campaign.State.CONQUERED
			elif open.has(id):
				want = Campaign.State.AVAILABLE
			if states.get(id, -1) != want:
				wrong.append(id)
		check(
			wrong.is_empty(), "after %s the globe offers %s (wrong: %s)" % [conquered, open, wrong]
		)
