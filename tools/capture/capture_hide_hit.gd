extends SceneTree
## Shot impacts on the kaiju's hide (director 2026-10-25), stills only. In a real rampage a tank is set
## on the camera's side of the standing kaiju and fires one real shell (TankFx.fire_shell) at its chest
## height: stills at the hit frame and +0.05, +0.2, +0.4, +0.6 s, each with a 2x crop on the hit; then
## the same shot from the far side (the hit must be hidden by his body), and, with armour, a glance.
## --worn: a 3-minute rampage with the real army, then a still and a 2x crop of the battle-worn hide.
## Prints the measured numbers (flash px, lifetimes, wounds). --before runs on code without HideHit.
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 --script tools/capture/capture_hide_hit.gd \
##     -- --stage=1 --tod=night --out=<dir> [--worn] [--before]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 90
## Frames after the hit that get a still: 0, 0.05, 0.2, 0.4, 0.6 s at 60 fps.
const STRIP: Array[int] = [0, 3, 12, 24, 36]
const CROP := Vector2i(600, 600)
const WORN_SECONDS := 180.0
const WORN_SMALL := Vector2i(960, 540)

var _out := "user://hide_hit"
var _stage := 1
var _tod := "night"
var _worn := false
var _before := false
var _species := "reptilian"
var _frame := 0
var _target := Vector2(INF, INF)
var _hold := false


func _initialize() -> void:
	var a := Kit.args(
		{"out": _out, "stage": _stage, "tod": _tod, "worn": _worn, "before": _before, "species": _species}
	)
	_out = str(a["out"])
	_stage = Num.i(a["stage"])
	_tod = str(a["tod"])
	_worn = a["worn"] == true
	_before = a["before"] == true
	_species = str(a["species"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var stats := Kit.stats(_species, Kit.STAGE_LEVELS[_stage], _species)
	var rampage := Kit.rampage(_species, stats, 1)
	Content.set_time(_tod)
	Content.set_weather("clear")
	rampage.scripted = _input
	root.add_child(rampage)
	await physics_frame
	await rampage.wait_loaded()
	var aim := rampage.get_node_or_null("BreathAim")
	if aim != null:
		aim.queue_free()
	_hold = not _worn
	while rampage.sim.emerge.active:
		await physics_frame
	await Kit.ticks(self, SETTLE)
	if _worn:
		await _run_worn(rampage)
	else:
		await _run_hits(rampage)
	quit()


## Walk into the nearest standing building; held still for the single-shot captures.
func _input(sim: RampageSim) -> Dictionary:
	if _hold:
		return {"move": Vector2.ZERO}
	if _frame % 20 == 0:
		_target = sim.nearest_standing(sim.kaiju_pos)
	if _target.x == INF or sim.kaiju_pos.distance_to(_target) < 1.0:
		return {"move": Vector2.ZERO}
	return {"move": (_target - sim.kaiju_pos).normalized()}


func _run_hits(rampage: Rampage) -> void:
	var tag := "%s_s%d_%s%s" % [_species, _stage, _tod, "_before" if _before else ""]
	var bs := rampage.sim.body_scale()
	var kaiju_at: Vector3 = rampage._kaiju_at
	var cam: Camera3D = rampage._camera
	print("SCALE body_scale %.2f kaiju_at %s voxel_world %s" % [bs, kaiju_at, _voxel(rampage)])
	var target := kaiju_at + Vector3(0, 4.0 * bs, 0)  # where TankYard.fire aims
	# Near side: on the camera's side, to the right. Far side: opposite.
	for side: String in ["near", "far", "glance"]:
		var offset := Vector3(5.0, 0, 11.0) * bs
		if side == "far":
			offset = Vector3(-5.0, 0, -11.0) * bs
		var tank := TankModel.new()
		tank.position = kaiju_at + offset
		rampage.add_child(tank)
		for _i: int in 80:
			tank.aim(target, 1.0 / 60.0)
		var armour := side == "glance"
		if armour:
			rampage.sim.stats["armor"] = 1.0
		await Kit.ticks(self, 2)
		var seen_before := _flash_count(rampage)
		TankFx.fire_shell(rampage, tank, target, false)
		var fired := _frame
		var hit_frame := -1
		for i: int in 120:
			await process_frame
			if _flash_count(rampage) > seen_before or _shell_gone(rampage, i):
				hit_frame = i
				break
		print("HIT %s %s shell frames %d" % [tag, side, hit_frame])
		var points: Array[Vector3] = [target]
		var at := cam.unproject_position(target)
		for k: int in STRIP.size():
			var want := STRIP[k]
			var have := 0 if k == 0 else STRIP[k - 1]
			for _i: int in want - have:
				await process_frame
			var path := Kit.still(self, _out, "%s_%s_f%02d" % [tag, side, want])
			var shot := root.get_texture().get_image()
			var size := Vector2(shot.get_size())
			var crop_at := Kit.image_point(self, cam, target, size)
			Kit.crop_2x(shot, crop_at, CROP, path.replace(".png", "_2x.png"))
			if k == 0:
				print("FLASH_SCREEN %s %s at %s count %d" % [tag, side, at, _flash_count(rampage)])
				_measure_flash(rampage, cam, size)
		tank.queue_free()
		if armour:
			rampage.sim.stats["armor"] = 0.0
		await Kit.ticks(self, 90)
	print("WOUNDS %s live %d" % [tag, _wounds(rampage)])


func _run_worn(rampage: Rampage) -> void:
	var tag := "%s_s%d_%s%s" % [_species, _stage, _tod, "_before" if _before else ""]
	var cam: Camera3D = rampage._camera
	root.get_window().size = WORN_SMALL
	var frames := roundi(WORN_SECONDS * Engine.physics_ticks_per_second)
	var shots := 0
	for i: int in frames:
		await physics_frame
		_frame = i
		if i % 1800 == 0:
			print(
				"WORN t=%ds hp %.1f wounds %d"
				% [i / 60, rampage.sim.hp, _wounds(rampage)]
			)
		if rampage.sim.over:
			break
	_hold = true
	root.get_window().size = Vector2i(3840, 2160)
	await Kit.ticks(self, 30)
	var kaiju_at: Vector3 = rampage._kaiju_at
	var path := Kit.still(self, _out, "%s_worn" % tag)
	var shot := root.get_texture().get_image()
	var size := Vector2(shot.get_size())
	var chest := kaiju_at + Vector3(0, 4.0 * rampage.sim.body_scale(), 0)
	Kit.crop_2x(shot, Kit.image_point(self, cam, chest, size), Vector2i(900, 900), path.replace(".png", "_2x.png"))
	print(
		"WORN done size %s wounds %d shots %d"
		% [size, _wounds(rampage), shots]
	)


func _wounds(rampage: Rampage) -> int:
	var kaiju: Node = rampage._kaiju
	if not kaiju.has_method("wounds_live"):
		return -1
	var n: int = kaiju.call("wounds_live")
	return n


func _voxel(rampage: Rampage) -> float:
	var kaiju: Node = rampage._kaiju
	if not kaiju.has_method("voxel_world"):
		return 0.12
	var v: float = kaiju.call("voxel_world")
	return v


func _flash_count(rampage: Rampage) -> int:
	var fx: Fx = rampage._city.fx
	var hit: Node = fx.get("_hide_hit")
	return 0 if hit == null else hit.get_child_count()


## Without HideHit (--before) the hit frame is the shell's end: its box leaves the rampage.
func _shell_gone(rampage: Rampage, i: int) -> bool:
	if not _before:
		return false
	var shells := 0
	for c: Node in rampage.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			shells += 1
	return i > 5 and shells == 0


## Prints the flash's size on screen (px at this resolution) and its colour headroom.
func _measure_flash(rampage: Rampage, cam: Camera3D, size: Vector2) -> void:
	var fx: Fx = rampage._city.fx
	var hit: Node = fx.get("_hide_hit")
	if hit == null:
		return
	for c: Node in hit.get_children():
		if c is MeshInstance3D:
			var quad := c as MeshInstance3D
			var half := quad.global_transform.basis.x * 0.5
			var a := cam.unproject_position(quad.global_position - half)
			var b := cam.unproject_position(quad.global_position + half)
			var px := a.distance_to(b) * size.x / root.get_visible_rect().size.x
			print("FLASH_PX %.1f at %dx%d" % [px, size.x, size.y])
	var tune: Dictionary = Content.section("fx")["hide_hit"]
	var tint := Color(str(tune["flash_tint"])).srgb_to_linear()
	var peak := Num.f(tune["flash_alpha"])
	print(
		"FLASH_LUMA max linear channel %.3f (threshold 0.9) life %.3f s = %d frames"
		% [maxf(tint.r, maxf(tint.g, tint.b)) * peak, Num.f(tune["flash_seconds"]), ceili(Num.f(tune["flash_seconds"]) * 60.0)]
	)
