extends RefCounted
## LANDMARK CLEARANCE audit (D-265 city audits; the director 2026-10-26 on a stage-3 overhead):
## every landmark's plaza (its site inside the kerbs, CitySites: the baked footprint and its
## margin) stays clear of every street's carriageway the plan lays (on main before the road
## geometry fix, 7 of 20 stage-1 cities had a plaza over an avenue's stub end). The railway
## through a plaza is the rail loop task's (it reroutes the line), not checked here. Pure, from
## the plan alone.

const STEP := 0.5  # m between the points tested along a street
const TOUCH := 0.01  # a plaza runs out to the kerb: touching it is no overlap


## One line per overlap ("<id> plaza ... on the <kind> ..."), none when every plaza is clear.
## city: a stage's city config (CityGrowth.tuning_for(...)["city"]).
static func violations(city: Dictionary) -> Array[String]:
	return of_plan(CityGen.map(city))


## violations on a given plan (a test plants a site in it).
static func of_plan(plan: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var sites: Array = plan.get("sites", [])
	var nodes: Array[Vector2] = plan["nodes"]
	for site: Dictionary in sites:
		var rect: Rect2 = site["rect"]
		var inner := rect.grow(-TOUCH)
		for street: Dictionary in plan["streets"]:
			var a := nodes[Num.i(street["from"])]
			var b := nodes[Num.i(street["to"])]
			if _gap(inner, a, b) < Num.f(street["width"]) * 0.5:
				out.append("%s plaza %s on the %s %s-%s" % [site["id"], rect, street["kind"], a, b])
	return out


## The least distance from segment a-b to rect (0 where it enters it), sampled every STEP.
static func _gap(rect: Rect2, a: Vector2, b: Vector2) -> float:
	var n := maxi(1, ceili(a.distance_to(b) / STEP))
	var best := INF
	for k: int in n + 1:
		var p := a.lerp(b, float(k) / n)
		best = minf(best, p.clamp(rect.position, rect.end).distance_to(p))
	return best
