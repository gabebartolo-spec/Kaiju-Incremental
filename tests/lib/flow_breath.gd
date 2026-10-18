extends RefCounted
## Atomic Breath probes for the flow suite: the legacy voxel jet must stay gone, and the scorch's
## molten cracks must glow in rather than land at full on the breath's first frame.

## Wider than any stomp mark: only the breath scorch spans its cone (about 2x reach).
const SCORCH_MIN_SIZE := 12.0


## Live voxel-cube jets (glowing 0.25 u cubes) in the rampage, above the prewarm spot.
static func jets(rampage: Rampage) -> int:
	var count := 0
	for node: Node in rampage.find_children("*", "GPUParticles3D", true, false):
		var p: GPUParticles3D = node
		var cube := p.draw_pass_1 as BoxMesh
		if cube != null and is_equal_approx(cube.size.x, 0.25) and p.global_position.y > -10.0:
			count += 1
	return count


## The widest Decal in the rampage is the breath scorch: remember its glow when first seen
## ("first") and the most it reaches ("peak").
static func track_scorch_glow(rampage: Rampage, glow: Dictionary) -> void:
	var widest: Decal = null
	for node: Node in rampage.find_children("*", "Decal", true, false):
		var d: Decal = node
		if d.global_position.y > -10.0 and (widest == null or d.size.x > widest.size.x):
			widest = d
	if widest == null or widest.size.x < SCORCH_MIN_SIZE:
		return
	if not glow.has("first"):
		glow["first"] = widest.emission_energy
	glow["peak"] = maxf(Num.f(glow.get("peak", 0.0)), widest.emission_energy)


## The breath's aim (director playtest): while the breath is ready, BreathAim draws the very cone
## the sim burns (BreathCone.of()). Call each frame; tally {"shown", "hidden", "worst"} (the
## largest mismatch seen: origin and reach in units, direction and half angle in radians).
static func track_aim(rampage: Rampage, tally: Dictionary) -> void:
	var aim := rampage.find_child("BreathAim", false, false) as BreathAim
	if aim == null or not aim.visible:
		tally["hidden"] = Num.i(tally.get("hidden", 0)) + 1
		return
	tally["shown"] = Num.i(tally.get("shown", 0)) + 1
	var drawn := aim.drawn()
	var sim := BreathCone.of(rampage.sim)
	var dir_a: Vector2 = drawn["dir"]
	var dir_b: Vector2 = sim["dir"]
	var at_a: Vector2 = drawn["origin"]
	var at_b: Vector2 = sim["origin"]
	var worst := Num.f(tally.get("worst", 0.0))
	worst = maxf(worst, at_a.distance_to(at_b))
	worst = maxf(worst, absf(dir_a.angle_to(dir_b)))
	worst = maxf(worst, absf(Num.f(drawn["reach"]) - Num.f(sim["reach"])))
	tally["worst"] = maxf(worst, absf(Num.f(drawn["half_angle"]) - Num.f(sim["half_angle"])))
