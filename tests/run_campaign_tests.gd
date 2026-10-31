extends "res://tests/lib/runner.gd"
## Campaign suite (Overworld plan row F3, D-418..D-422): the seven continents load through Content
## in the globe's sequence with the ruled names and stages; each conquest offers three bonuses and
## the capital, last, none; the six conquests' Threat shares leave room for mission noise; every
## id is a key the save's campaign can hold. Data only, no clock.
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


func suite_name() -> String:
	return "Campaign"


func run_checks() -> void:
	await _t("_check_seven_in_order")
	await _t("_check_stages")
	await _t("_check_bonuses_and_capital")
	await _t("_check_threat_shares")
	await _t("_check_save_keys")


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
		for b: Variant in picks:
			check(not seen.has(b), "bonus id %s is offered once" % b)
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
			bonuses[c["id"]] = picks[0]
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
