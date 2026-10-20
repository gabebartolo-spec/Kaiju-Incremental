extends SceneTree
## The stadium crowd when its stands go (director, playtest comments #17 and b2-8): a camera in
## the bowl looking at the east stand; the AFL match plays, then one section of the stand is lost
## (as a foot would take it), and two more as the fans run, so fans fall with their stand, run
## over gaps and thin out over many seconds. Prints, every second, how many fans are in view,
## running, falling or lying, and how many were seen standing on a lost stand that frame.
## Needs a window and the no-focus override.cfg. With --write-movie the run is the clip.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_crowd_fall.gd -- --out=<dir> [--hold=<frames>]

const GuiInput := preload("res://tests/lib/gui_input.gd")
const PLAY := 150
## Frames after the first section goes that the next two do.
const SECOND_AT := 240
const THIRD_AT := 480
const FRAMES := 1200
const HUGE := 1.0e9
## Where the camera looks: the east stand, from the pitch (offsets from the stadium's middle).
const LOOK := Vector3(11.0, 3.0, 0.0)
const EYE := Vector3(-6.0, 9.0, 8.0)

var _out := "user://crowd_fall"
var _stadium: RampageSim.Building
var _index := 0
var _sim: RampageSim


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	StadiumMatch.force_sport = "afl"
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	var sim := rampage.sim
	_sim = sim
	for i: int in sim.buildings.size():
		if sim.buildings[i].landmark == str(Content.sports()["pitch"]["landmark"]):
			_stadium = sim.buildings[i]
			_index = i
	# The kaiju stays far off: only the stands are lost.
	sim.kaiju_pos = Vector2(_stadium.x, _stadium.z + 60.0)
	rampage.scripted = func(_s: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	root.add_child(rampage)
	var crowd: StadiumCrowd = GuiInput.find_script(rampage, StadiumCrowd)
	var middle := Vector3(_stadium.x, Num.f(Content.sports()["pitch"]["top"]), _stadium.z)
	var camera := Camera3D.new()
	camera.fov = 60.0
	rampage.add_child(camera)
	camera.position = middle + EYE
	camera.look_at(middle + LOOK)
	camera.make_current()
	var lost := -1
	for i: int in FRAMES:
		await physics_frame
		if i == PLAY:
			lost = i
			_lose(crowd, 0.0)
		elif lost >= 0 and i == lost + SECOND_AT:
			_lose(crowd, -0.35)
		elif lost >= 0 and i == lost + THIRD_AT:
			_lose(crowd, 0.35)
		if i % 60 == 0 or i == PLAY + 1:
			print(
				(
					"%4.1fs: in view %d, running %d, falling or lying %d; out %d, fell %d, crushed %d"
					% [
						i / 60.0,
						crowd.in_stands(),
						crowd.running(),
						crowd.dying(),
						crowd.escaped,
						crowd.fallen,
						crowd.killed
					]
				)
			)
		if i % 30 == 0:
			_shot("f%04d" % i)
	StadiumMatch.force_sport = ""
	quit()


## The stand seat nearest the east stand at `turn` radians round the bowl from it, lost for good.
func _lose(crowd: StadiumCrowd, turn: float) -> void:
	var middle := Vector3(_stadium.x, 0.0, _stadium.z)
	var want := middle + LOOK.rotated(Vector3.UP, turn)
	var best: StadiumCrowd.Fan = null
	for fan: StadiumCrowd.Fan in crowd.fans:
		if fan.is_dead() or fan.pos.y < 3.0:
			continue
		if best == null or fan.pos.distance_to(want) < best.pos.distance_to(want):
			best = fan
	var v := BuildingVoxels.VOXEL
	var corner := Vector2(_stadium.x - _stadium.w * 0.5, _stadium.z - _stadium.d * 0.5)
	var chunk := Vector3i(
		floori(best.pos.x - corner.x), floori(best.pos.y - v * 0.5), floori(best.pos.z - corner.y)
	)
	var cells: Array[Vector3i] = [chunk]
	_sim.damage_chunks(_index, cells, HUGE)


func _shot(shot_name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(shot_name + ".png"))
