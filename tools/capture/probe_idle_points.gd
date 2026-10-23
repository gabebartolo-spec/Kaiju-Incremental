extends SceneTree
## How far and how fast the croc titan's body moves while it stands (D-165 breath bars), headless,
## per stage, the plain baked idle (--life=0) or with the life layer (--life=1): for points on the
## back, shoulders, flank, head, tail and belly, the peak-to-peak travel (share of the body's
## height) and the top speed (share of the body's height per second, over 0.2 s so frame noise
## does not count), over the last 40 s of a 60 s stand. The breath's own cycle: its length and its
## inhale / exhale shares.
##   godot --headless --path . --script tools/capture/probe_idle_points.gd -- --life=1

const STAGES: Array[String] = ["baby", "adolescent", "adult"]
const DT := 1.0 / 60.0
const RUN := 60.0
const FROM := 20.0
const SPAN := 12  ## frames: 0.2 s
## Points: label -> [bone, true for the bone's tail end].
const POINTS := {
	"back (spine1)": ["spine1", false],
	"shoulders (spine2)": ["spine2", false],
	"flank (arm_l0)": ["arm_l0", false],
	"hip (leg_l0)": ["leg_l0", false],
	"head (head0)": ["head0", false],
	"snout (head1 tip)": ["head1", true],
	"tail base (tail1)": ["tail1", false],
	"tail tip": ["tail8", true],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var life := true
	var breath_only := false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--life=0":
			life = false
		if arg == "--breath-only":
			breath_only = true
	for stage: String in STAGES:
		var colors: Dictionary = Content.species_def("reptilian")["colors"]
		var kaiju := KaijuModel.new("reptilian", colors, stage)
		root.add_child(kaiju)
		var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
		var gait: ClipAlive = rig.gait
		gait.life_on = life
		gait.life.breath_only = breath_only
		var tracks := {}
		for label: String in POINTS:
			tracks[label] = [] as Array[Vector3]
		var inhale: Array[float] = []
		var last := 0.0
		var rose := -1.0
		for f: int in int(RUN / DT):
			kaiju.animate(DT, 0.0)
			if float(f) * DT < FROM:
				continue
			for label: String in POINTS:
				var row: Array = POINTS[label]
				var bone_name: String = row[0]
				var at := (
					rig.tail_world(bone_name) if row[1] else rig.bone(bone_name).global_position
				)
				var track: Array[Vector3] = tracks[label]
				track.append(at)
			var now := gait.life.breath
			if life and now > last and rose < 0.0:
				rose = float(f) * DT
			last = now
		print("%s (%s):" % [stage, "life layer" if life else "plain baked idle"])
		for label: String in POINTS:
			var track: Array[Vector3] = tracks[label]
			print(
				"  %-20s %s" % [label, _report(track, kaiju.hip_height() / gait.hip_height * 10.0)]
			)
		kaiju.queue_free()
		inhale.clear()
	quit()


## Peak-to-peak and top speed, as shares of the body's height (`height`, world units).
func _report(track: Array[Vector3], height: float) -> String:
	var lo := track[0]
	var hi := track[0]
	var top := 0.0
	for i: int in track.size():
		lo = Vector3(minf(lo.x, track[i].x), minf(lo.y, track[i].y), minf(lo.z, track[i].z))
		hi = Vector3(maxf(hi.x, track[i].x), maxf(hi.y, track[i].y), maxf(hi.z, track[i].z))
		if i >= SPAN:
			top = maxf(top, track[i].distance_to(track[i - SPAN]) / (float(SPAN) * DT))
	return (
		"travel %.2f %% of height (box %.2f), top speed %.2f %%/s"
		% [_far(track) / height * 100.0, (hi - lo).length() / height * 100.0, top / height * 100.0]
	)


## The farthest two samples of a track are apart.
func _far(track: Array[Vector3]) -> float:
	var worst := 0.0
	for i: int in range(0, track.size(), 6):
		for j: int in range(i, track.size(), 24):
			worst = maxf(worst, track[i].distance_to(track[j]))
	return worst
