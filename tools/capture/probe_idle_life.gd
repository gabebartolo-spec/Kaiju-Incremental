extends SceneTree
## Numbers for the croc titan's standing life (D-165, ClipIdle), headless, per stage over 120 s at
## 60 Hz: the breath's length (mean, shortest, longest), the most a foot moves off the plain
## baked stand (hip heights), the jaw's widest crack (deg), the weight shift, the blinks, how far
## the skin is pushed (rig units).
##   godot --headless --path . --script tools/capture/probe_idle_life.gd

const STAGES: Array[String] = ["baby", "adolescent", "adult"]
const DT := 1.0 / 60.0
const SECONDS := 120.0


func _initialize() -> void:
	_run.call_deferred()


func _model(stage: String, life: bool) -> KaijuModel:
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	root.add_child(kaiju)
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var gait: ClipAlive = rig.gait
	gait.life_on = life
	return kaiju


func _run() -> void:
	await process_frame
	for stage: String in STAGES:
		var kaiju := _model(stage, true)
		var plain := _model(stage, false)
		var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
		var rig_plain: KaijuRig = plain.find_children("*", "KaijuRig", true, false)[0]
		var gait: ClipAlive = rig.gait
		var skin: VoxelSkin = kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)[0]
		var hip := kaiju.hip_height()
		var last := 0.0
		var crossed: Array[float] = []
		var slide := 0.0
		var jaw := 0.0
		var shift := 0.0
		var push := 0.0
		var blinks := 0
		var shut := false
		for f: int in int(SECONDS / DT):
			kaiju.animate(DT, 0.0)
			plain.animate(DT, 0.0)
			var now := gait.life.breath
			if last <= 0.0 and now > 0.0 and gait.life.weight >= 1.0:
				crossed.append(float(f) * DT)
			last = now
			for leg: String in ["leg_l2", "leg_r2"]:
				slide = maxf(slide, rig.tail_world(leg).distance_to(rig_plain.tail_world(leg)))
			var open := absf(
				(
					rig.bone("jaw").transform.basis.get_euler().x
					- rig_plain.bone("jaw").transform.basis.get_euler().x
				)
			)
			jaw = maxf(jaw, open)
			shift = maxf(shift, absf(gait.life.pelvis_x))
			push = maxf(push, absf(skin.breath))
			if skin.blink > 0.9 and not shut:
				shut = true
				blinks += 1
			if skin.blink < 0.1:
				shut = false
		var gaps: Array[float] = []
		for i: int in range(1, crossed.size()):
			gaps.append(crossed[i] - crossed[i - 1])
		var mean := (crossed[-1] - crossed[0]) / float(crossed.size() - 1)
		print(
			(
				(
					"%s: breath %.2f s (shortest %.2f, longest %.2f), foot off the plain stand %.4f hip, "
					% [stage, mean, gaps.min(), gaps.max(), slide / hip]
				)
				+ (
					"jaw %.1f deg, pelvis shift %.3f hip, blinks %d in %d s, skin push %.3f rig units"
					% [rad_to_deg(jaw), shift, blinks, int(SECONDS), push]
				)
			)
		)
		kaiju.queue_free()
		plain.queue_free()
	quit()
