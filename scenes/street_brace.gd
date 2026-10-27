class_name StreetBrace
extends RefCounted
## Which of StreetLife's people a falling building section pins in place, so its landing crushes
## them. Split out of StreetLife to keep files small; presentation only.


## The people of `street` under a section that starts to fall (a fall_start event) freeze there;
## its landing (CityView) crushes the same reach: a topple's strip, or a drop's walls plus
## drop_reach.
static func fall(street: StreetLife, event: Dictionary, drop_reach: float) -> void:
	var b := street.sim.buildings[Num.i(event["building"])]
	var cells: Array = event["cells"]
	if cells.is_empty():  # a carved scrap smashes nothing
		return
	var seconds := Num.f(event["duration"])
	var spill := street.tune("fall_spill")
	if str(event["kind"]) == "topple" and event.has("to"):
		var pivot: Vector3 = event["pivot"]
		var to: Vector2 = event["to"]
		var from := Vector2(pivot.x, pivot.z)
		street.brace(from, to, Num.f(event["width"]) * 0.6 + spill, seconds)
	elif b.landmark == "":
		var at := Vector2(b.x, b.z)
		street.brace(at, at, maxf(b.w, b.d) * 0.5 + drop_reach + spill, seconds)
