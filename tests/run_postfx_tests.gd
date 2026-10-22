extends "res://tests/lib/runner.gd"
## Post-effects suite (D-142): the vignette is always on and subtle, turns red and pulses at low
## health; the colour fringe fires only on a top-tier impact (a wide stomp, a tall collapse, a
## heavy hit), lasts at most 0.25 s, never repeats inside its cooldown and is never on for long;
## in a real rampage the rects follow the state, sit under the HUD, and a big stomp lands one.
## Seeded by design: no randomness, time is stepped by hand.
##   godot --headless --path . --script tests/run_postfx_tests.gd

const FRAME := 1.0 / 60.0
const MAX_FRINGE_SECONDS := 0.25  # the director's bound (D-142: a split second)


func suite_name() -> String:
	return "PostFx"


func run_checks() -> void:
	await _t("_check_vignette_calm")
	await _t("_check_vignette_low_health")
	await _t("_check_fringe_gates")
	await _t("_check_hp_drop_and_fall")
	await _t("_check_fringe_shape")
	await _t("_check_cooldown_and_share")
	await _t("_check_motion_setting")
	await _t("_check_rampage")


func _cfg() -> Dictionary:
	return Content.section("post_fx")


## Steps `state` for `seconds` at 60 fps and returns the largest fringe seen.
func _run_for(state: PostFxState, seconds: float, hp_share := 1.0, motion := 1.0) -> float:
	var peak := 0.0
	for _i: int in roundi(seconds / FRAME):
		state.update(FRAME, hp_share, motion)
		peak = maxf(peak, state.fringe_px)
	return peak


func _check_vignette_calm() -> void:
	var state := PostFxState.new()
	_run_for(state, 1.0)
	var cfg: Dictionary = _cfg()["vignette"]
	var strength := Num.f(cfg["strength"])
	check(
		is_equal_approx(state.vignette_alpha, strength) and strength > 0.0 and strength <= 0.5,
		(
			"at full health the vignette sits at its subtle strength (%.2f, at most 0.5)"
			% state.vignette_alpha
		)
	)
	check(
		state.vignette_color.r < 0.1 and state.vignette_color.g < 0.1,
		"the calm vignette is dark, not red: %s" % state.vignette_color
	)
	check(
		Num.f(cfg["inner"]) >= 0.4 and Num.f(cfg["outer"]) > Num.f(cfg["inner"]),
		(
			"the vignette leaves the centre clear (starts at %.2f of the corner distance)"
			% Num.f(cfg["inner"])
		)
	)


func _check_vignette_low_health() -> void:
	var low_cfg: Dictionary = _cfg()["low_health"]
	var cap := Num.f(low_cfg["alpha"])
	var just_above := PostFxState.new()
	var above_peak := 0.0
	for _i: int in 120:
		just_above.update(FRAME, Num.f(low_cfg["below"]) + 0.01, 1.0)
		above_peak = maxf(above_peak, just_above.red_alpha)
	var state := PostFxState.new()
	_run_for(state, 2.0, Num.f(low_cfg["full_at"]) * 0.5)
	var lo := 1.0
	var hi := 0.0
	var beats := 0
	var rising := false
	for _i: int in 240:  # a pulse period is 0.77 s at 1.3 Hz: four seconds is five beats
		state.update(FRAME, 0.05, 1.0)
		lo = minf(lo, state.red_alpha)
		hi = maxf(hi, state.red_alpha)
		var up := state.red_alpha > cap * 0.5
		if up and not rising:
			beats += 1
		rising = up
	check(
		above_peak == 0.0 and just_above.low == 0.0,
		"above the low-health line (%.2f of max) there is no red at all" % Num.f(low_cfg["below"])
	)
	check(
		state.red_color.r > 0.6 and state.red_color.g < 0.2 and state.vignette_color.r < 0.1,
		(
			"at very low health the edge band is red (%s) over the unchanged dark vignette"
			% state.red_color
		)
	)
	check(
		lo < cap * 0.02 and hi > cap * 0.95 and hi <= cap + 0.001,
		(
			"each beat swells to the edge alpha (%.2f, cap %.2f) and drops back to nothing (%.3f)"
			% [hi, cap, lo]
		)
	)
	check(
		beats >= 4 and beats <= 6 and Num.f(low_cfg["depth_px"]) <= 150.0 and cap <= 0.3,
		(
			"%d distinct beats in 4 s; the band is %d px deep at 1080 lines, edge alpha %.2f"
			% [beats, Num.i(low_cfg["depth_px"]), cap]
		)
	)
	# Healing back: the red fades out over frames, never a pop.
	var biggest_step := 0.0
	var before := state.red_alpha
	for _i: int in 90:
		state.update(FRAME, 1.0, 1.0)
		biggest_step = maxf(biggest_step, absf(state.red_alpha - before))
		before = state.red_alpha
	check(
		state.low == 0.0 and state.red_alpha == 0.0 and biggest_step < 0.1,
		"healing fades the red out (largest frame step %.3f)" % biggest_step
	)


func _check_fringe_gates() -> void:
	var fringe: Dictionary = _cfg()["fringe"]
	var min_stomp := Num.f(fringe["stomp_min_radius"])
	var min_fall := Num.f(fringe["collapse_min_length"])
	var min_hit := Num.f(fringe["hit_hp_fraction"])
	var states: Array[PostFxState] = []
	var results: Array[bool] = []
	for hit: Array in [
		["stomp", min_stomp * 0.99],
		["collapse", min_fall * 0.99],
		["hurt", min_hit * 0.99],
		["stomp", min_stomp],
		["collapse", min_fall],
		["hurt", min_hit],
	]:
		var state := PostFxState.new()
		states.append(state)
		match str(hit[0]):
			"stomp":
				results.append(state.stomp(Num.f(hit[1])))
			"collapse":
				results.append(state.collapse(Num.f(hit[1])))
			_:
				results.append(state.hurt(Num.f(hit[1])))
	check(
		results == [false, false, false, true, true, true],
		"only a top-tier impact starts a fringe: %s (below the bars, then at them)" % [results]
	)
	check(
		not states[0].fringe_on() and states[3].fringe_on(),
		"a refused hit leaves the fringe off, an accepted one turns it on"
	)
	# A baby's stomp (stage 1 of the flow test) and a small building are far below the bars.
	check(
		min_stomp > 3.0 and min_fall > 20.0 and min_hit >= 0.1,
		"the bars sit well above a hatchling's stomp, an ordinary building and a tank shell"
	)


func _check_hp_drop_and_fall() -> void:
	var min_hit := Num.f(_cfg()["fringe"]["hit_hp_fraction"])
	var heavy := PostFxState.new()
	heavy.update(FRAME, 1.0, 1.0)
	heavy.update(FRAME, 1.0 - min_hit - 0.01, 1.0)
	var chip := PostFxState.new()
	var share := 1.0
	for _i: int in 240:  # a tank shell's worth every few frames, never one big step
		share -= min_hit * 0.4 if _i % 20 == 0 else 0.0
		chip.update(FRAME, share, 1.0)
	check(
		heavy.fringe_on() and not chip.fringe_on() and share < 0.5,
		(
			"one frame losing %.0f%% of max health earns the fringe, a drain of chips does not (%.0f%% left)"
			% [(min_hit + 0.01) * 100.0, share * 100.0]
		)
	)
	var length := Num.f(_cfg()["fringe"]["collapse_min_length"])
	var tall := {"kind": "topple", "scrap": false, "from": Vector2.ZERO, "to": Vector2(length, 0)}
	var results: Array[bool] = []
	for event: Dictionary in [
		tall,
		tall.merged({"scrap": true}, true),
		tall.merged({"kind": "drop"}, true),
		tall.merged({"to": Vector2(length * 0.5, 0)}, true),
	]:
		results.append(PostFxState.new().fall(event))
	check(
		results == [true, false, false, false],
		"a sim fall_land event earns the fringe only as a tall, real topple: %s" % [results]
	)


func _check_fringe_shape() -> void:
	var fringe: Dictionary = _cfg()["fringe"]
	var seconds := Num.f(fringe["seconds"])
	var state := PostFxState.new()
	state.stomp(100.0)
	var frames := 0
	var peak := 0.0
	var peak_at := 0
	var last_on := 0
	for i: int in 60:
		state.update(FRAME, 1.0, 1.0)
		if state.fringe_px > 0.0:
			frames += 1
			last_on = i
		if state.fringe_px > peak:
			peak = state.fringe_px
			peak_at = i
	var length := frames * FRAME
	check(
		seconds <= MAX_FRINGE_SECONDS and length <= MAX_FRINGE_SECONDS + FRAME and frames > 4,
		(
			"the fringe lasts %.2f s (%d frames at 60 fps), at most %.2f s"
			% [length, frames, MAX_FRINGE_SECONDS]
		)
	)
	check(
		peak > 0.0 and peak <= Num.f(fringe["peak_px"]) + 0.001 and peak_at < last_on,
		(
			"it rises to its peak (%.1f px at 1080 lines, frame %d) and falls away after"
			% [peak, peak_at]
		)
	)
	check(
		state.fringe_px == 0.0 and not state.fringe_on(),
		"it is gone afterwards: %.2f px" % state.fringe_px
	)


func _check_cooldown_and_share() -> void:
	var fringe: Dictionary = _cfg()["fringe"]
	var cooldown := Num.f(fringe["cooldown_s"])
	var state := PostFxState.new()
	var first := state.stomp(100.0)
	_run_for(state, cooldown * 0.5)
	var early := state.stomp(100.0)
	_run_for(state, cooldown * 0.5 + 0.1)
	var late := state.stomp(100.0)
	check(
		first and not early and late,
		(
			"a second big hit inside the %.1f s cooldown is refused, after it accepted (%s %s %s)"
			% [cooldown, first, early, late]
		)
	)
	# The biggest stomper there is, stomping every 0.7 s for a minute: the fringe stays rare.
	var rapid := PostFxState.new()
	var on_frames := 0
	var total := 0
	for i: int in roundi(60.0 / FRAME):
		if i % roundi(0.7 / FRAME) == 0:
			rapid.stomp(100.0)
		rapid.update(FRAME, 1.0, 1.0)
		total += 1
		on_frames += 1 if rapid.fringe_px > 0.0 else 0
	var share := float(on_frames) / float(total)
	check(
		share > 0.0 and share < 0.08,
		(
			"stomping flat out for a minute shows the fringe %.1f%% of the time (never always on)"
			% (share * 100.0)
		)
	)


func _check_motion_setting() -> void:
	var state := PostFxState.new()
	state.stomp(100.0)
	var off := _run_for(state, 0.3, 1.0, 0.0)
	var full := PostFxState.new()
	full.stomp(100.0)
	var on := _run_for(full, 0.3, 1.0, 1.0)
	check(
		off == 0.0 and on > 0.0,
		"a 0%% camera-motion setting shows no fringe (%.1f vs %.1f px)" % [off, on]
	)


## A real rampage: the vignette rect is on screen under the HUD, a wide stomp lands a fringe on
## the second rect, low health turns the vignette red in the shader, and PostFx.enabled = false
## draws nothing.
func _check_rampage() -> void:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 0
	)
	root.add_child(rampage)
	for _i: int in 30:
		await process_frame
	var fx: PostFx = rampage.find_children("*", "PostFx", true, false)[0]
	var rects := fx.rects()
	var hud: CanvasLayer = rampage._hud
	check(
		fx.is_inside_tree() and fx.layer < hud.layer and rects[0].visible and not rects[1].visible,
		(
			"the vignette is up and the fringe rect hidden in play; PostFx layer %d under the HUD's %d"
			% [fx.layer, hud.layer]
		)
	)
	var calm := Num.f((rects[0].material as ShaderMaterial).get_shader_parameter("red_alpha"))
	rampage.sim.stats["stomp_radius"] = 100.0  # a stomp as wide as the widest earns the fringe
	rampage._stomp_radius = 100.0
	rampage._stomp_wait = 0.5
	rampage._on_footfall("left", 1.0, Vector3.ZERO)
	await process_frame
	await process_frame
	var split := Num.f((rects[1].material as ShaderMaterial).get_shader_parameter("amount_px"))
	check(
		rects[1].visible and split > 0.0,
		"a wide stomp's footfall shows the fringe rect (%.1f px)" % split
	)
	rampage.sim.hp = rampage.sim.max_hp * 0.05
	for _i: int in 90:
		await process_frame
	var peak := 0.0
	for _i: int in 60:  # a beat every 0.77 s: a second of frames holds one
		await process_frame
		peak = maxf(
			peak, Num.f((rects[0].material as ShaderMaterial).get_shader_parameter("red_alpha"))
		)
	check(
		calm == 0.0 and peak > 0.1 and not rects[1].visible,
		(
			"low health beats the live red edge (%.2f to %.2f) and the fringe is long gone"
			% [calm, peak]
		)
	)
	PostFx.enabled = false
	await process_frame
	var hidden := not rects[0].visible and not rects[1].visible
	PostFx.enabled = true
	check(hidden, "with PostFx.enabled off neither rect is drawn")
	rampage.free()
