extends "res://tests/lib/leap_base.gd"
## The croc's leap in the seeded city (Seeds.make("city", 0)): it never lands on a roof above his
## shoulder (D-361, D-449). Seeded by design: every sim is Seeds.make("army", 0).


func suite_name() -> String:
	return "LeapCity"


func run_checks() -> void:
	await _t("_check_city_no_tall_tops")


## Regression (director 2026-11-03, "the kaiju can leap onto the roofs of extremely tall
## buildings"): at every growth stage, in the seeded city, from a take-off short of each standing
## building taller than his shoulder (4 headings), no leap aims to land higher than his shoulder;
## and the first such take-off, pressed for real, plans its arc to land no higher either.
func _check_city_no_tall_tops() -> void:
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	var dirs: Array[Vector2] = [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]
	for stage: String in STAGES:
		var levels: Dictionary = STAGES[stage]
		var sim := _croc(levels, layout)
		var shoulder := sim.body.dash.shoulder_y()
		var reach := Num.f(_stage(sim)["reach"]) * sim.body_scale()
		var tried := 0
		var worst := 0.0
		var worst_at := ""
		var first := Vector4.INF
		for i: int in sim.buildings.size():
			var b := sim.buildings[i]
			if not b.in_arena or float(b.height) <= shoulder:
				continue
			for dir: Vector2 in dirs:
				var at := Vector2(b.x, b.z) - dir * (sim.body.feet_ahead() + 0.6 * reach)
				if sim.clamp_to_arena(at) != at:
					continue
				tried += 1
				var roof := Num.f(sim.body.dash.aim_at(at, dir)["roof"])
				if first == Vector4.INF:
					first = Vector4(at.x, at.y, dir.x, dir.y)
				if roof > worst:
					worst = roof
					worst_at = "building %d (h%d) from %s" % [i, b.height, at]
		var pressed := -1.0
		if first != Vector4.INF:
			var run := _croc(levels, layout)
			run.kaiju_pos = Vector2(first.x, first.y)
			run.facing = Vector2(first.z, first.w)
			run.body.heading = run.facing
			run.step(DT, Vector2.ZERO, false, BUTTON)
			pressed = run.body.dash.arc.land_y if run.body.dash.on() else 0.0
		check(
			tried > 0 and worst <= shoulder and pressed >= 0.0 and pressed <= shoulder,
			(
				"%s: %d take-offs at tall towers, highest landing %.2f (pressed %.2f), shoulder %.2f %s"
				% [stage, tried, worst, pressed, shoulder, worst_at]
			)
		)
