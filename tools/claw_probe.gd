extends SceneTree
## Prints the claw swipe's raking-arm numbers at every growth stage (tests/lib/claw_arm_probe.gd):
## bone stretch, elbow and wrist range, how far the upper arm crosses the chest, each bone's peak
## angular speed, the claw tip's peak speed, when the claw crosses the snout line against the sim's
## hit, and how long the arm is off its held pose. Bars: data/motion_gate.json "claw_arm".
##   godot --headless --path . --script tools/claw_probe.gd [-- --frames]

const ClawArmProbe := preload("res://tests/lib/claw_arm_probe.gd")
const STAGES: Array[String] = ["baby", "adolescent", "adult"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var bars: Dictionary = Content.load_json("res://data/motion_gate.json")["claw_arm"]
	var scales: Array = bars["body_scales"]
	for i: int in STAGES.size():
		var m := ClawArmProbe.new().measure(root, STAGES[i], Num.f(scales[i]))
		await process_frame
		print(
			(
				"%s: body scale %.2f, hip %.2f u; stretch max %.1f%%; elbow %.0f-%.0f deg; wrist %.0f-%.0f deg"
				% [
					STAGES[i],
					Num.f(scales[i]),
					m.hip,
					m.stretch * 100.0,
					m.elbow.x,
					m.elbow.y,
					m.wrist.x,
					m.wrist.y,
				]
			)
		)
		print(
			(
				"  claw fastest at f%d, the hit at f%d; nearest the snout line %+.2f hip (<= 0 reaches it)"
				% [m.fastest_at, m.hit, m.short]
			)
		)
		print(
			(
				(
					"  upper arm least outward %+.2f (held %+.2f); peak deg/s upper %.0f fore %.0f"
					+ " hand %.0f; tip %.1f hip/s; away %.2f s, home f%d"
				)
				% [
					m.across,
					m.held,
					m.peak[0],
					m.peak[1],
					m.peak[2],
					m.tip,
					m.away,
					m.home,
				]
			)
		)
		if OS.get_cmdline_user_args().has("--frames"):
			for r: String in m.rows:
				print(r)
	quit(0)
