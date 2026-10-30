class_name RampageCamera
extends RefCounted
## The gameplay camera each frame: the follow, the step dip, the turn and the lead, the run intro's
## shot while he rises, the blasts' jitter and the shake.


static func place(r: Rampage, delta: float) -> void:
	var zoom := CameraTuning.zoom(r.sim.body_scale())
	# Follow the body as drawn (KaijuModel.focus), eased: an insect's hold settles still on
	# screen and its dart bursts ahead of the camera.
	# Follow the body as drawn (KaijuModel.focus), eased: an insect's hold settles still on screen
	# and its dart bursts ahead of the camera.
	r._follow.step(
		r._kaiju.focus(), r.camera_rest * zoom - Vector3(0, r._step_dip * zoom * motion, 0), delta
	)
	r._follow.turn_with(r.sim.facing, not r.sim.emerge.active, delta)  # D-330, D-259
	var hold := r.sim.body.dash.on() or r._ability.leaping() or r.sim.emerge.active  # rise: no lead
	r._follow.step_lead(r._kaiju.position, r.sim.body_scale(), hold, delta)
	var nod := r.shake.turn(r.sim.body_scale(), motion).y
	var aim := r._follow.aim(r._kaiju, r.sim.body_scale(), Vector2(r.camera_fov, nod), delta)
	var view := {"body": r._kaiju_at, "eye": r._follow.eye(), "aim": aim, "fov": r.camera_fov}
	if r.sim.emerge.active:  # the run intro's shot, ending exactly on this camera (RunIntro)
		view = r._rise.shot(view, r._follow, r._hud)
	RampageRise.aim_camera(
		r._camera, RunIntro.above_water(r.sim, view), r._blasts.jitter() * motion
	)
	r.shake.apply(r._camera, r.sim.body_scale(), motion)
