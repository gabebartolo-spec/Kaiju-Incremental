extends RefCounted
## The croc standing suite's check of a clip-keyed standing stomp (the adult's Cascadeur r10d,
## D-199), measured in the game: the approved clip's own bars (stomp plan S2, S3, S4, S7) replace
## the code foot arc's floors for it (lead ruling 2026-10-26: those floors measured the code lift
## the clip replaces). One press, the adult standing, fixed 60 Hz steps:
##   S3  the lifted foot's ankle rises at least ANKLE_RISE hip heights;
##   S2  the knee peaks KNEE_LEAD frames (keyed, 30 fps) before the ankle;
##   S4  the drive speeds up into the street: the ankle's last step down is the fastest and at
##       least DRIVE x its mean step down;
##   S7  the body drops at least DROP hip heights within the first 3 keyed frames of contact and is
##       back to the clip's settled height (SETTLE) by 8 keyed frames on;
## the toe is on the street in the frame its footfall goes out (the suite's footfall bar), and the
## hand-over from the clip's end to the idle moves the hips at most SETTLE a frame (the
## clip's end pose sits a little off the idle's: it must ease, never pop).

const DT := 1.0 / 60.0
const KEYED := 1.0 / 30.0  # s per keyed frame (r10d)
const ANKLE_RISE := 0.30
const KNEE_LEAD := Vector2(1.0, 3.0)
const DRIVE := 1.8
const DROP := 0.04
const SETTLE := 0.005
const FRAMES := 150  # 2.5 s: the stomp, its hold, the hand-over and the idle

var _check: Callable


func _init(check: Callable) -> void:
	_check = check


func run(kaiju: KaijuModel, rig: KaijuRig) -> void:
	var gait := rig.gait as ClipGait
	var hip := kaiju.hip_height()
	var landed: Array[int] = []
	var clock: Array[int] = [0]
	rig.foot_planted.connect(
		func(side: String, _strength: float, _at: Vector3) -> void:
			if side != "tail":
				landed.append(clock[0])
	)
	for f: int in 60:
		kaiju.animate(DT, 0.0)
	var ankle0 := _ankle(rig, "leg_l2")
	var toe0 := rig.tail_world("leg_l2").y
	var toe: Array[float] = []
	var pelvis0 := _pelvis(rig)
	var ankle: Array[float] = []
	var knee: Array[float] = []
	var pelvis: Array[float] = []
	var states: Array[String] = []
	kaiju.prefer_foot("left")
	kaiju.stomp()
	for f: int in FRAMES:
		clock[0] = f
		kaiju.animate(DT, 0.0)
		ankle.append((_ankle(rig, "leg_l2") - ankle0) / hip)
		toe.append((rig.tail_world("leg_l2").y - toe0) / hip)
		knee.append(rig.bone("leg_l1").global_position.y / hip)
		pelvis.append((_pelvis(rig) - pelvis0) / hip)
		states.append(gait.state)
	var contact := landed[0] if not landed.is_empty() else FRAMES - 1
	var top := _argmax(ankle, contact)
	_check.call(
		ankle[top] >= ANKLE_RISE,
		"adult clip stomp S3: the ankle rises %.2f hip (>= %.2f)" % [ankle[top], ANKLE_RISE]
	)
	var lead := (top - _argmax(knee, contact)) * DT / KEYED
	_check.call(
		lead >= KNEE_LEAD.x - 0.5 and lead <= KNEE_LEAD.y + 0.5,
		"adult clip stomp S2: the knee peaks %.1f keyed frames before the ankle (1-3)" % lead
	)
	_check.call(
		contact > 0 and toe[contact] <= 0.02 and toe[contact - 1] > 0.03,
		(
			"adult clip stomp: the toe is on the street as the footfall goes out (%.3f hip), moving"
			+ " before (%.3f)"
		) % [toe[contact], toe[maxi(0, contact - 1)]]
	)
	_drive(ankle, top, contact)
	_settle(pelvis, contact, states.find("idle") - 1)
	_hand_over(pelvis, states)


## S4: the ankle's last step down before contact is the fastest of the drive and DRIVE x its mean.
func _drive(ankle: Array[float], top: int, contact: int) -> void:
	var steps: Array[float] = []
	for f: int in range(top + 1, contact + 1):
		steps.append(ankle[f - 1] - ankle[f])
	var mean := 0.0
	for d: float in steps:
		mean += d / maxf(1.0, steps.size())
	var last: float = steps[-1] if not steps.is_empty() else 0.0
	_check.call(
		not steps.is_empty() and last >= Num.f(steps.max()) - 1e-6 and last >= DRIVE * mean,
		"adult clip stomp S4: the last step down is the fastest, %.1fx the mean (>= %.1f)" % [
			last / maxf(mean, 1e-6), DRIVE
		]
	)


## S7: the body drops from its height at contact within 3 keyed frames (as stomp_bars_adult3.py
## measures it) and is back by 8 (to the clip's settled end pose, frame `rest`, the last before the
## idle takes over).
func _settle(pelvis: Array[float], contact: int, rest: int) -> void:
	var low := 0.0
	for f: int in range(contact, mini(pelvis.size(), contact + roundi(3 * KEYED / DT) + 1)):
		low = minf(low, pelvis[f])
	var settled := pelvis[maxi(0, rest)]
	var back := pelvis[mini(pelvis.size() - 1, contact + roundi(8 * KEYED / DT))] - settled
	low -= pelvis[contact]
	_check.call(
		-low >= DROP and absf(back) <= SETTLE,
		"adult clip stomp S7: the body drops %.3f hip (>= %.2f), back to %.4f by +8 (<= %.3f)" % [
			-low, DROP, back, SETTLE
		]
	)


## The clip's end hands over to the idle: the hips move at most SETTLE hip heights a frame.
func _hand_over(pelvis: Array[float], states: Array[String]) -> void:
	var start := states.find("idle")
	var worst := 0.0
	if start > 0:
		for f: int in range(start, pelvis.size()):
			worst = maxf(worst, absf(pelvis[f] - pelvis[f - 1]))
	_check.call(
		start > 0 and worst <= SETTLE,
		"adult clip stomp: the hand-over to the idle moves the hips %.4f hip a frame (<= %.3f)" % [
			worst, SETTLE
		]
	)


func _ankle(rig: KaijuRig, leg: String) -> float:
	return rig.bone(leg).global_position.y - rig.global_position.y


func _pelvis(rig: KaijuRig) -> float:
	return rig.bone(rig.bone_names()[0]).global_position.y


func _argmax(series: Array[float], before: int) -> int:
	var best := 0
	for f: int in mini(before, series.size()):
		if series[f] > series[best]:
			best = f
	return best
