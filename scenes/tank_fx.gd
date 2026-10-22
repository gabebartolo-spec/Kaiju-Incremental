class_name TankFx
extends RefCounted
## What a tank's shell and wreck look like; Rampage decides when (sim events), this draws.


## Flies one shell from the tank's muzzle to the target, with the hit (or deflect) on arrival; a
## miss (`miss`) only flies, as long as the sim takes to land it (its impact is the stray_landed).
static func fire_shell(host: Rampage, node: TankModel, target: Vector3, miss := false) -> void:
	var muzzle := node.fire()
	var shell := TankModel.box(Vector3.ONE * 0.35, muzzle, UiKit.WARN)
	shell.material_override = CityView.glow(UiKit.WARN, 4.0)
	host.add_child(shell)
	host._city.flash(muzzle, Color("ffc070"), 4.0, 0.12)
	host.sfx.play_at("tank_fire", muzzle)
	var tween := shell.create_tween()
	tween.tween_property(shell, "position", target, Num.f(host.sim.army["shell_flight"]))
	if miss:
		pass
	elif host.sim.stat("armor") > 0.0:
		var away := (node.position - target).normalized() + Vector3.UP * 0.5
		tween.tween_callback(func() -> void: host.ability_fx.deflect(target, away))
		tween.tween_callback(func() -> void: host.sfx.play("deflect"))
	else:
		tween.tween_callback(func() -> void: host._city.fx.sparks(target))
		tween.tween_callback(func() -> void: host.sfx.play_at("shell_hit", target))
	tween.tween_callback(shell.queue_free)


## Debris, flash, fire and the rubble the wreck pays.
static func wreck(city: CityView, pos: Vector3, gained: float) -> void:
	for n: int in 8:
		city.debris(
			pos + Vector3(0, 0.5, 0), TankModel.TAN if n % 2 == 0 else UiKit.ACCENT, Vector3.UP
		)
	city.flash(pos + Vector3(0, 1.0, 0), Color("ff8a3a"), 7.0, 0.5)
	city.fire(pos, 0.6)
	city.float_text("+%d" % Num.i(gained), pos + Vector3(0, 2, 0), UiKit.WARN)


## A stray shell's impact (StrayShell): a flash, debris, a dust cloud and a small fire where it
## lands, and the people there are the army's casualties, not the kaiju's.
static func stray(city: CityView, at: Vector3, radius: float) -> void:
	for n: int in 8:
		city.debris(
			at + Vector3(0, 0.5, 0), TankModel.TAN if n % 2 == 0 else UiKit.WARN, Vector3.UP
		)
	city.flash(at + Vector3(0, 1.0, 0), Color("ff8a3a"), 9.0, 0.45)
	city.fx.dust(at + Vector3(0, 1.0, 0), 1.2)
	city.fire(at, 0.35)
	city.crush(at, radius, false, true)
