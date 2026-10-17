extends RefCounted
## The flow suite's rooftop-rifle distance check (kept here so run_flow_tests.gd stays under its
## line cap): a volley far from the camera plays well under one close to it.


static func check_distance(check: Callable, sfx: Sfx) -> void:
	var ear := sfx.listener.global_position
	sfx.play_at("rifle", ear + Vector3(5, 0, 0))
	var near_db := sfx.last_volume()
	sfx.play_at("rifle", ear + Vector3(600, 0, 0))
	check.call(
		sfx.last_volume() < near_db - 10.0,
		(
			"a far rooftop volley is quieter than a near one (%.1f vs %.1f dB)"
			% [sfx.last_volume(), near_db]
		)
	)
