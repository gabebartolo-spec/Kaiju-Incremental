extends SceneTree
## Comments #32/#33: the croc's neck through a dash and then a sharp turn, in the real rampage at
## the game camera. Saves a still every --every frames into --out (for 2x crops of the neck);
## with --write-movie the same run is the clip (~6 s). Render it on CI, never windowed here:
##   tools/capture/ci_capture.sh --movie --resolution=1280x720 capture_croc_neck.gd -- --stage=3
## --stage=1|2|3: baby, adolescent, adult (default 3).

const LEAD_IN := 40
const DASH_AT := 70
## Walk on after the dash, then swing the stick back and forth: a sharp turn each time.
const WALK_AFTER := 70
const TURN_SWAP := 36
const TURNS := 5
## Growth upgrades that make the adolescent and the adult (capture_growth.gd's levels).
const LEVELS: Array[Dictionary] = [
	{"claws": 2, "hide": 2},
	{"claws": 5, "hide": 5, "rage": 3, "evolve1": 1},
	{"claws": 5, "hide": 5, "rage": 5, "evolve1": 1, "tail": 3, "sig_power": 3, "evolve2": 1},
]

var _out := "user://croc_neck"
var _every := 6
var _stage := 3


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--every="):
			_every = arg.substr(8).to_int()
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS[_stage - 1], "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	var steps := [0]
	rampage.scripted = func(sim: RampageSim) -> Dictionary:
		var n: int = steps[0]
		steps[0] = n + 1
		var move := Vector2.ZERO
		if n >= LEAD_IN:
			move = sim.facing
		var since := n - (DASH_AT + WALK_AFTER)
		if since >= 0:  # alternate hard left and right turns
			var side := 1.0 if (since / TURN_SWAP) % 2 == 0 else -1.0
			move = sim.facing.rotated(side * 2.4)
		return {"move": move, "dash": n == DASH_AT}
	root.add_child(rampage)
	for child: Node in rampage.get_children():
		if child is BreathAim:
			child.queue_free()
	var total := DASH_AT + WALK_AFTER + TURN_SWAP * TURNS
	var frames := 0
	while frames < total and not rampage.sim.over:
		await physics_frame
		frames += 1
		if frames >= DASH_AT - 6 and frames % _every == 0:
			await process_frame
			root.get_texture().get_image().save_png("%s/neck_%04d.png" % [_out, frames])
	rampage.queue_free()
	await process_frame
	quit()
