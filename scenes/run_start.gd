class_name RunStart
extends RefCounted
## What every rampage takes from the save as it starts, shared by main.gd and the globe's real
## cities (GlobeMissions) so a city launched from the globe starts as any run does.


## After Rampage.setup_later: the Taskforce's clock so far (D-160), then the time of day (D-145)
## and the weather (D-155), each seeded, never the last run's, unless the options fix one. The
## save remembers both (the caller writes it), even if the rampage is quit before it ends.
static func prepare(save: Dictionary, rampage: Rampage) -> void:
	var runs := Num.i(save.get("runs", 0))
	rampage.city_seconds = Num.f(save.get("city_seconds", 0.0))
	var time_id := TimeOfDay.pick(runs, str(save.get("last_time", "")), PlayerSettings.time_of_day)
	Content.set_time(time_id)
	save["last_time"] = time_id
	var weather_id := Weather.pick(runs, str(save.get("last_weather", "")), PlayerSettings.weather)
	Content.set_weather(weather_id)
	save["last_weather"] = weather_id


## The whole run intro on the first run and the first at a new size (a new body to show); the
## short cut otherwise (R 20.4). Set after the save is written, so it is saved with the result.
static func intro(save: Dictionary, rampage: Rampage, tier: int) -> void:
	rampage.full_intro = Num.i(save.get("intro_size", -1)) != tier
	save["intro_size"] = tier
