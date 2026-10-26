extends SceneTree
## His death from the game camera (DeathOverload, director 2026-10-26): a seeded day rampage (city
## seed 0) with the croc at --stage (baby, adolescent, adult; default adult) and --nodes Death
## Blast nodes (0-3, the stat set directly). He rises, walks --walk seconds into the city, then dies
## (killed); the movie runs --seconds past that. It prints "film from frame N": the movie's frames
## before N are the rise and the walk; cut there. Record with Godot's --write-movie. A 4K movie
## needs the untracked off-screen override.cfg to make the window borderless at 3840x2160
## (window/size/borderless, window_width_override, window_height_override): a bordered window is
## clamped to the screen and the movie comes out 1920x1080.
## --key presses a key a second into the rise (before "film from"), as a player would, so the
## first-run Controls card is gone from the clip.
## --measure=<dir> instead of a clip: measures his stone (DeathMeasure). The mean luminance of the
## stone body just before the shatter against that of his flying debris and shards, the pixels of
## each picked by painting it unshaded magenta in the same paused frame; prints the ratios and
## saves the frames to <dir>. Needs a window (and the no_focus override.cfg).
##
##   godot --path . --windowed --fixed-fps 30 --write-movie <dir>/death.avi \
##     --script tools/capture/capture_death.gd -- --nodes=3 --seconds=6.5 --key

const DeathMeasure := preload("res://tools/capture/death_measure.gd")
const STAGES := {
	"baby": {},
	"adolescent": {"claws": 1, "hide": 1, "rage": 1, "evolve1": 1},
	"adult":
	{
		"claws": 1,
		"hide": 1,
		"rage": 1,
		"evolve1": 1,
		"sig_power": 1,
		"tail": 1,
		"titan_hide": 1,
		"evolve2": 1,
	},
}
## Seconds of the walk filmed before he dies, so the clip opens on him alive.
const LEAD_IN := 0.5
## Seconds into the rise when --key presses its key (the card ignores a key before 0.6 s).
const KEY_AT := 1.0

var _nodes := 0
var _stage := "adult"
var _walk := 2.5
var _seconds := 6.5
var _time := "noon"
var _key := false
var _measure := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--nodes="):
			_nodes = clampi(arg.substr(8).to_int(), 0, 3)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8)
		elif arg.begins_with("--walk="):
			_walk = arg.substr(7).to_float()
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg == "--key":
			_key = true
		elif arg.begins_with("--measure="):
			_measure = arg.substr(10)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Content.set_time(_time)
	var species := Content.species_def("reptilian")
	var levels: Dictionary = STAGES.get(_stage, {})
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["death_blast"] = _nodes
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, Content.times().find(_time))
	var walking := [true]
	rampage.scripted = func(_sim: RampageSim) -> Dictionary:
		return {"move": Vector2(0, -1) if walking[0] else Vector2.ZERO}
	root.add_child(rampage)
	await physics_frame
	var sim := rampage.sim
	var ticks := 0
	while sim.emerge.active:
		sim.hp = sim.max_hp
		ticks += 1
		if _key and ticks == roundi(KEY_AT * Engine.physics_ticks_per_second):
			_press_key()
		await physics_frame
	var walked := 0.0
	while walked < _walk:
		sim.hp = sim.max_hp
		walked += 1.0 / Engine.physics_ticks_per_second
		await physics_frame
	var lead := roundi(LEAD_IN * Engine.max_fps) if Engine.max_fps > 0 else 15
	print("film from frame %d" % maxi(0, Engine.get_frames_drawn() - lead))
	walking[0] = false
	sim.hp = -sim.max_hp
	if _measure != "":
		await DeathMeasure.new(self, rampage, _measure).run()
		quit()
		return
	var t := 0.0
	while t < _seconds:
		t += 1.0 / Engine.physics_ticks_per_second
		await physics_frame
	print(
		(
			"died: nodes %d, blast %.1f, shards %d, chunks shards %d blast %d, over %s (%s)"
			% [
				_nodes,
				sim.death.blast_radius,
				sim.death.shards.size(),
				sim.death.shard_chunks,
				sim.death.blast_chunks,
				sim.over,
				sim.end_reason,
			]
		)
	)
	quit()


## A player's key press (and release): the first-run Controls card goes.
func _press_key() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
