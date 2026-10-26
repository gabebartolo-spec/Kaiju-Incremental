class_name RampageNews
extends Control
## The news crawl during a rampage (D-259, "On big events"): when the sim reports a big moment
## (RunNews: the threat level rose, a landmark fell, a tower total; the VIP helicopter's events),
## the emergency-broadcast crawl (NewsTicker) slides up along the bottom edge, runs the headline
## past once and slides away. Moments that come while it is up wait their turn, at most tuning
## "ui" news_live queue of them. Lines are data (tuning "news" live). Presentation only.

var sim: RampageSim
## The crawl on screen (null while none is).
var ticker: NewsTicker
## Every headline shown this rampage, in order (read by the suites and captures).
var shown: PackedStringArray = []
## Set for the end beat: no more crawl this rampage.
var muted := false
var _cfg: Dictionary
var _queue: PackedStringArray = []
var _left := 0.0
## The last crawl is still sliding away for this long (s): the next waits for it.
var _leaving := 0.0
var _read: Array[Dictionary] = []


func _init(p_sim: RampageSim) -> void:
	sim = p_sim
	_cfg = UiKit.ui()["news_live"]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -NewsTicker.HEIGHT
	visible = false  # only while a crawl is up: the strip runs edge to edge, past the safe area


## The crawl's line for a sim event, or "" when the event is not news.
static func line_for(event: Dictionary) -> String:
	var live: Dictionary = Content.section("news")["live"]
	var kind := str(event.get("type", ""))
	match kind:
		"threat_up":
			var levels: Dictionary = live["threat"]
			return str(levels.get(str(Num.i(event["level"])), ""))
		"landmark_felled":
			var lines: Dictionary = live["landmarks"]
			return str(lines.get(str(event["landmark"]), lines["landmark"]))
		"towers_toppled":
			return str(live["towers"]).replace("{n}", str(Num.i(event["count"])))
	var vip: Dictionary = live["vip"]
	return str(vip.get(kind, ""))


## Queues the news in this step's sim events (each step's list is read once).
func _physics_process(_delta: float) -> void:
	var events := sim.events
	if is_same(events, _read):
		return
	_read = events
	for event: Dictionary in events:
		add(line_for(event))


## Queues `line` for the crawl ("" is ignored); the oldest waiting line drops past the cap.
func add(line: String) -> void:
	if line == "":
		return
	_queue.append(line)
	while _queue.size() > Num.i(_cfg["queue"]):
		_queue.remove_at(0)


func _process(delta: float) -> void:
	visible = not muted and (ticker != null or _leaving > 0.0)
	if muted:
		return
	if ticker != null:
		_left -= delta
		if _left <= 0.0:
			_slide_out()
	elif _leaving > 0.0:
		_leaving -= delta
	elif not _queue.is_empty():
		_slide_in(_queue[0])
		_queue.remove_at(0)
		visible = true


## The lines waiting for the crawl, oldest first.
func waiting() -> PackedStringArray:
	return _queue.duplicate()


## True while a crawl is up.
func showing() -> bool:
	return ticker != null


func _slide_in(line: String) -> void:
	shown.append(line)
	ticker = NewsTicker.new(PackedStringArray([line]))
	ticker.once = true
	ticker.size = Vector2(size.x, NewsTicker.HEIGHT)
	ticker.position = Vector2(0.0, NewsTicker.HEIGHT)
	add_child(ticker)
	ticker.size.x = size.x
	# Up long enough for the headline to cross behind the tag, plus a moment to read it.
	var crawl := ticker.headlines_width() / NewsTicker.SPEED
	_left = maxf(Num.f(_cfg["min_s"]), crawl + Num.f(_cfg["read_s"]))
	create_tween().tween_property(ticker, "position:y", 0.0, Num.f(_cfg["slide_s"]))


func _slide_out() -> void:
	var going := ticker
	ticker = null
	_leaving = Num.f(_cfg["slide_s"])
	var tween := create_tween()
	tween.tween_property(going, "position:y", NewsTicker.HEIGHT, Num.f(_cfg["slide_s"]))
	tween.tween_callback(going.queue_free)
