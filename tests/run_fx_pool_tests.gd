extends "res://tests/lib/runner.gd"
## Pooled dust, sparks and fire systems (render plan item 8, tuning render_opt.fx_pool): after 100
## dust bursts the particle systems under Fx are the same nodes, none freed; the pool's slots,
## reset, exhaustion, flag-off and fire / blast give-back. Detail in tests/lib/fx_burst_nodes.gd
## and tests/lib/fx_pool_slots.gd. Headless; nothing here is random.

const Nodes := preload("res://tests/lib/fx_burst_nodes.gd")
const Slots := preload("res://tests/lib/fx_pool_slots.gd")


func suite_name() -> String:
	return "FxPool"


func run_checks() -> void:
	await _t("_check_burst_nodes")
	await _t("_check_pool_slots")


func _check_burst_nodes() -> void:
	await _h("100 dust bursts", func() -> void: await Nodes.new(check, self).run())


func _check_pool_slots() -> void:
	await _h("pool slots", func() -> void: await Slots.new(check, self).run())
