class_name LandmarkBurst
extends Node3D
## Every section a landmark sheds (a stadium's rim or stands, toppling or dropping) bursts where
## it stands on its break frame (D-078 round 4): its piece is gone at once, a spray of its own
## voxels is thrown outward from the landmark's middle, under dust, so no cut face, hinge or
## lip is ever seen. CityView keeps this node in the section's place until the sim lands the
## fall (it rotates or drops it, to no effect: nothing is left inside), and its landing leaves
## no strip or crush (CityView.fall_land).

const SECONDS := 0.15  # a landed landmark section's shrink (retire)
const SPRAY := 120  # voxels thrown per section (the debris field caps the total)

var debris := 0


## True for any section a landmark sheds.
static func bursts(sim: RampageSim, event: Dictionary) -> bool:
	return sim.buildings[Num.i(event["building"])].landmark != ""


## A section that has landed: an ordinary building's goes at once (its debris and rubble take
## over); a landmark's shrinks into its hinge over SECONDS under the dust, so it never pops.
static func retire(node: Node3D, landmark: bool) -> void:
	if not landmark:
		node.queue_free()
		return
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.01, SECONDS)
	tween.tween_callback(node.queue_free)


## piece: the lifted section (BuildingView.lift_piece), freed here. view: for its debris and
## dust. event: the sim's fall_start (its building's middle: the spray flies away from it).
func _init(piece: Node3D, view: CityView, event: Dictionary) -> void:
	var b := view.sim.buildings[Num.i(event["building"])]
	var parts: Array = piece.get_meta("parts", [])
	piece.queue_free()
	if parts.is_empty():
		return
	var middle := Vector3.ZERO
	for part: Dictionary in parts:
		var pos: Vector3 = part["pos"]
		middle += pos
	middle /= parts.size()
	var every := maxi(1, parts.size() / SPRAY)
	for n: int in range(0, parts.size(), every):
		var part: Dictionary = parts[n]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		var out := Vector3(pos.x - b.x, 0.0, pos.z - b.z).normalized()
		view.debris(pos, color, (out + Vector3.UP * 0.5).normalized())
		debris += 1
	view.fx.dust(middle, 1.0 + parts.size() * 0.0006)
