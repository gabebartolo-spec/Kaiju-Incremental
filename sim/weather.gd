class_name Weather
extends RefCounted
## Which weather a rampage plays (D-155, ROADMAP M1). Mirrors TimeOfDay: the weathers are
## data/looks.json "weather" "order"; the player's setting is "" (Random, the default) or one of
## them. A random pick draws from its own seeded stream by run number and leaves out the weather
## the last run played, so a save replays the same sequence. Pure: no Node, no clock.
## The pick is the run's one current weather, Content.weather_id() (set by Main when a rampage
## starts); the sim only picks and remembers it, the view decides how it looks.

## The setting that means a random weather.
const RANDOM := ""


## The weather for run number `run_index`: `setting` when it names one, else a seeded pick from
## the others than `last` (the last run's; "" or unknown leaves all of them in).
static func pick(run_index: int, last: String, setting: String) -> String:
	var all: Array = Content.weathers()
	if all.has(setting):
		return setting
	var pool: Array = all.filter(func(id: Variant) -> bool: return str(id) != last)
	if pool.is_empty():
		pool = all
	var rng := Seeds.make("weather", run_index)
	return str(pool[rng.randi_range(0, pool.size() - 1)])


## The settings in the order the options button steps through: Random first, then each weather.
static func settings() -> Array[String]:
	var out: Array[String] = [RANDOM]
	for id: Variant in Content.weathers():
		out.append(str(id))
	return out


## The setting after `setting` (wrapping); an unknown one counts as Random.
static func next(setting: String) -> String:
	var all := settings()
	return all[(maxi(all.find(setting), 0) + 1) % all.size()]


## What the options menu shows for `setting` (data/looks.json "weather" labels).
static func label(setting: String) -> String:
	var table := Content.weather_table()
	if setting == RANDOM or not Content.weathers().has(setting):
		return str(table["random_label"])
	var labels: Dictionary = table["labels"]
	return str(labels[setting])


## `setting` as the options file should keep it: a known weather or Random.
static func clean(setting: String) -> String:
	return setting if Content.weathers().has(setting) else RANDOM
