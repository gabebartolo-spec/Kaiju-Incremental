class_name TreePacing
extends RefCounted
## The pacing bot's shopping and its cadence bars (ROADMAP E, R 16.1, R 1.1). Between rampages
## the bot buys the cheapest node it can afford until none is left (tools/pacing.gd); this
## records every visit to the tree and checks the bars in tuning "tree" "pacing" over the first
## window_hours: buys a visit inside buys_per_visit, at most max_runs_between_verbs runs between
## a new verb or stage node, each evolution within evolve_tolerance of its target hour, the
## first purchase inside first_buy_seconds. Pure and seeded by its caller: tools/pacing.gd feeds
## real rampages; the tree suite feeds the data's income stand-in (model_income).

## One entry per visit: {"run", "stage", "income", "end_hours", "bought": Array[String]}.
var visits: Array[Dictionary] = []
## Play seconds so far (rampages plus tree_seconds a visit).
var clock := 0.0
## Seconds of play before the first purchase (-1 until one is made).
var first_buy_seconds := -1.0
## The hour each node's first level was bought.
var first_bought: Dictionary = {}
var _bank := 0
var _tree_seconds := 0.0


func _init(tree_seconds: float) -> void:
	_tree_seconds = tree_seconds


## A rampage of `seconds` paid `income`: bank it, then buy the cheapest affordable node until
## none is left. Returns the ids bought, in order.
func visit(tree: UpgradeTree, seconds: float, income: int) -> Array[String]:
	clock += seconds
	_bank += income
	var bought: Array[String] = []
	while true:
		var pick := cheapest(tree, _bank)
		if pick == "":
			break
		_bank -= tree.buy(pick, _bank)
		bought.append(pick)
		if first_buy_seconds < 0.0:
			first_buy_seconds = clock
		if tree.level(pick) == 1:
			first_bought[pick] = (clock + _tree_seconds) / 3600.0
	clock += _tree_seconds
	(
		visits
		. append(
			{
				"run": visits.size() + 1,
				"stage": tree.stage(),
				"income": income,
				"end_hours": clock / 3600.0,
				"bought": bought,
			}
		)
	)
	return bought


## The cheapest node the bank can buy now ("" when none).
static func cheapest(tree: UpgradeTree, bank: int) -> String:
	var best := ""
	var best_cost := bank + 1
	for id: String in tree.order:
		if tree.can_buy(id, bank) and tree.cost(id) < best_cost:
			best = id
			best_cost = tree.cost(id)
	return best


## The tree suite's stand-in for a rampage's pay (tuning "tree" "pacing" "income"): at each
## growth stage it moves from first to last as that stage's ring levels are bought.
static func model_income(tree: UpgradeTree, pacing: Dictionary) -> Array:
	var rows: Array = pacing["income"]
	var stage := mini(tree.stage(), rows.size())
	var row: Dictionary = rows[stage - 1]
	var owned := 0
	var total := 0
	for id: String in tree.order:
		var r := tree.ring(id)
		if r <= tree.rings.size() and Num.i(tree.rings[r - 1]["stage"]) == stage:
			owned += tree.level(id)
			total += tree.max_level(id)
	var share := float(owned) / float(maxi(1, total))
	var pay := lerpf(Num.f(row["first"]), Num.f(row["last"]), share)
	return [roundi(pay), Num.f(row["run_seconds"])]


## Every bar the visits so far miss inside the window, in words ([] when all pass).
func misses(tree: UpgradeTree, pacing: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var window := Num.f(pacing["window_hours"])
	var span: Array = pacing["buys_per_visit"]
	var gap_max := Num.i(pacing["max_runs_between_verbs"])
	var last_event := 0
	for v: Dictionary in visits:
		if Num.f(v["end_hours"]) > window:
			break
		var bought: Array[String] = v["bought"]
		var run := Num.i(v["run"])
		if bought.size() < Num.i(span[0]) or bought.size() > Num.i(span[1]):
			out.append("run %d bought %d (bar %d-%d)" % [run, bought.size(), span[0], span[1]])
		for id: String in bought:
			if tree.kind(id) != "stat" and _first_level(v, id):
				if run - last_event > gap_max:
					out.append("%d runs without a new verb before run %d" % [run - last_event, run])
				last_event = run
	var runs_in_window := _runs_within(window)
	if runs_in_window - last_event > gap_max:
		out.append("%d runs without a new verb at the window's end" % (runs_in_window - last_event))
	out.append_array(_evolve_misses(pacing))
	if first_buy_seconds < 0.0 or first_buy_seconds > Num.f(pacing["first_buy_seconds"]):
		out.append("first purchase at %.0f s" % first_buy_seconds)
	return out


func _evolve_misses(pacing: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var targets: Dictionary = pacing["evolve_hours"]
	var tol := Num.f(pacing["evolve_tolerance"])
	for id: String in targets:
		var want := Num.f(targets[id])
		var got := Num.f(first_bought.get(id, -1.0))
		if got < 0.0 or absf(got - want) > want * tol:
			out.append("%s at %.2f h (target %.2f h +/- %d%%)" % [id, got, want, roundi(tol * 100)])
	return out


## True when this visit bought `id`'s first level (it may buy several levels of it).
func _first_level(v: Dictionary, id: String) -> bool:
	return absf(Num.f(first_bought.get(id, -1.0)) - Num.f(v["end_hours"])) < 1e-9


func _runs_within(window: float) -> int:
	var n := 0
	for v: Dictionary in visits:
		if Num.f(v["end_hours"]) <= window:
			n = Num.i(v["run"])
	return n
