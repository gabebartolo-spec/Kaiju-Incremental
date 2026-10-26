extends SceneTree
## A real autoplayed rampage (as capture_rampage_kaiju.gd) that also logs, off-screen, one line
## a rendered frame to <out>: how many standing building cells the camera bubble hides (cells of
## the sim's building frames whose centre is nearer the camera than the bubble radius), how many
## buildings hold them, the radius and the camera-to-kaiju distance. Used to pick a clip window
## where a tower is cut away. Needs a window and --write-movie (one rendered frame per movie frame).
##
##   godot --path . --resolution 3840x2160 --windowed --write-movie <out.avi> --fixed-fps 30 \
##     --script tools/capture/capture_bubble_log.gd -- --species=reptilian --seconds=30 --out=<log>

const Kit := preload("res://tools/capture/capture_kit.gd")


func _initialize() -> void:
	var a := Kit.args({"species": "reptilian", "seconds": 30.0, "out": "bubble_log.txt"})
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(str(a["species"]), Num.f(a["seconds"]), str(a["out"]))


func _run(species: String, seconds: float, out: String) -> void:
	await process_frame
	var rampage := Kit.autoplay(self, species, Kit.stats(species), 0)
	var log := FileAccess.open(out, FileAccess.WRITE)
	var frames := int(seconds * 30.0)
	for f: int in frames:
		await process_frame
		if rampage.sim.over:
			break
		var cam: Camera3D = rampage.get("_camera")
		var bubble: CameraBubble = rampage.get("_bubble")
		var eye := cam.global_position
		var radius := bubble.radius()
		var cells := 0
		var towers := 0
		for b: RampageSim.Building in rampage.sim.buildings:
			if b.frame == null:
				continue
			var lo := Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5)
			var box := AABB(lo, Vector3(b.w, b.height, b.d))
			var near := eye.clamp(box.position, box.end)
			if near.distance_to(eye) >= radius:
				continue
			var here := 0
			for z: int in b.frame.d:
				for y: int in b.frame.h:
					for x: int in b.frame.w:
						var c := Vector3i(x, y, z)
						var centre := lo + Vector3(x + 0.5, y + 0.5, z + 0.5)
						if b.frame.alive(c) and centre.distance_to(eye) < radius:
							here += 1
			cells += here
			towers += 1 if here > 0 else 0
		var kaiju := Vector3(rampage.sim.kaiju_pos.x, 0.0, rampage.sim.kaiju_pos.y)
		log.store_line("%d %d %d %.2f %.2f" % [f, cells, towers, radius, eye.distance_to(kaiju)])
	log.close()
	quit()
