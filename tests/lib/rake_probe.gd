extends RefCounted
## Drives the croc titan standing at one growth step (the motion suite's stages, D-135) with the
## real sim, which swipes on its own clock (Claws), at 60 Hz, feeds the model the cues exactly as
## PowersView does ("swipe_windup" -> claw_windup, "swipe" -> claw), and measures every swipe's
## raking arm in the rig's frame, in hip heights (the director's D-177 claw rake bars): scale,
## chest yaw, hand height, azimuth sweep and overshoot, hand speed (load, strike window, ramp,
## frame-to-frame change), the hand's crossing of the snout line against the sim's hit, the hand's
## elevation over the shoulder and over the chest horizontal, shoulder/elbow/wrist angles, planted
## toes, settle time. Reads only the rig's bones, so it runs unchanged on any version of the rake.
## Deterministic: a seeded sim, a fixed step, no clock.

const Drive := preload("res://tests/lib/motion_drive.gd")
const DT := 1.0 / 60.0
const SECONDS := 6.0
## Frames kept after a hit for the follow-through and the settle.
const AFTER := 100


## One frame of the raking pair's geometry, rig space in hip heights. arm[side index 0 (-x) / 1
## (+x)] holds the shoulder, elbow, wrist and claw tip.
class Fr:
	var arm: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	var arm_q: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
	var spine := Vector3.ZERO
	var toe: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # world, in hip heights
	var planted: Array[bool] = [false, false]
	var scale_dev := 0.0
	var half := 0.0  # the torso's half-width seen from behind (hip heights)


## The swipes of one growth step: [{"side", "cue", "hit", ...metrics}], from the real sim.
static func run(root: Node, stage: String) -> Array[Dictionary]:
	var def := Content.species_def("reptilian")
	var base: Dictionary = Drive.STAGES[stage]
	var levels: Dictionary = base.duplicate()
	levels["claws"] = 1
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 30)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var rig: KaijuRig = kaiju._rig
	var gait := rig.gait as ClipGait
	var frames: Array[Fr] = []
	var cues: Array[Vector2] = []  # (frame, side)
	var hits: Array[Vector2] = []
	for f: int in roundi(SECONDS / DT):
		var move := Vector2.ZERO
		for event: Dictionary in sim.step(DT, move, false, 0):
			match str(event["type"]):
				"swipe_windup":
					kaiju.tail_sweep(Num.f(event["side"]), "claw_windup")
					cues.append(Vector2(f, Num.f(event["side"])))
				"swipe":
					kaiju.tail_sweep(Num.f(event["side"]), "claw")
					hits.append(Vector2(f, Num.f(event["side"])))
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
		kaiju.animate(DT, 0.0, -sim.body.turn_left)
		frames.append(_snap(rig, gait))
	var out: Array[Dictionary] = []
	for i: int in mini(cues.size(), hits.size()):
		var last := mini(frames.size() - 1, int(hits[i].x) + AFTER)
		var m := analyse(frames, int(cues[i].x), int(hits[i].x), hits[i].y, last)
		m["stage"] = stage
		var recover: Variant = Content.section("claw_fx")["recover_s"]
		if recover is Dictionary:
			var by_stage: Dictionary = recover
			recover = by_stage[KaijuModel.stage_for(sim.size_tier())]
		m["recover_cfg"] = Num.f(recover)
		m["scale"] = sim.body_scale()
		m["miss"] = (
			Num.f(gait.swing.call("rake_miss")) if gait.swing.has_method("rake_miss") else 0.0
		)
		out.append(m)
	kaiju.free()
	return out


static func _snap(rig: KaijuRig, gait: ClipGait) -> Fr:
	var fr := Fr.new()
	var to_rig := rig.global_transform.affine_inverse()
	var hip := gait.hip_height
	var hh := hip * gait.s
	for s: int in 2:
		var arm := "r" if s == 1 else "l"
		for i: int in 3:
			fr.arm[s].append(to_rig * rig.bone("arm_%s%d" % [arm, i]).global_position / hip)
		fr.arm[s].append(to_rig * rig.tail_world("arm_%s2" % arm) / hip)
		var b := rig.bone("arm_%s0" % arm).global_transform.basis.orthonormalized()
		fr.arm_q[s] = Quaternion(to_rig.basis.orthonormalized() * b)
	for n: String in ["spine1", "spine2"]:
		var part := rig.voxels_of(n)
		if part != null:
			for cell: Vector3i in part.cells:
				fr.half = maxf(fr.half, absf(cell.x) * rig.voxel_size() / hip)
	fr.spine = to_rig * rig.tail_world("spine2") - to_rig * rig.bone("spine2").global_position
	for j: int in 2:
		fr.toe[j] = rig.tail_world(gait.legs[j].names[2]) / hh
		fr.planted[j] = gait.legs[j].planted
	for n: String in rig.bone_names():
		var off := (rig.bone(n).scale - Vector3.ONE).abs()
		fr.scale_dev = maxf(fr.scale_dev, maxf(off.x, maxf(off.y, off.z)))
	return fr


## The chest's frame at one moment: x lateral (left to right shoulder), y dorsal, z = x cross y.
static func chest(fr: Fr) -> Basis:
	var l := (fr.arm[1][0] - fr.arm[0][0]).normalized()
	var f := (fr.spine - l * fr.spine.dot(l)).normalized()
	var u := l.cross(f).normalized()
	return Basis(l, u, l.cross(u))


static func _deg(v: float) -> float:
	return rad_to_deg(v)


## Every bar's number for the swipe cued at frame `cue`, hit at `hit`, on `side` (+1 the +x arm).
static func analyse(frames: Array[Fr], cue: int, hit: int, side: float, last: int) -> Dictionary:
	var a := 1 if side > 0.0 else 0
	var n := last + 1
	var speed: Array[float] = []
	var phi: Array[float] = []
	var g: Array[float] = []
	var elev_w: Array[float] = []
	var elev_c: Array[float] = []
	var m: Dictionary = {"side": side, "cue": cue, "hit": hit, "scale_dev": 0.0}
	var yaw0 := 0.0
	var q0 := Quaternion.IDENTITY
	var d0 := Vector3.ZERO
	var hum_elev := -999.0
	var cone := 0.0
	var roll := 0.0
	var elbow := 0.0
	var wrist := 0.0
	var slide := 0.0
	var bends: Array[String] = []
	var toe0: Array[Vector3] = frames[cue].toe
	for i: int in range(cue, n):
		var fr := frames[i]
		var arm := fr.arm[a]
		var cb := chest(fr)
		var v := fr.arm[1][0] - fr.arm[0][0]
		var yaw := _deg(atan2(-v.z, v.x))
		var hand := arm[3] - arm[0]
		if i == cue:
			yaw0 = yaw
			q0 = Quaternion(cb.inverse()) * fr.arm_q[a]
			d0 = cb.inverse() * (BipedSwing.ARM_UPPER * Vector3(side, 1.0, 1.0)).normalized()
		g.append(side * (yaw - yaw0))
		phi.append(_deg(atan2(-side * hand.x, -hand.z)))
		elev_w.append(_deg(asin(clampf(hand.y / maxf(hand.length(), 0.0001), -1.0, 1.0))))
		elev_c.append(_deg(asin(clampf(hand.dot(cb.y) / maxf(hand.length(), 0.0001), -1.0, 1.0))))
		speed.append(0.0 if i == cue else (arm[3] - frames[i - 1].arm[a][3]).length() / DT)
		var up := arm[1] - arm[0]
		hum_elev = maxf(hum_elev, _deg(asin(clampf(up.normalized().dot(cb.y), -1.0, 1.0))))
		var dc: Vector3 = cb.inverse() * up.normalized()
		cone = maxf(cone, _deg(dc.angle_to(d0)))
		var dq := (Quaternion(cb.inverse()) * fr.arm_q[a]) * q0.inverse()
		var roll_i := 2.0 * atan2(Vector3(dq.x, dq.y, dq.z).dot(dc), dq.w)
		roll = maxf(roll, absf(_deg(wrapf(roll_i, -PI, PI))))
		var elbow_i := _deg(up.angle_to(arm[2] - arm[1]))
		var wrist_i := _deg((arm[2] - arm[1]).angle_to(arm[3] - arm[2]))
		bends.append("%.0f/%.0f" % [elbow_i, wrist_i])
		elbow = maxf(elbow, elbow_i)
		wrist = maxf(wrist, wrist_i)
		m["scale_dev"] = maxf(Num.f(m["scale_dev"]), fr.scale_dev)
		for j: int in 2:
			if fr.planted[j] and frames[cue].planted[j]:
				var flat := Vector2(fr.toe[j].x - toe0[j].x, fr.toe[j].z - toe0[j].z)
				slide = maxf(slide, flat.length())
	var span := n - cue  # index of frame i in the arrays is i - cue
	var peak := 0.0
	var peak_i := cue
	for k: int in range(1, mini(span, hit - cue + 30)):
		if speed[k] > peak:
			peak = speed[k]
			peak_i = cue + k
	var win := 0
	var load_end := cue + span
	for k: int in span:
		if speed[k] >= 0.5 * peak:
			win += 1
			load_end = mini(load_end, cue + k)
	var load_sum := 0.0
	for k: int in range(1, load_end - cue):
		load_sum += speed[k]
	var load_mean := load_sum / maxf(1.0, load_end - cue - 1.0)
	var first := 0.0
	for k: int in range(1, mini(7, span)):
		first = maxf(first, speed[k])
	# Speed change frame to frame; one frame near the hit is the impact's and exempt.
	var dv_hit := 0.0
	var dv_rest := 0.0
	for k: int in range(2, span):
		var dv := absf(speed[k] - speed[k - 1])
		if absi(cue + k - hit) <= 2:
			dv_hit = maxf(dv_hit, dv)
		else:
			dv_rest = maxf(dv_rest, dv)
	var cross := -1
	for i: int in range(cue + 1, n):
		if frames[i].arm[a][3].x * side <= 0.0 and frames[i - 1].arm[a][3].x * side > 0.0:
			cross = i
			break
	var pmax_k := 0
	for k: int in range(span):
		if phi[k] > phi[pmax_k]:
			pmax_k = k
	var pmin := phi[0]
	for k: int in range(pmax_k + 1):
		pmin = minf(pmin, phi[k])
	var gmin := 0.0
	var gmax := -999.0
	for k: int in range(mini(span, hit - cue + 30)):
		gmax = maxf(gmax, g[k])
	for k: int in range(mini(span, hit - cue + 1)):
		gmin = minf(gmin, g[k])
	var win_h := -999.0
	var el_load := -999.0
	var el_strike := -999.0
	var el_follow := -999.0
	var rise := -999.0
	for k: int in span:
		var i := cue + k
		var hand_y := frames[i].arm[a][3].y - frames[i].arm[a][0].y
		if i < load_end:
			el_load = maxf(el_load, elev_c[k])
		elif speed[k] >= 0.5 * peak and i <= peak_i + 12:
			win_h = maxf(win_h, hand_y)
			el_strike = maxf(el_strike, elev_c[k])
		else:
			el_follow = maxf(el_follow, elev_c[k])
		rise = maxf(rise, elev_c[k])
	# (the claw seen from its shoulder, so the clip's idle sway does not blur the settle)
	# Seen from the game camera (behind the kaiju): the claw shows while it is outboard of the chest.
	var half := frames[cue].half
	var vis_hit := 0
	var vis_load := 0
	var hit_off := -999.0
	for i: int in range(cue, hit + 5):
		var tip := frames[i].arm[a][3]
		var shown := side * tip.x > half
		if i >= hit - 4:
			vis_hit += 1 if shown else 0
		elif i >= cue + 2:
			vis_load += 1 if shown else 0
		if absi(i - hit) <= 1:
			var ahead := -(tip.z - frames[i].arm[a][0].z)
			var off := _deg(atan2(side * tip.x, ahead))
			if absf(off - 80.0) < absf(hit_off - 80.0):
				hit_off = off
	m["vis_hit"] = vis_hit
	m["vis_load"] = vis_load
	m["load_n"] = hit - 4 - (cue + 2)
	m["hit_off"] = hit_off
	var rest_hand := frames[last].arm[a][3] - frames[last].arm[a][0]
	var far := 0.0  # the furthest the hand strays from where it ends
	for i: int in range(hit, n):
		far = maxf(far, (frames[i].arm[a][3] - frames[i].arm[a][0] - rest_hand).length())
	var settled := cue
	for i: int in range(hit, n):
		if (frames[i].arm[a][3] - frames[i].arm[a][0] - rest_hand).length() > 0.05 * far:
			settled = i
	var pmax_i := cue + pmax_k
	m["win_s"] = win * DT
	m["peak"] = peak
	m["load_ratio"] = peak / maxf(load_mean, 0.0001)
	m["first01"] = first / maxf(peak, 0.0001)
	m["dv_rest"] = dv_rest / maxf(peak, 0.0001)
	m["dv_hit"] = dv_hit / maxf(peak, 0.0001)
	m["cross_off"] = (cross - hit) if cross >= 0 else 999
	m["over_deg"] = (phi[pmax_k] - phi[cross - cue]) if cross >= 0 else -999.0
	m["arc_deg"] = phi[pmax_k] - pmin
	m["chest_load"] = gmin
	m["chest_swing"] = gmax - gmin
	m["strike_h"] = win_h
	m["elev_load"] = el_load
	m["elev_strike"] = el_strike
	m["elev_follow"] = el_follow
	m["elev_max"] = rise
	m["hum_elev"] = hum_elev
	m["cone"] = cone
	m["roll"] = roll
	m["elbow"] = elbow
	m["wrist"] = wrist
	m["slide"] = slide
	var trace: Array[String] = []
	for k: int in range(0, mini(span, 70)):
		trace.append("%.1f/%.0f/%.0f" % [speed[k], phi[k], g[k]])
	m["trace"] = " ".join(trace)
	m["bends"] = " ".join(bends.slice(0, 70))
	m["settle_s"] = (settled - pmax_i) * DT
	m["recover_s"] = (settled - hit) * DT
	return m


## A bar row for the log.
static func row(m: Dictionary) -> String:
	var keys := [
		"peak",
		"miss",
		"hit_off",
		"vis_hit",
		"vis_load",
		"scale_dev",
		"chest_load",
		"chest_swing",
		"strike_h",
		"arc_deg",
		"load_ratio",
		"first01",
		"win_s",
		"dv_rest",
		"dv_hit",
		"cross_off",
		"over_deg",
		"elev_load",
		"elev_strike",
		"elev_follow",
		"hum_elev",
		"cone",
		"roll",
		"elbow",
		"wrist",
		"slide",
		"settle_s",
		"recover_s"
	]
	var parts: Array[String] = []
	for k: String in keys:
		parts.append("%s=%.3f" % [k, Num.f(m[k])])
	return "%s side %+d: %s" % [m["stage"], m["side"], " ".join(parts)]
