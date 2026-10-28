extends "res://tests/lib/runner.gd"
## The countable bars of the night speed runs (D-351), on every PR: the pinned adult-city route
## replayed headless, what it counts and the bars that hold on the count. Detail in
## tests/lib/counts_route.gd. Headless; nothing here is random.

const Route := preload("res://tests/lib/counts_route.gd")


func suite_name() -> String:
	return "Counts"


func run_checks() -> void:
	await _t("_check_route_counts")


func _check_route_counts() -> void:
	await _h("pinned route counts", func() -> void: await Route.new(check, self).run())
