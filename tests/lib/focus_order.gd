extends RefCounted
## The title checks' tab-order probe (split out of tests/lib/ui_title.gd to keep files small).


## Tab order: each button's focus_next is the next one in `order`, wrapping round.
static func run(check: Callable, title: Node, order: Array, label: String) -> void:
	var good := true
	for i: int in order.size():
		var here: Button = order[i]
		var next: Button = order[(i + 1) % order.size()]
		if here.get_node_or_null(here.focus_next) != next:
			good = false
	check.call(good, "focus order %s is Continue/New Kaiju, gear, exit (%s)" % [label, title.name])
