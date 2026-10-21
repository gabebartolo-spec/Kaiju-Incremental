extends RefCounted
## The flow suite's voice check (kept here so run_flow_tests.gd stays under its line cap): a
## stomp keeps sounding while a burst of other sounds plays after it, instead of losing its
## tail to a voice reused too soon (tuning "sfx" "voices").

const BURST := 12  # more plays than the old 8-voice pool held
const LANDINGS := 200  # a heavy collapse: building parts landing in one second
const BURST_FRAMES := 60


static func check_tail(check: Callable, sfx: Sfx) -> void:
	sfx.play("stomp_2")
	for i: int in BURST:
		sfx.play("shell_hit" if i % 2 == 0 else "tank_fire")
	check.call(
		sfx.sounding("stomp_2") > 0,
		(
			"a stomp keeps its tail through %d more plays (%d voices)"
			% [BURST, Num.i(Content.tuning()["sfx"]["voices"])]
		)
	)


## A heavy collapse (R 8.2): 200 building parts landing over one second never hold more voices
## than the collapse and debris caps (tuning "sfx" "voice_caps"), and never cut the roar or the
## stomp already sounding: hero voices are not stolen. The old round-robin pool failed both
## (every voice went to rubble and the roar's player was reused within a frame).
static func check_burst(check: Callable, root: Node) -> void:
	var sfx := Sfx.new(Seeds.make("sfx", 0))
	root.add_child(sfx)
	sfx.live = true
	sfx.play("roar")
	sfx.play("stomp_2")
	var tune: Dictionary = Content.section("sfx")
	var spec: Dictionary = tune.get("voice_caps", {"categories": {}})
	var caps: Dictionary = spec["categories"]
	var topple: Dictionary = caps.get("collapse", {"cap": 3})
	var debris: Dictionary = caps.get("debris", {"cap": 6})
	var cap := Num.i(topple["cap"]) + Num.i(debris["cap"])
	var most := 0
	var landed := 0
	for frame: int in BURST_FRAMES:
		while landed < roundi(float(LANDINGS * (frame + 1)) / BURST_FRAMES):
			sfx.collapse(landed % 3 == 0)
			landed += 1
		sfx._process(1.0 / BURST_FRAMES)
		most = maxi(most, sfx.sounding("collapse"))
	var raw: Variant = sfx.get_indexed(^"voices:heroes_stolen")  # null on the old pool
	var stolen := -1 if raw == null else Num.i(raw)
	check.call(
		most > 0 and most <= cap and sfx.sounding("roar") > 0 and sfx.sounding("stomp_2") > 0,
		(
			(
				"%d landings in a second hold at most %d collapse voices (%d), roar and stomp still"
				+ " sounding (%d, %d), %d hero voices stolen"
			)
			% [landed, cap, most, sfx.sounding("roar"), sfx.sounding("stomp_2"), stolen]
		)
	)
	check.call(stolen == 0, "no hero voice is ever stolen (%d)" % stolen)
	sfx.free()
