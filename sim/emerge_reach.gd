class_name EmergeReach
extends RefCounted
## The biggest body that can rise from the sea bay at a stage (CityHarbour), and the bay fitted
## to hold it (director 2026-10-21, "Fit the biggest possible"). Every
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


## The biggest body scale (Growth.body_scale) any species reaches at this size tier.
static func biggest_scale(tuning: Dictionary, upgrades: Array[Dictionary], tier: int) -> float:
	var contact: Dictionary = tuning.get("contact", {})
	var bodies: Dictionary = contact.get("bodies", {})
	var city: Dictionary = tuning["city"]
	var out := 0.0
	for species_id: String in bodies:
		var stats := {"size": tier, "growth": max_growth(upgrades, species_id, tier)}
		out = maxf(out, Growth.body_scale(stats, city))
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


## Fits the city's "harbour" in `tuning` (a stage's, CityGrowth.tuning_for) to the biggest body:
## at least as wide as it plus "fit_margin" each side ("fit_width"), the sea floor at the rise
## its crouched back ("crouch_back" per body scale) plus "seabed_clear" under the surface
## ("seabed_depth"), and no painted stand-in within the game camera's ground reach of the rise
## ("view_clear").
static func fit(tuning: Dictionary, upgrades: Array[Dictionary], tier: int) -> void:
	var city: Dictionary = tuning.get("city", {})
	if not city.has("harbour"):
		return
	var bay: Dictionary = city["harbour"]
	var body := biggest(tuning, upgrades, tier)
	var scale := biggest_scale(tuning, upgrades, tier)
	bay["fit_width"] = ceilf(body.y + Num.f(bay["fit_margin"]) * 2.0)
	var crouch := Num.f(bay["crouch_back"]) * scale + Num.f(bay["seabed_clear"])
	bay["seabed_depth"] = maxf(Num.f(bay["seabed_depth"]), crouch)
	var cam: Dictionary = tuning.get("camera", {})
	var offset: Array = cam.get("offset", [0, 0, 0])
	var behind := absf(Num.f(offset[2]))
	bay["view_clear"] = ceilf((behind + Num.f(bay["view_margin"])) * scale)


## Whether a footprint (centre `at`, `size`) lies within the game camera's reach of where the
## kaiju rises or the bank point it wades to (city "harbour" "view_clear", set by fit): no
## painted stand-in stands there, only real buildings (CitySkyline; playtest 2026-10-19).
static func in_view(plan: Dictionary, city: Dictionary, at: Vector2, size: Vector2) -> bool:
	var bay: Dictionary = city.get("harbour", {})
	var clear := Num.f(bay.get("view_clear", 0.0))
	if clear <= 0.0 or not plan.has("rise_spawn"):
		return false
	var foot := Rect2(at - size * 0.5, size)
	for p: Vector2 in [plan["rise_spawn"], plan.get("rise_bank", plan["rise_spawn"])]:
		if p.clamp(foot.position, foot.end).distance_to(p) < clear:
			return true
	return false


## in_view for a lot (CityLots: a dictionary with x, z, w, d).
static func lot_in_view(plan: Dictionary, city: Dictionary, lot: Dictionary) -> bool:
	var at := Vector2(Num.f(lot["x"]), Num.f(lot["z"]))
	return in_view(plan, city, at, Vector2(Num.f(lot["w"]), Num.f(lot["d"])))
