extends RefCounted
## The stopwatch of the sim-speed probe (tools/sim_profile.gd): named spans that nest. A span's
## inclusive time is everything between begin and end; its exclusive time leaves out the spans
## begun inside it, so the exclusive times of all spans add up to the whole step. A probe only:
## nothing in sim/ reads a clock (a clock in the sim is a bug).

## label -> microseconds, inclusive and exclusive; label -> calls.
static var inclusive: Dictionary = {}
static var exclusive: Dictionary = {}
static var calls: Dictionary = {}
## True to time the tanks' convoy down to its road graph, search, posts and spacing (--drill).
static var drill := false
## Open spans, innermost last: [label, start (us), microseconds its children took].
static var _open: Array = []


static func begin(label: String) -> void:
	_open.append([label, Time.get_ticks_usec(), 0])


static func end() -> void:
	var span: Array = _open.pop_back()
	var label: String = span[0]
	var took := Time.get_ticks_usec() - Num.i(span[1])
	inclusive[label] = Num.i(inclusive.get(label, 0)) + took
	exclusive[label] = Num.i(exclusive.get(label, 0)) + took - Num.i(span[2])
	calls[label] = Num.i(calls.get(label, 0)) + 1
	if not _open.is_empty():
		var parent: Array = _open.back()
		parent[2] = Num.i(parent[2]) + took


static func reset() -> void:
	inclusive.clear()
	exclusive.clear()
	calls.clear()
	_open.clear()
