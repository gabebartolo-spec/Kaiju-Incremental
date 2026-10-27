extends "res://tests/lib/runner.gd"
## Carved debris bookkeeping (render plan item 1): the cached, draw-on-tick path draws exactly what
## the old per-frame path drew. Detail in tests/lib/carve_debris_cache.gd.
## And render plan item 11 (tests/lib/island_mesh_check.gd): a falling island draws as one merged
## mesh and patch, exactly a fresh mesh's faces after every drop, its boxes the old ones.
## Seeded by design: the helpers pin their seeds.

const Cache := preload("res://tests/lib/carve_debris_cache.gd")
const Islands := preload("res://tests/lib/island_mesh_check.gd")


func suite_name() -> String:
	return "CarveDebris"


func run_checks() -> void:
	await _t("_check_cache")
	await _t("_check_islands")


func _check_cache() -> void:
	await _h("debris cache", func() -> void: await Cache.new(check, self).run())


func _check_islands() -> void:
	await _h("merged islands", func() -> void: await Islands.new(check, self).run())
