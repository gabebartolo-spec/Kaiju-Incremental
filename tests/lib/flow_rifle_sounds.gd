extends RefCounted
## The flow suite's rooftop-rifle distance check (kept here so run_flow_tests.gd stays under its
## line cap): a volley far from the camera plays well under one close to it, and volleys closer
## together than tuning "sfx" "min_interval" "rifle" sound once.


static func check_distance(check: Callable, sfx: Sfx) -> void:
	var ear := sfx.listener.global_position
	var gap := Num.f(Content.tuning()["sfx"]["min_interval"]["rifle"])
	sfx._process(gap)  # the live rampage's own volleys may have a gap open: let it close first
	sfx.play_at("rifle", ear + Vector3(5, 0, 0))
	var near_db := sfx.last_volume()
	var before := sfx.played.count("rifle")  # Sfx._process may play other sounds meanwhile
	sfx.play_at("rifle", ear + Vector3(5, 0, 0))
	sfx._process(gap * 0.5)
	sfx.play_at("rifle", ear + Vector3(5, 0, 0))
	check.call(
		sfx.played.count("rifle") == before,
		(
			"volleys inside the rifle's %.2f s gap stay silent (%d played)"
			% [gap, sfx.played.count("rifle") - before]
		)
	)
	sfx._process(gap)
	sfx.play_at("rifle", ear + Vector3(600, 0, 0))
	check.call(
		sfx.last_volume() < near_db - 10.0,
		(
			"a far rooftop volley is quieter than a near one (%.1f vs %.1f dB)"
			% [sfx.last_volume(), near_db]
		)
	)
