extends RefCounted
## The UI suite's title-haze check (D-441; director 2026-11-02, the title's roof fires floated over
## the left district: "Thin the haze"): the title's far shore takes the city's far_fog with the
## title's keys over it, so its far towers are out of the engine's depth fog and their windows show
## under the fires. The city's own far_fog (the play area, unchanged) does fog them, so it can fail.

var check: Callable


func _init(p_check: Callable) -> void:
	check = p_check


func run() -> void:
	var city: Dictionary = Content.tuning()["city"]["far_fog"]
	var title: Dictionary = Content.section("title")["far_fog"]
	var play := FarHaze.new(city)
	play.apply_default()
	check.call(play.fogged, "the play area's far city takes the engine's depth fog")
	var shore := FarHaze.new(TitleBackdrop.far_fog(city, title))
	shore.apply_default()
	check.call(not shore.fogged, "the title's far shore is out of the depth fog (its towers show)")
