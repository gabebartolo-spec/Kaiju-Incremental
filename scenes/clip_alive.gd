class_name ClipAlive
extends ClipGait
## ClipGait plus the standing life layer (D-165, ClipIdle): standing, the baked idle breathes at the
## stage's own pace and the pose gets the weight shift, the head's drift and glances, the sigh and
## the jaw crack on top, while the skin shader gets the breath and the blink. It adds to the clip's
## pose before the feet are planted, so the legs are re-solved to the locked feet as they are for
## the clip. Walking, turning, roaring and the beam fade it out in a quarter second; with it faded
## out the pose is exactly ClipGait's. Presentation only.

## The run's number the next croc's standing life draws on (Rampage.setup sets it).
static var run_seed := 0

## Debug and tests: false plays the plain baked idle (3 s breath, no life layer).
var life_on := true
var life: ClipIdle
var _skin: VoxelSkin
var _calm := PackedFloat32Array()  # the baked idle's share kept, per bone (KaijuClips.idle_calm)
var _idle_s := 3.0


## The gait for a biped rig: ClipAlive when it has clips baked for this skeleton, else BipedGait.
static func or_biped(p_rig: KaijuRig, p_clips: Variant) -> KaijuGait:
	if p_clips is KaijuClips and not ClipGait.off:
		var baked: KaijuClips = p_clips
		var why := baked.fit(p_rig)
		if why.is_empty():
			return ClipAlive.new(p_rig, baked)
		push_warning("ClipGait: the clips do not fit this rig (%s); walking procedurally" % why)
	return BipedGait.new(p_rig)


func _init(p_rig: KaijuRig, p_clips: KaijuClips) -> void:
	super(p_rig, p_clips)
	_idle_s = float(clips.frames_of("idle")) / clips.fps
	life = ClipIdle.new(_tail_count())
	life.seed = run_seed
	_set_calm()
	life.begin()


## The stage ("baby", "adolescent", "adult") and the skin that gets the breath and the blink.
func set_life(stage_name: String, skin: VoxelSkin) -> void:
	life.stage = maxi(0, ["baby", "adolescent", "adult"].find(stage_name))
	_set_calm()
	life.begin()
	_skin = skin


## The run's number: the schedule starts over on it.
func set_seed(run: int) -> void:
	life.seed = run
	life.begin()


func update(delta: float) -> void:
	clips.idle_calm = _calm if life_on else PackedFloat32Array()
	super(delta)
	if _skin != null:
		_skin.breath = life.skin_push() * KaijuModel.MODEL_HEIGHT
		_skin.breath_peak = life.skin_peak() * KaijuModel.MODEL_HEIGHT
		_skin.breath_phase = life.phase_now()
		_skin.breath_depth = life.depth_weight()
		_skin.breath_lag = life.lag()
		_skin.blink = life.blink


func _choose(dt: float) -> void:
	var was := state
	var idle_was := clip_time
	super(dt)
	if not life_on:
		return
	var standing := state == "idle" and not head.held_open
	if state == "idle":
		if was != "idle":
			life.begin()
		else:  # the baked breath plays at this breath's pace, not its own 3 s
			var played := clip_time - idle_was
			clip_time = idle_was + played * life.rate(_idle_s)
	var frames := float(clips.frames_of("idle"))
	life.step(dt, standing, fposmod(clip_time / frames, 1.0) if state == "idle" else 0.0)


func _apply(pose: KaijuClips.Pose, dt: float) -> void:
	if life_on and life.is_active():
		for i: int in clips.bones.size():
			pose.turns[i] = life.turn(clips.bones[i]) * pose.turns[i]
		pose.offset.x += life.pelvis_x * hip_height / clips.rig_scale
	super(pose, dt)


## The baked idle's own sway, cut: the body's (it nods the snout, heaves the chest at the old 3 s)
## to calm_body, the tail's (a slow sway that stays) to the stage's calm_tail.
func _set_calm() -> void:
	var cfg := Content.section("croc_idle")
	var tail: Array = cfg["calm_tail"]
	var calm_tail := Num.f(tail[life.stage])
	clips.idle_calm_offset = Num.f(cfg["calm_body"])
	_calm.resize(clips.bones.size())
	for i: int in clips.bones.size():
		_calm[i] = calm_tail if clips.bones[i].begins_with("tail") else Num.f(cfg["calm_body"])


func _tail_count() -> int:
	var count := 0
	for bone_name: String in clips.bones:
		count += 1 if bone_name.begins_with("tail") else 0
	return count
