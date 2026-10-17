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
