extends RefCounted
## The smoke suite's Blender vehicle checks (D-042): the tank and the helicopter load as their
## parts and move them (split out of run_smoke_tests.gd to keep files small).


## The Blender tank (D-042) loads as hull, turret and gun; the turret swings onto a target at
## the side while the hull stays put, and a shot leaves the muzzle ahead of the hull and kicks the
## gun back.
static func check_tank(check: Callable, root: Node) -> void:
	var tank := TankModel.new()
	root.add_child(tank)
	var cfg := Content.section("vehicles")
	var counts: Array[int] = []
	for part: Node3D in [tank, tank._turret, tank._barrel]:
		for child: Node in part.get_children():
			if child is MultiMeshInstance3D:
				counts.append((child as MultiMeshInstance3D).multimesh.instance_count)
	check.call(
		counts.size() == 3 and not counts.has(0) and tank._barrel.get_parent() == tank._turret,
		"the tank is hull > turret > gun, each with voxels: %s" % [counts]
	)
	var target := Vector3(10.0, 1.0, 0.0)  # off the right side
	for _i: int in 120:
		tank.aim(target, 1.0 / 60.0)
	var facing := -tank._turret.global_basis.z
	var want := (target - tank._turret.global_position) * Vector3(1, 0, 1)
	check.call(
		facing.angle_to(want.normalized()) < 0.05 and tank.rotation.y == 0.0,
		"the turret turns onto a target at the side (off by %.3f rad)" % facing.angle_to(want)
	)
	var rest := tank._barrel.position
	var muzzle := tank.fire()
	tank._process(Num.f(cfg["recoil_seconds"]) * 0.25)
	check.call(
		muzzle.x > 2.0 and tank._barrel.position.distance_to(rest) > 0.05,
		"the shot leaves the muzzle (%s) and the gun kicks back" % muzzle
	)
	tank.free()


## The Blender helicopter (D-042) loads as body, main rotor, tail rotor and chin gun; both rotors
## spin about their own hubs, and the gun swings onto a target below and ahead with the muzzle
## at the nose.
static func check_heli(check: Callable, root: Node) -> void:
	var heli := HelicopterModel.new()
	root.add_child(heli)
	var main: Node3D = heli._main_rotor
	var tail: Node3D = heli._tail_rotor
	var hub := main.position
	heli._process(0.1)
	var parts := heli.get_children().filter(func(c: Node) -> bool: return not c is MeshInstance3D)
	check.call(
		parts.size() == 4 and main.rotation.y > 0.5 and tail.rotation.x > 0.5,
		(
			"the rotors spin about their hubs (main %.2f, tail %.2f rad)"
			% [main.rotation.y, tail.rotation.x]
		)
	)
	var target := Vector3(3.0, -6.0, -12.0)
	heli.aim(target)
	var muzzle := heli.fire()
	var aim := -heli._gun.global_basis.z
	check.call(
		(
			aim.angle_to(target - heli._gun.global_position) < 0.02
			and muzzle.z < -2.0
			and main.position == hub
		),
		"the chin gun aims at a target below and ahead; muzzle at %s" % muzzle
	)
	heli.free()
