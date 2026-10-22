class_name TimeOfDay
extends RefCounted
## Which time of day a rampage plays (D-145, director 2026-10-22: "the time of day will be
## randomised each run (a toggle available in the options menu to set a fixed time if players
## prefer)", "random but cannot do the same time of day twice in a row"). The times are
## data/looks.json "times" "order"; the player's setting is "" (Random, the default) or one of
## them. A random pick draws from its own seeded stream by run number and leaves out the time
## the last run played, so a save replays the same sequence. Pure: no Node, no clock.

## The setting that means a random time.
const RANDOM := ""


## The time of day for run number `run_index`: `setting` when it names a time, else a seeded pick
## from the others than `last` (the last run's; "" or unknown leaves all of them in).
static func pick(run_index: int, last: String, setting: String) -> String:
	var all: Array = Content.times()
	if all.has(setting):
		return setting
	var pool: Array = all.filter(func(id: Variant) -> bool: return str(id) != last)
	if pool.is_empty():
		pool = all
	var rng := Seeds.make("time_of_day", run_index)
	return str(pool[rng.randi_range(0, pool.size() - 1)])


## The settings in the order the options button steps through: Random first, then each time.
static func settings() -> Array[String]:
	var out: Array[String] = [RANDOM]
	for id: Variant in Content.times():
		out.append(str(id))
	return out


## The setting after `setting` (wrapping); an unknown one counts as Random.
static func next(setting: String) -> String:
	var all := settings()
	return all[(maxi(all.find(setting), 0) + 1) % all.size()]


## What the options menu shows for `setting` (data/looks.json "times" labels).
static func label(setting: String) -> String:
	var times := Content.time_table()
	if setting == RANDOM or not Content.times().has(setting):
		return str(times["random_label"])
	var labels: Dictionary = times["labels"]
	return str(labels[setting])


## `setting` as the options file should keep it: a known time or Random.
static func clean(setting: String) -> String:
	return setting if Content.times().has(setting) else RANDOM
