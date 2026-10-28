class_name SfxVoices
extends RefCounted
## The Sfx pool's voice manager (R 8.2, research 08-soundscape finding 4): a fixed set of players
## shared by every rampage one-shot, with a voice cap per category from tuning "sfx" "voice_caps".
## Hero categories (the roar, stomps, a toppled tower, an explosion's core) are never stolen by
## another category: a hero over its own cap takes its own oldest voice once that has played
## "hero_cut_after_s" (D-367, "Newest cuts oldest"), else it is dropped, and "reserve_hero"
## voices stay free for heroes whatever the rest of the city is doing. Any other sound over its
## cap, or over the non-hero share of the pool, takes the quietest voice (its dB has the
## distance fade in it, so the quietest is also the farthest; ties go to the oldest) if it is at
## least as loud, else it is dropped. The same sound in the same category is not restarted within
## its "retrigger_ms". Time is the frames' own delta (advance), never the clock, so a replay drops
## the same sounds. Presentation only.

var players: Array[AudioStreamPlayer] = []
## Plays dropped and voices stolen so far, how many hero voices another category ever stole
## (always 0), and how many a hero cut in its own category (newest cuts oldest).
var dropped := 0
var stolen := 0
var heroes_stolen := 0
var heroes_cut := 0
## The most voices each category has held at once, and the most the whole pool has.
var peak: Dictionary = {}
var peak_total := 0
var _cfg: Dictionary
var _now := 0.0
var _category: Array[String] = []
var _until: Array[float] = []
var _db: Array[float] = []
var _start: Array[float] = []
var _last_start: Dictionary = {}  # "category:sound" -> when it last started


## count players (tuning "sfx" "voices") under parent on bus "SFX" until a play sets theirs.
func _init(parent: Node, count: int, cfg: Dictionary) -> void:
	_cfg = cfg
	for _i: int in count:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		parent.add_child(player)
		players.append(player)
		_category.append("")
		_until.append(-INF)
		_db.append(-INF)
		_start.append(-INF)


## The frame's delta: voices whose sound has ended free up.
func advance(delta: float) -> void:
	_now += delta


## The category a sound plays in (voice_caps "sounds"), else voice_caps "default".
func category_of(sound: String) -> String:
	var sounds: Dictionary = _cfg["sounds"]
	return str(sounds.get(sound, _cfg["default"]))


func is_hero(category: String) -> bool:
	return _spec(category).get("hero", false) == true


func cap(category: String) -> int:
	return Num.i(_spec(category)["cap"])


## How many voices `category` holds now ("" counts every busy voice).
func busy_in(category: String) -> int:
	var n := 0
	for i: int in players.size():
		if _busy(i) and (category == "" or _category[i] == category):
			n += 1
	return n


## A voice for `sound` in `category` at db (its level with the distance fade) lasting `seconds`,
## or null when the sound is dropped. The caller sets the stream, bus and pitch, then plays.
func take(sound: String, category: String, db: float, seconds: float) -> AudioStreamPlayer:
	var key := "%s:%s" % [category, sound]
	var gap := Num.f(_spec(category).get("retrigger_ms", _cfg["retrigger_ms"])) * 0.001
	if _now - Num.f(_last_start.get(key, -INF)) < gap:
		dropped += 1
		return null
	var at := _pick(category, db)
	if at < 0:
		dropped += 1
		return null
	if _busy(at) and _category[at] == category and is_hero(category):
		heroes_cut += 1
	elif _busy(at):
		stolen += 1
		if is_hero(_category[at]):
			heroes_stolen += 1
	_last_start[key] = _now
	_category[at] = category
	_until[at] = _now + maxf(seconds, 0.0)
	_db[at] = db
	_start[at] = _now
	var held := busy_in(category)
	peak[category] = maxi(Num.i(peak.get(category, 0)), held)
	peak_total = maxi(peak_total, busy_in(""))
	return players[at]


func _pick(category: String, db: float) -> int:
	var hero := is_hero(category)
	if busy_in(category) >= cap(category):
		return _oldest_own(category) if hero else _quieter(db, category)
	if not hero:
		var share := players.size() - Num.i(_cfg["reserve_hero"])
		if _busy_others() >= share:
			return _quieter(db, "")
	for i: int in players.size():
		if not _busy(i):
			return i
	return _quieter(INF if hero else db, "")


## The oldest busy voice of hero `category` that has played "hero_cut_after_s", else -1.
func _oldest_own(category: String) -> int:
	var best := -1
	var after := Num.f(_cfg["hero_cut_after_s"])
	for i: int in players.size():
		if _busy(i) and _category[i] == category and _now - _start[i] >= after:
			if best < 0 or _start[i] < _start[best]:
				best = i
	return best


## The quietest busy non-hero voice (in `category`, or any with ""), oldest first on a tie, if
## a play at db is at least as loud; else -1.
func _quieter(db: float, category: String) -> int:
	var best := -1
	for i: int in players.size():
		if not _busy(i) or is_hero(_category[i]):
			continue
		if category != "" and _category[i] != category:
			continue
		if best < 0 or _db[i] < _db[best] or (_db[i] == _db[best] and _start[i] < _start[best]):
			best = i
	return best if best >= 0 and db >= _db[best] else -1


func _busy_others() -> int:
	var n := 0
	for i: int in players.size():
		if _busy(i) and not is_hero(_category[i]):
			n += 1
	return n


func _busy(i: int) -> bool:
	return _now < _until[i]


func _spec(category: String) -> Dictionary:
	var categories: Dictionary = _cfg["categories"]
	return categories[category]
