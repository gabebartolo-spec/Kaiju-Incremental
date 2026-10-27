extends RefCounted
## D-326 (director 2026-10-27: "its ok to obscure the kaiju, its not ok to block the camera";
## "Only a wall that fills the frame at the camera is handled"): FrameShare measures how much of the
## screen a box covers, and BuildingFade fades only a building in a sight line that covers
## camera.fade_frame_share or more of it. Every other building stays solid, a faded wall that
## stops filling the frame eases back, and one with a section in the air snaps solid for the fall.
## Pure maths on hand-made boxes and buildings: no scene, no clock.

const ASPECT := 16.0 / 9.0
const DT := 1.0 / 60.0
## Frames the easing is given to finish (fade_seconds is a quarter of a second).
const EASE_FRAMES := 60


static func check(check: Callable) -> void:
	_share_maths(check)
	_fade_rule(check)


## The share of the screen, on boxes whose cover can be worked out by hand.
static func _share_maths(check: Callable) -> void:
	var eye := Vector3(0, 10, 40)
	var frame := FrameShare.looking(eye, Vector3(0, 10, 0), 40.0, ASPECT)
	# 4 m cube 20 m ahead: 4 / (2 * 20 * tan 20) tall, and that over the aspect wide: about 4%.
	var small := frame.share_of(AABB(Vector3(-2, 8, 18), Vector3(4, 4, 4)))
	# A wall wider and taller than the whole view, 20 m ahead.
	var wall := frame.share_of(AABB(Vector3(-200, -100, 19), Vector3(400, 300, 2)))
	var inside := frame.share_of(AABB(Vector3(-5, 0, 35), Vector3(10, 30, 10)))
	var behind := frame.share_of(AABB(Vector3(-5, 0, 50), Vector3(10, 30, 10)))
	# Wide, from one metre over the eye's height up, from 10 m ahead (the near edge crosses the
	# camera's plane): the screen above the box's far lower edge, (1 - 0.5 / (10 tan 20)) / 2.
	var low := frame.share_of(AABB(Vector3(-50, 10.5, 30), Vector3(100, 50, 20)))
	var edge := (1.0 - 0.5 / (10.0 * tan(deg_to_rad(20.0)))) * 0.5
	check.call(
		small > 0.02 and small < 0.08 and wall > 0.99 and inside == 1.0 and behind == 0.0,
		(
			(
				"FrameShare: a 4 m cube 20 m ahead covers %.1f%%, a wall past the view %.1f%%, the"
				+ " eye inside a box 100%%, a box behind the camera %.1f%%"
			)
			% [small * 100.0, wall * 100.0, behind * 100.0]
		)
	)
	check.call(
		absf(low - edge) < 0.02,
		(
			"FrameShare: a box across the camera's near plane covers %.1f%% (worked out %.1f%%)"
			% [low * 100.0, edge * 100.0]
		)
	)


## BuildingFade with the real share: a small building between the camera and the kaiju stays
## solid, a wall at the camera fades, falls hold a building solid, a wall the camera backs away
## from eases back.
static func _fade_rule(check: Callable) -> void:
	var eye := Vector3(0, 10, 40)
	var sight := BuildingFade.targets(Vector3.ZERO, 20.0, Vector3(0, 0, -3))
	var share := Num.f(Content.section("camera")["fade_frame_share"])
	var floor_opacity := Num.f(Content.section("camera")["fade_opacity"])
	var frame := FrameShare.looking(eye, Vector3(0, 10, 0), 40.0, ASPECT)
	var small := _building(6, 2, 14, 15.0)
	var wall := _building(40, 2, 40, 33.0)
	var small_fade := _fade(small)
	var wall_fade := _fade(wall)
	var worst := 1.0
	for i: int in EASE_FRAMES:
		small_fade.update(frame, sight, DT)
		worst = minf(worst, small_fade.opacity(0))
	var covers := frame.share_of(AABB(Vector3(-3, 0, 14), Vector3(6, 14, 2)))
	(
		check
		. call(
			small_fade.blocking(eye, sight).size() == 1 and covers < share and worst == 1.0,
			(
				(
					"a small building (%.1f%% of the screen, under %.0f%%) between the camera and the kaiju"
					+ " stays at opacity %.2f for %d frames"
				)
				% [covers * 100.0, share * 100.0, worst, EASE_FRAMES]
			)
		)
	)
	wall_fade.update(frame, sight, DT)
	var first := wall_fade.opacity(0)
	check.call(
		wall_fade.blocking(eye, sight).size() == 1 and is_equal_approx(first, floor_opacity),
		"a wall that fills the frame fades (opacity %.2f on the run's first frame)" % first
	)
	wall_fade.update(frame, sight, DT, {0: true})
	var held := wall_fade.opacity(0)
	for i: int in EASE_FRAMES:
		wall_fade.update(frame, sight, DT, {0: true})
		held = minf(held, wall_fade.opacity(0))
	check.call(
		held == 1.0,
		"a wall with a section in the air snaps to opacity 1 and stays there (%.2f)" % held
	)
	var back := FrameShare.looking(Vector3(0, 10, 140), Vector3(0, 10, 0), 40.0, ASPECT)
	var far := back.share_of(AABB(Vector3(-20, 0, 32), Vector3(40, 40, 2)))
	wall_fade = _fade(wall)
	wall_fade.update(frame, sight, DT)  # the wall is faded, filling the frame
	wall_fade.update(back, sight, DT)
	var easing := wall_fade.opacity(0)
	for i: int in EASE_FRAMES:
		wall_fade.update(back, sight, DT)
	(
		check
		. call(
			far < share and easing < 1.0 and wall_fade.opacity(0) == 1.0,
			(
				(
					"a faded wall the camera backs away from (now %.1f%% of the screen) eases back to solid"
					+ " (%.2f a frame later, %.2f after %d)"
				)
				% [far * 100.0, easing, wall_fade.opacity(0), EASE_FRAMES]
			)
		)
	)


static func _fade(b: RampageSim.Building) -> BuildingFade:
	var buildings: Array[RampageSim.Building] = [b]
	return BuildingFade.new(buildings, func(_n: int) -> BuildingView: return null)


static func _building(w: int, d: int, h: int, z: float) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.w = w
	b.d = d
	b.height = h
	b.z = z
	return b
