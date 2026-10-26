extends "res://tests/lib/runner.gd"
## Tree suite (ROADMAP E, b2-28, R 16.1, R 1.1, R 1.4): the upgrade tree grows outward in rings,
## each node a kind; the data obeys its schema (tuning "tree": rings, kinds, geometric costs);
## only the open rings can be bought, the next shows as shapes, evolutions always show; an old
## save keeps every level it bought; and the pacing bot's shopping over the data's income
## stand-in meets the cadence bars over the first hour. No rampage is played: the pacing check is
## a pure replay of TreePacing (the real bot is tools/pacing.gd), so it is the same every run.
##   godot --headless --path . --script tests/run_tree_tests.gd

const CROC := "reptilian"
## Levels a played croc held before rings existed (the old tree let scales be bought young):
## every id and level must come back unchanged.
const OLD_LEVELS := {
	"claws": 5,
	"hide": 5,
	"stride": 4,
	"rage": 3,
	"scales": 2,
	"r_tail": 2,
	"evolve1": 1,
	"sig_power": 3,
	"r_ablaze": 1
}


func suite_name() -> String:
	return "Tree"


func run_checks() -> void:
	await _t("_check_schema")
	await _t("_check_costs_geometric")
	await _t("_check_ring_sizes")
	await _t("_check_reveal_young")
	await _t("_check_reveal_grown")
	await _t("_check_unringed_species")
	await _t("_check_old_save")
	await _t("_check_bars_catch")
	await _t("_check_pacing")


func _croc(levels: Dictionary = {}) -> UpgradeTree:
	return UpgradeTree.new(Content.upgrades(), levels, CROC)


## The ids of ring `r` in data order.
func _ring_ids(tree: UpgradeTree, r: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in tree.order:
		if tree.ring(id) == r:
			out.append(id)
	return out


## Every node of a ringed species: a ring that exists, a known kind, a stage exactly when it
## grows the kaiju, and never inside a ring nearer the centre than a node it needs.
func _check_schema() -> void:
	var cfg: Dictionary = Content.section("tree")
	var kinds: Array = cfg["kinds"]
	var ringed: Dictionary = cfg["species"]
	var bad: Array[String] = []
	for species_id: String in ringed:
		var tree := UpgradeTree.new(Content.upgrades(), {}, species_id)
		check(not tree.rings.is_empty(), "%s has rings in tuning tree" % species_id)
		for id: String in tree.order:
			var def: Dictionary = tree.defs[id]
			var effects: Dictionary = def.get("effects", {})
			if not def.has("ring") or not def.has("kind"):
				bad.append("%s has no ring or kind" % id)
				continue
			if str(def.get("source", "")) == "":
				bad.append("%s names no source (his words, or agent-added)" % id)
			if tree.ring(id) < 1 or tree.ring(id) > tree.rings.size():
				bad.append("%s in ring %d" % [id, tree.ring(id)])
			if not kinds.has(tree.kind(id)) or (tree.kind(id) == "stage") != effects.has("size"):
				bad.append("%s kind %s" % [id, tree.kind(id)])
			var requires: Array = def.get("requires", [])
			for req: String in requires:
				if tree.defs.has(req) and tree.ring(req) > tree.ring(id):
					bad.append("%s (ring %d) needs %s further out" % [id, tree.ring(id), req])
		for r: int in range(1, tree.rings.size()):
			var inner: Dictionary = tree.rings[r - 1]
			var outer: Dictionary = tree.rings[r]
			if Num.i(outer["stage"]) < Num.i(inner["stage"]):
				bad.append("ring %d opens at an earlier stage than ring %d" % [r + 1, r])
	check(bad.is_empty(), "every ringed node has a ring and kind that fit the tree: %s" % [bad])


## Each level of a ringed species' node costs cost_rate times the level before (geometric,
## research 01 rec 1), one price per level.
func _check_costs_geometric() -> void:
	var cfg: Dictionary = Content.section("tree")
	var rate: Array = cfg["cost_rate"]
	var ringed: Dictionary = cfg["species"]
	var bad: Array[String] = []
	for species_id: String in ringed:
		var tree := UpgradeTree.new(Content.upgrades(), {}, species_id)
		for id: String in tree.order:
			var costs: Array = tree.defs[id]["cost"]
			if costs.size() != tree.max_level(id):
				bad.append("%s: %d prices for %d levels" % [id, costs.size(), tree.max_level(id)])
			for i: int in range(1, costs.size()):
				var step := Num.f(costs[i]) / Num.f(costs[i - 1])
				if step < Num.f(rate[0]) or step > Num.f(rate[1]):
					bad.append("%s level %d is x%.3f" % [id, i + 1, step])
	check(bad.is_empty(), "every level costs x%s-%s the one before: %s" % [rate[0], rate[1], bad])


## b2-28: each ring reaches the node count it is meant to (about 14 / 16 / 18 / 10).
func _check_ring_sizes() -> void:
	var tree := _croc()
	for r: int in range(1, tree.rings.size() + 1):
		var ring_def: Dictionary = tree.rings[r - 1]
		var have := _ring_ids(tree, r).size()
		check(
			have >= Num.i(ring_def["target"]),
			"the croc's ring %d holds %d nodes of its %d" % [r, have, Num.i(ring_def["target"])]
		)


## A new croc: ring 1 in full and buyable, ring 2 as shapes that cannot be bought at any price,
## everything further out hidden, and each evolution always in view (the landmark ahead).
func _check_reveal_young() -> void:
	var tree := _croc()
	var wrong: Array[String] = []
	for id: String in tree.order:
		var want := UpgradeTree.Reveal.HIDDEN
		if tree.ring(id) == 1:
			want = UpgradeTree.Reveal.FULL
		elif tree.ring(id) == 2 or tree.kind(id) == "stage":
			want = UpgradeTree.Reveal.SHAPE
		if tree.reveal(id) != want:
			wrong.append("%s shows %d, not %d" % [id, tree.reveal(id), want])
		if tree.ring(id) > 1 and tree.is_unlocked(id):
			wrong.append("%s can be bought from a closed ring" % id)
	check(tree.can_buy("claws", 1000000), "a new croc can buy a centre node")
	check(
		wrong.is_empty(), "a new croc sees ring 1, ring 2 as shapes, nothing further: %s" % [wrong]
	)


## Growing opens the rings in turn: Behemoth opens ring 2 (ring 3 as shapes); Colossus with a
## ring 2 node opens ring 3; a ring 3 node opens ring 4.
func _check_reveal_grown() -> void:
	var levels := {"claws": 1, "hide": 1, "rage": 1, "evolve1": 1}
	var behemoth := _croc(levels)
	var r2 := _ring_ids(behemoth, 2)
	var r3 := _ring_ids(behemoth, 3)
	var r4 := _ring_ids(behemoth, 4)
	check(
		behemoth.reveal(r2[0]) == UpgradeTree.Reveal.FULL and behemoth.ring_open(2),
		"Behemoth opens ring 2"
	)
	check(
		behemoth.reveal(r3[0]) == UpgradeTree.Reveal.SHAPE and not behemoth.ring_open(3),
		"Behemoth sees ring 3 as shapes only"
	)
	levels["evolve2"] = 1
	var colossus := _croc(levels)
	check(colossus.ring_open(3), "Colossus with a ring 2 node (its evolution) opens ring 3")
	check(
		not colossus.ring_open(4) and colossus.reveal(r4[0]) == UpgradeTree.Reveal.SHAPE,
		"ring 4 stays shapes until a ring 3 node is owned"
	)
	levels[r3[0]] = 1
	check(_croc(levels).ring_open(4), "a ring 3 node opens ring 4")


## A species without rings keeps today's whole tree open (the insectoid and cephalopod).
func _check_unringed_species() -> void:
	var tree := UpgradeTree.new(Content.upgrades(), {}, "insectoid")
	var shut: Array[String] = []
	for id: String in tree.order:
		if tree.reveal(id) != UpgradeTree.Reveal.FULL or not tree.ring_open(tree.ring(id)):
			shut.append(id)
	check(tree.rings.is_empty() and shut.is_empty(), "the insectoid tree is all open: %s" % [shut])


## An old save keeps every level it bought: through the migration, a save to disk and back and
## a new tree, ids and levels are unchanged, and a node owned in a ring not open yet still shows.
func _check_old_save() -> void:
	var save := SaveFile.new_save(CROC)
	save["version"] = 4
	save["levels"] = OLD_LEVELS.duplicate()
	var up := SaveFile.migrate(save)
	SaveFile.save_game(up, 3)
	var back := SaveFile.load_game(3)
	SaveFile.delete_save(3)
	var saved: Dictionary = back.get("levels", {})
	var tree := _croc(saved)
	var lost: Array[String] = []
	for id: String in OLD_LEVELS:
		if tree.level(id) != Num.i(OLD_LEVELS[id]):
			lost.append("%s %d of %d" % [id, tree.level(id), Num.i(OLD_LEVELS[id])])
	check(
		lost.is_empty(), "an old save keeps every level through migrate, disk and tree: %s" % [lost]
	)
	var young := _croc({"claws": 1, "scales": 2})
	check(
		young.level("scales") == 2 and young.reveal("scales") == UpgradeTree.Reveal.FULL,
		"a node an old save owns in a closed ring is kept and shown"
	)


## The bars catch what they guard (a planted bad cadence): a visit with no buy, one with six,
## a long run without a verb and a late evolution are each named.
func _check_bars_catch() -> void:
	var pacing: Dictionary = Content.section("tree")["pacing"]
	var tree := _croc()
	var shop := TreePacing.new(Num.f(pacing["tree_seconds"]))
	var none: Array[String] = []
	var six: Array[String] = ["claws", "claws", "hide", "hide", "rage", "rage"]
	for run: int in 9:
		var bought: Array[String] = six if run == 1 else none
		shop.visits.append({"run": run + 1, "end_hours": 0.01 * (run + 1), "bought": bought})
	shop.first_buy_seconds = 30.0
	var misses := shop.misses(tree, pacing)
	var said := "; ".join(misses)
	check(
		(
			said.contains("run 1 bought 0")
			and said.contains("run 2 bought 6")
			and said.contains("without a new verb")
			and said.contains("evolve1 at")
		),
		(
			"the bars name an empty visit, a six-buy visit, a verb drought and a missing evolution: %s"
			% said
		)
	)


## R 16.1 / R 1.1: the bot's cheapest-first shopping over the data's income stand-in, for the
## first hour: 1-4 buys after every rampage, at most 5 runs between new verbs or evolutions,
## each evolution within 20% of its hour, the first purchase inside 60 s. Prints the cadence.
func _check_pacing() -> void:
	var pacing: Dictionary = Content.section("tree")["pacing"]
	var tree := _croc()
	var shop := TreePacing.new(Num.f(pacing["tree_seconds"]))
	var counts := ""
	while tree.levels_owned() < tree.levels_total() and shop.visits.size() < 400:
		var pay := TreePacing.model_income(tree, pacing)
		var bought := shop.visit(tree, Num.f(pay[1]), Num.i(pay[0]))
		counts += str(mini(bought.size(), 9))
	print(
		(
			"  croc pacing: %d visits, %.2f h, evolve1 %.2f h, evolve2 %.2f h, buys %s"
			% [
				shop.visits.size(),
				shop.clock / 3600.0,
				Num.f(shop.first_bought.get("evolve1", -1.0)),
				Num.f(shop.first_bought.get("evolve2", -1.0)),
				counts,
			]
		)
	)
	var misses := shop.misses(tree, pacing)
	check(misses.is_empty(), "the croc's first hour meets every cadence bar: %s" % [misses])
