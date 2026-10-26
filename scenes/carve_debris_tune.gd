class_name CarveDebrisTune
extends RefCounted
## The tuning (carve_physics) that a debris tick reads for every piece, read once.

var rest_v := 0.0
var rest_w := 0.0
var rest_t := 0.0
var fade_t := 1.0
var ground := 0.0
var slop := 0.0
var indoor_t := 0.0
var indoor_m := 0.0
var drag := 0.0


static func read(cfg: Dictionary) -> CarveDebrisTune:
	var t := CarveDebrisTune.new()
	t.rest_v = Num.f(cfg["settle_speed"])
	t.rest_w = Num.f(cfg["settle_spin"])
	t.rest_t = Num.f(cfg["settle_seconds"])
	t.fade_t = Num.f(cfg["fade_seconds"])
	t.ground = Num.f(cfg["ground_y"])
	t.slop = Num.f(cfg["ground_slop"])
	t.indoor_t = Num.f(cfg["indoor_seconds"])
	t.indoor_m = Num.f(cfg["indoor_margin"])
	t.drag = Num.f(cfg["ground_drag"])
	return t
