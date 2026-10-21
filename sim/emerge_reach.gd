class_name EmergeReach
extends RefCounted
## The biggest body that can rise from the river at a stage, and the bay sized to hold it
## (director 2026-10-21 #17: "the river where he emerges from can be slightly wider than the
## other sections of the river to accomodate him"; his pick: "Fit the biggest possible"). Every
## species' body at the stage's size tier (tuning "contact" "bodies"), at the most growth it can
## own at that size: every level of every upgrade at or below the tier, short of the evolution
## that leaves it (Growth.body_scale, UpgradeTree.tier_of). Pure: tuning and upgrades in.


## The longest and widest such body (x: snout to tail tip, y: across), world units.
static func biggest(tuning: Dictionary, upgrades: Array[Dictionary], tier: int) -> Vector2:
	var contact: Dictionary = tuning.get("contact", {})
	var bodies: Dictionary = contact.get("bodies", {})
	var out := Vector2.ZERO
	for species_id: String in bodies:
		var stages: Array = bodies[species_id]
		if stages.is_empty():
			continue
		var stage: Dictionary = stages[clampi(tier - 1, 0, stages.size() - 1)]
		var stats := {"size": tier, "growth": max_growth(upgrades, species_id, tier)}
		var city: Dictionary = tuning["city"]
		var s := Growth.body_scale(stats, city)
		var front := 0.0
		var back := 0.0
		var wide := 0.0
		for d: Array in stage["discs"]:
			front = maxf(front, Num.f(d[0]) + Num.f(d[1]))
			back = minf(back, Num.f(d[0]) - Num.f(d[1]))
			wide = maxf(wide, Num.f(d[1]) * 2.0)
		out = Vector2(maxf(out.x, (front - back) * s), maxf(out.y, wide * s))
	return out


## The most upgrade levels a kaiju of this species can own while at this size tier.
static func max_growth(upgrades: Array[Dictionary], species_id: String, tier: int) -> int:
	var tree := UpgradeTree.new(upgrades, {}, species_id)
	var levels := 0
	for id: String in tree.order:
		var t := tree.tier_of(id)
		var def: Dictionary = tree.defs[id]
		var effects: Dictionary = def.get("effects", {})
		if t < tier or (t == tier and not effects.has("size")):
			levels += tree.max_level(id)
	return levels


## Grows the city's "river_bay" in `tuning` (a stage's, CityGrowth.tuning_for) to hold the
## biggest body: deep enough from the channel's north edge for the shore, the nose gap, the
## body and "fit_margin"; long enough (x) for its width and the margin each side. Never smaller
## than the data's own depth and length.
static func fit(tuning: Dictionary, upgrades: Array[Dictionary], tier: int) -> void:
	var city: Dictionary = tuning.get("city", {})
	if not city.has("river_bay"):
		return
	var bay: Dictionary = city["river_bay"]
	var body := biggest(tuning, upgrades, tier)
	var margin := Num.f(bay.get("fit_margin", 0.0))
	var deep := Num.f(bay["beach"]) + Num.f(bay["nose_gap"]) + body.x + margin
	bay["depth"] = maxf(Num.f(bay["depth"]), ceilf(deep))
	bay["length"] = maxf(Num.f(bay["length"]), ceilf(body.y + margin * 2.0))
