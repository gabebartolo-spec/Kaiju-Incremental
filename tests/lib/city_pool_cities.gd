extends RefCounted
## The sampled cities the pool suite measures (D-256 bars): 3 stages x SEEDS city seeds, built by
## CityGrowth.layout as a run builds them, with the street plan each stands on. Seeded by design.

const SEEDS := 20

## One per city: {"stage", "seed", "layout": Array[Dictionary], "plan", "cfg"}.
var cities: Array[Dictionary] = []


## seeds: city seeds per stage (SEEDS unless fewer are asked for).
func _init(pool_on: bool = true, seeds: int = SEEDS) -> void:
	var tuning := Content.tuning()
	for stage: int in range(1, CityGrowth.stage_count(tuning) + 1):
		var stage_tuning := CityGrowth.tuning_for(tuning, stage)
		var cfg: Dictionary = stage_tuning["city"]
		if not pool_on:
			cfg = cfg.duplicate()
			var shared_book: Dictionary = cfg["building_pool"]
			var book := shared_book.duplicate()
			var shared_pl: Dictionary = book["placement"]
			var pl := shared_pl.duplicate()
			pl["on"] = false
			book["placement"] = pl
			cfg["building_pool"] = book
		var plan := CityGen.map(cfg)
		for s: int in seeds:
			var layout := CityGen.generate(Seeds.make("city", s), cfg)
			cities.append({"stage": stage, "seed": s, "layout": layout, "plan": plan, "cfg": cfg})


## Pool entries of a layout.
static func pooled(layout: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout:
		if e.has("model"):
			out.append(e)
	return out


## The variant key that makes two copies look the same: model, facing, mirror, stretch, palette.
static func look_key(e: Dictionary) -> String:
	return (
		"%s|%d|%s|%d|%d"
		% [e["model"], Num.i(e["facing"]), e["mirror"], Num.i(e["stretch"]), Num.i(e["palette"])]
	)
