extends "res://tests/lib/runner.gd"
## Carved debris bookkeeping (render plan item 1): the cached, draw-on-tick path draws exactly what
## the old per-frame path drew. Detail in tests/lib/carve_debris_cache.gd.
## Seeded by design: the helper pins its throw seed.

const Cache := preload("res://tests/lib/carve_debris_cache.gd")


func suite_name() -> String:
	return "CarveDebris"


func run_checks() -> void:
	await _t("_check_cache")


func _check_cache() -> void:
	await _h("debris cache", func() -> void: await Cache.new(check, self).run())
