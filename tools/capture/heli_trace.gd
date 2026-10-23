extends RefCounted
## The per-frame trace of a heli-deaths clip (stdout "T,..." and "X,..." lines), read by the
## measured tables of the reports: screen positions in px at 1080p, a camera reference point, both
## arm tips, the hull's height, yaw and screen point, the sim's own crash point, the camera's
## trauma and kick, and the burning hull's flame state.

## Logs one line a frame for the clip (stdout "T,..."): a fixed ground point's screen position (the
## camera's kick, px at 1080p), both arm tips, the burning hull's height, screen point and roll, the
## falling wreck's height and yaw. The measured table of the report comes from it.
const ROW := (
	"T,%d,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.2f,%.1f,%.1f,%.1f,%.2f,%.1f,"
	+ "%.3f,%.3f,%.3f,%.3f,%.1f,%.1f"
)


static func run(tree: SceneTree, rampage: Rampage, frames: int) -> void:
	var cam := tree.root.get_viewport().get_camera_3d()
	var model: KaijuModel = rampage._kaiju
	print(
		(
			"T,n,rake_t,cam_x,cam_y,armL_x,armL_y,armR_x,armR_y,hull_y,hull_x,hull_py,roll,"
			+ "fall_y,yaw,fall_x,fall_z,sim_x,sim_z,fall_px_x,fall_px_y"
		)
	)
	for n: int in frames:
		var sim := rampage.sim
		var feet := Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		var ref := cam.unproject_position(feet + Vector3(sim.facing.x, 0.0, sim.facing.y) * 6.0)
		var arm_l := cam.unproject_position(model._rig.tail_world("arm_l2"))
		var arm_r := cam.unproject_position(model._rig.tail_world("arm_r2"))
		var wrecks: HeliWreck = rampage._powers._wrecks  # made on the first death
		var swing := (model._rig.gait as BipedGait).swing
		var hull := Vector3.ZERO
		var hull_px := Vector2.ZERO
		var roll := 0.0
		for piece: HeliDebris.Piece in [] if wrecks == null else wrecks._debris._pieces:
			if piece.heavy and is_instance_valid(piece.node):
				hull = piece.node.global_position
				hull_px = cam.unproject_position(hull)
				roll = rad_to_deg(piece.node.rotation.z)
				break
		var fall_y := 0.0
		var fall_yaw := 0.0
		var fall_at := Vector3.ZERO
		var fall_px := Vector2.ZERO
		var sim_at := Vector2.ZERO
		for down: AirWing.Falling in sim.air.falling:
			sim_at = down.pos
		for fall: HeliWreck.Fall in [] if wrecks == null else wrecks._falling.values():
			fall_y = fall.node.position.y
			fall_yaw = rad_to_deg(fall.yaw)
			fall_at = fall.node.position
			fall_px = cam.unproject_position(fall.node.global_position)
		var kb := Rect2(
			cam.unproject_position(model._rig.bone(model._rig.bone_names()[0]).global_position),
			Vector2.ZERO
		)
		for bone_name: String in model._rig.bone_names():
			kb = kb.expand(cam.unproject_position(model._rig.tail_world(bone_name)))
			kb = kb.expand(cam.unproject_position(model._rig.bone(bone_name).global_position))
		var chute := Vector2(-1, -1)
		var smoke := Vector2(-1, -1)
		if wrecks != null:
			for c: HeliCrew.Chute in wrecks._crew._chutes:
				if is_instance_valid(c.node):
					chute = cam.unproject_position(c.node.global_position + Vector3(0, 4.0, 0))
			for fall: HeliWreck.Fall in wrecks._falling.values():
				smoke = cam.unproject_position(fall.trail.global_position)
		print(
			(
				"G,%d,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f"
				% [
					n,
					kb.position.x,
					kb.position.y,
					kb.end.x,
					kb.end.y,
					chute.x,
					chute.y,
					smoke.x,
					smoke.y
				]
			)
		)
		var emit := -1
		var vis := -1
		var live := 0
		for fall: HeliWreck.Fall in [] if wrecks == null else wrecks._falling.values():
			for fire: Fire in fall.fires:
				live += 1 if is_instance_valid(fire) else 0
				for child: Node in fire.get_children():
					if child is GPUParticles3D:
						emit = 1 if (child as GPUParticles3D).emitting else 0
						vis = 1 if (child as GPUParticles3D).is_visible_in_tree() else 0
						break
		print(
			(
				"X,%d,%.3f,%.3f,%d,%d,%d,%.1f"
				% [
					n,
					rampage.shake.trauma,
					rampage.shake._kick_left,
					emit,
					vis,
					live,
					sim.time_left
				]
			)
		)
		var row := (
			ROW
			% [
				n,
				swing._rake_t,
				ref.x,
				ref.y,
				arm_l.x,
				arm_l.y,
				arm_r.x,
				arm_r.y,
				hull.y,
				hull_px.x,
				hull_px.y,
				roll,
				fall_y,
				fall_yaw,
				fall_at.x,
				fall_at.z,
				sim_at.x,
				sim_at.y,
				fall_px.x,
				fall_px.y
			]
		)
		print(row)
		await tree.process_frame
