extends SceneTree
## Probe for the keyed rise from the sea bay (RampageRise.rise, the adult's "rise_bay" clip): per
## clip frame, how high the head crown (bone "head1") and the highest bone stand over the feet
## (world units at body scale 1), so city "harbour" "crouch_back" (the crouched body under the
## water) and "emerge" "keyed_surface" (when the head breaks it) come from the clip, not a guess.
##   godot --headless --fixed-fps 60 --path . --script tools/capture/probe_rise.gd

const STAGES: Array[String] = ["baby", "adolescent", "adult"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	for stage: String in STAGES:
		var kaiju := KaijuModel.new("reptilian", colors, stage)
		root.add_child(kaiju)
		await process_frame
		if not RampageRise.rise(kaiju, 0.0):
			print("%s: no %s clip" % [stage, KaijuModel.RISE_CLIP])
			kaiju.queue_free()
			continue
		var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
		kaiju.animate(1.0 / 60.0, 0.0)
		var rest_top := _top(kaiju, rig)
		for f: int in range(0, 97, 4):
			RampageRise.rise(kaiju, f / 24.0)
			kaiju.animate(1.0 / 60.0, 0.0)
			var head := kaiju.to_local(rig.bone("head1").global_position).y
			print("%s f%d t%.2f head %.2f top %.2f" % [stage, f, f / 24.0, head, _top(kaiju, rig)])
		print(
			"%s rest top bone %.2f (model height %.1f)" % [stage, rest_top, KaijuModel.MODEL_HEIGHT]
		)
		kaiju.queue_free()
	quit()


func _top(kaiju: KaijuModel, rig: KaijuRig) -> float:
	var top := -INF
	for b: String in rig.bone_names():
		top = maxf(top, kaiju.to_local(rig.bone(b).global_position).y)
	return top
