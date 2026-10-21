class_name FallMotion
extends RefCounted
## How a toppling building piece turns: a quarter turn by its end, about the level axis across its
## fall direction. A topple whose direction came out zero (the sim rounds a tiny overhang to
## none) turns about a fixed axis, so it still goes over instead of logging "axis must be
## normalized" and standing still (rooftops #63 CI run: 133 such errors in one mass collapse).

## The axis a direction-less topple turns about.
const STILL_AXIS := Vector3.RIGHT


## The piece's turn at `k` (0..1 of its fall time; gravity: the angle grows with k squared).
static func topple_basis(dir: Vector2, k: float) -> Basis:
	return topple_turn(dir, PI * 0.5 * k * k)


## The piece turned `angle` (radians) over its fall direction (ToppleFx shapes the angle).
static func topple_turn(dir: Vector2, angle: float) -> Basis:
	var axis := Vector3(dir.y, 0, -dir.x)
	if axis.is_zero_approx():
		axis = STILL_AXIS
	return Basis(axis.normalized(), angle)
