extends "res://tests/lib/runner.gd"
## Crowd suite (director, playtest comments #17 and b2-8): the stadium's fans are never drawn
## standing on nothing once the stand under them has gone, and the crowd thins over seconds
## instead of vanishing. Each test drives the sim's stadium (RampageSim.damage_chunks) and reads
## the StadiumCrowd the rampage built; "standing" is a fan still seated or running upright, "dying"
## one that fell, or lies under the dust (StadiumCrowd.State).
##   godot --headless --path . --script tests/run_crowd_tests.gd

const GuiInput := preload("res://tests/lib/gui_input.gd")
## Frames a fan may be drawn standing on a lost stand (the brief: no more than a frame or two).
const GRACE := 2
const HUGE := 1.0e9
## Every second of the thinning check, the crowd's loss is read over this many frames.
const SECOND := 60

var _rampage: Rampage
var _sim: RampageSim
var _index := 0
var _crowd: StadiumCrowd
var _stadium: RampageSim.Building
## The stadium's chunks as built: where there never was one, nobody stands on a hole.
var _built := PackedFloat32Array()


func suite_name() -> String:
	return "Crowd"


## A check whose numbers the log keeps even when it passes.
func _numbered(condition: bool, expectation: String) -> void:
	print("CROWD ", "ok   " if condition else "FAIL ", expectation)
	check(condition, expectation)


func run_checks() -> void:
	await _t("_check_stand_lost_under_seated_fans")
	await _t("_check_stand_lost_under_running_fans")
	await _t("_check_crowd_thins_when_the_stands_go")
	await _t("_check_crowd_thins_when_it_flees")


## A fresh rampage with the stadium and its seated crowd, a few frames in.
func _begin() -> bool:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	# Stage 2: the stadium spot is outside the baby's band (lead call A), so stage 1 has none.
	stats["size"] = 2
	var layout := CityGrowth.layout(Content.tuning(), 2, Seeds.make("city", 0))
	_rampage = Rampage.new()
	_rampage.setup(species, stats, layout, 0)
	root.add_child(_rampage)
	await physics_frame
	await physics_frame
	_sim = _rampage.sim
	_crowd = GuiInput.find_script(_rampage, StadiumCrowd)
	for i: int in _sim.buildings.size():
		if _sim.buildings[i].landmark == str(Content.sports()["pitch"]["landmark"]):
			_index = i
			_stadium = _sim.buildings[i]
	_built = _stadium.frame.standing().duplicate()
	check(_crowd != null and _crowd.in_stands() >= 500, "the stands are full to start with")
	return _crowd != null


func _end() -> void:
	_rampage.queue_free()
	await process_frame


## The chunk of the stands a fan sits in (its seat), the first of `skip` seated fans up the bowl.
func _stand_chunk(skip: int) -> Vector3i:
	var fan := _crowd.fans[skip]
	return _chunk_at(fan.pos)


func _chunk_at(at: Vector3) -> Vector3i:
	var v := BuildingVoxels.VOXEL
	var corner := Vector2(_stadium.x - _stadium.w * 0.5, _stadium.z - _stadium.d * 0.5)
	return Vector3i(floori(at.x - corner.x), floori(at.y - v * 0.5), floori(at.z - corner.y))


## Standing fans drawn over a chunk that has gone: the bug. A fan stepping down an exit (past its
## run) is going out of sight by design and is not counted.
func _dangling() -> Array[StadiumCrowd.Fan]:
	var hp := _stadium.frame.standing()
	var out: Array[StadiumCrowd.Fan] = []
	for fan: StadiumCrowd.Fan in _crowd.fans:
		if fan.state != StadiumCrowd.State.SEATED and fan.state != StadiumCrowd.State.UP:
			continue
		var p := _crowd.running_at(fan)
		var c := _chunk_at(p)
		if not _stadium.frame.inside(c):
			continue
		var along := Vector2(p.x - fan.pos.x, p.z - fan.pos.z).length()
		if fan.state == StadiumCrowd.State.UP and along >= fan.run - 0.001:
			continue  # stepping down the exit
		var at := _stadium.frame.index(c)
		if _built[at] > 0.0 and hp[at] <= 0.0:
			out.append(fan)
	return out


## Over `frames` frames: the most frames in a row any one fan was drawn standing on nothing, and
## the most fans so in one frame.
func _watch_dangling(frames: int) -> Dictionary:
	var run: Dictionary = {}
	var streak := 0
	var most := 0
	for _i: int in frames:
		await physics_frame
		var now := _dangling()
		most = maxi(most, now.size())
		var next: Dictionary = {}
		for fan: StadiumCrowd.Fan in now:
			next[fan] = Num.i(run.get(fan, 0)) + 1
			streak = maxi(streak, Num.i(next[fan]))
		run = next
	return {"streak": streak, "most": most}


func _check_stand_lost_under_seated_fans() -> void:
	if not await _begin():
		return
	var seated := _crowd.in_stands()
	_sim.damage_chunks(_index, [_stand_chunk(seated / 2)] as Array[Vector3i], HUGE)
	var at_once := _dangling().size()
	var seen := await _watch_dangling(30)
	_numbered(
		Num.i(seen["streak"]) <= GRACE,
		(
			"no seated fan is drawn on a lost stand for more than %d frames: %d, %d at once (%d at first)"
			% [GRACE, seen["streak"], seen["most"], at_once]
		)
	)
	await _end()


func _check_stand_lost_under_running_fans() -> void:
	if not await _begin():
		return
	var seated := _crowd.in_stands()
	_sim.damage_chunks(_index, [_stand_chunk(0)] as Array[Vector3i], HUGE)
	var first := await _watch_dangling(200)
	var running := _crowd.running()
	# A second stand goes while the fans run: those on it, and those running on to it, must not
	# be drawn standing over the gap, now or later.
	_sim.damage_chunks(_index, [_stand_chunk(seated * 3 / 4)] as Array[Vector3i], HUGE)
	var seen := await _watch_dangling(900)
	_numbered(
		maxi(Num.i(first["streak"]), Num.i(seen["streak"])) <= GRACE,
		(
			"no running fan hangs over a lost stand for over %d frames: %d (%d), then %d (%d); %d run"
			% [GRACE, first["streak"], first["most"], seen["streak"], seen["most"], running]
		)
	)
	await _end()


## The most the visible crowd shrinks by in any one second, as a share of the start.
func _worst_loss(counts: PackedInt32Array) -> float:
	var worst := 0.0
	for i: int in range(0, counts.size() - SECOND):
		worst = maxf(worst, float(counts[i] - counts[i + SECOND]) / counts[0])
	return worst


func _watch(frames: int) -> PackedInt32Array:
	var counts := PackedInt32Array()
	for _i: int in frames:
		await physics_frame
		counts.append(_crowd.in_stands())
	return counts


func _check_crowd_thins_when_the_stands_go() -> void:
	if not await _begin():
		return
	var cap := Num.f(Content.section("crowd")["max_loss_per_second"])
	# Every chunk of the stands above the stub, at once: the whole bowl comes down.
	var all: Array[Vector3i] = []
	for fan: StadiumCrowd.Fan in _crowd.fans:
		var c := _chunk_at(fan.pos)
		if not all.has(c):
			all.append(c)
	_sim.damage_chunks(_index, all, HUGE)
	var counts := await _watch(60 * 20)
	var worst := _worst_loss(counts)
	_numbered(
		worst <= cap,
		(
			"the whole bowl falling thins the crowd by at most %.0f%% a second: worst %.0f%%, %d left"
			% [cap * 100.0, worst * 100.0, counts[counts.size() - 1]]
		)
	)
	await _end()


func _check_crowd_thins_when_it_flees() -> void:
	if not await _begin():
		return
	var cap := Num.f(Content.section("crowd")["max_loss_per_second"])
	var seated := _crowd.in_stands()
	_sim.damage_chunks(_index, [_stand_chunk(0)] as Array[Vector3i], HUGE)
	var counts := await _watch(60 * 40)
	var worst := _worst_loss(counts)
	var gone := 60 * 40
	for i: int in counts.size():
		if counts[i] == 0:
			gone = i
			break
	_numbered(
		worst <= cap,
		(
			"a fleeing crowd thins by at most %.0f%% a second: worst %.0f%% of %d, empty after %.1f s"
			% [cap * 100.0, worst * 100.0, seated, gone / 60.0]
		)
	)
	await _end()
