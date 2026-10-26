class_name LandmarkSlowmo
extends Node
## Slow motion only when a landmark falls (D-259: "Only when a landmark falls"; the VIP kill and
## the end beat have none, D-243). When the sim reports `landmark_felled` (RunNews) the world slows
## to tuning "slowmo" scale for hold_s real seconds, then eases back to normal speed over ease_s.
## A second fall while it plays restarts the clock; it never stacks. Never during his death or the
## end beat.
##
## Presentation only, and the sim is never told. Engine.time_scale shrinks the delta every physics
## tick gets (the tick rate stays 60 a second), so a sim fed that delta would take smaller steps in
## the slowed window than it does at full speed. Rampage therefore asks `sim_dt` what to step the
## sim by: always a whole tick, on only as many ticks as the slowed clock has run. The sim sees the
## same steps in the same order with this on or off; the run just takes longer on the wall clock.
## The clock is counted in physics ticks (real seconds = tick delta over the time scale), not read
## from the machine's clock, so it is the same every replay.

## `time_scale` never goes below this, whatever the tuning says.
const FLOOR := 0.05
## A tick's owed time within this of a whole tick counts as a whole tick (float slack).
const OWED_SLACK := 1.0e-9

var sim: RampageSim
## The end beat's HUD: no slow motion starts while its beat runs, and one in play is cut short.
var hud: RampageHud
## False: a fall does nothing. Tests run the same rampage with and without to compare the sim.
var enabled := true
## Tuning "slowmo": scale (the speed it drops to), hold_s, ease_s.
var _cfg: Dictionary
var _read: Array[Dictionary] = []
## Real seconds the slow motion in play has run; negative when none is.
var _age := -1.0
## Sim time the slowed clock owes the sim, not yet stepped (s).
var _owed := 0.0
## Presses made on a tick the sim sat out, kept for its next step (the window the river's latch has).
var _waited := InputLatch.new(Num.f(Content.section("emerge")["input_latch_seconds"]))


func _init(p_sim: RampageSim, p_hud: RampageHud = null, tuning: Dictionary = {}) -> void:
	sim = p_sim
	hud = p_hud
	_cfg = tuning if not tuning.is_empty() else Content.section("slowmo")
	# The pause menu runs while paused; time must be whole behind it.
	process_mode = Node.PROCESS_MODE_ALWAYS


## The speed of the world `age` real seconds after a fall: the scale for hold_s, then eased back
## up to 1.0 over ease_s (smoothstep), then whole. Negative age: no slow motion.
static func speed_at(age: float, cfg: Dictionary) -> float:
	if age < 0.0:
		return 1.0
	var low := clampf(Num.f(cfg["scale"]), FLOOR, 1.0)
	var hold := maxf(0.0, Num.f(cfg["hold_s"]))
	var ease_s := maxf(0.0, Num.f(cfg["ease_s"]))
	if age < hold:
		return low
	if age >= hold + ease_s:
		return 1.0
	return lerpf(low, 1.0, smoothstep(0.0, 1.0, (age - hold) / ease_s))


## True while slow motion is in play.
func active() -> bool:
	return _age >= 0.0


## A landmark has fallen: slow the world now (a fall already playing starts over).
func trigger() -> void:
	if not enabled or _suppressed():
		return
	_age = 0.0
	_apply()


## Moves the slowed clock on by `real` seconds of real time.
func advance(real: float) -> void:
	if _age < 0.0:
		return
	if _suppressed():
		stop()
		return
	_age += real
	if _age >= Num.f(_cfg["hold_s"]) + Num.f(_cfg["ease_s"]):
		stop()
		return
	_apply()


## Back to normal speed now.
func stop() -> void:
	_age = -1.0
	_owed = 0.0
	Engine.time_scale = 1.0


## What to step the sim by this physics tick (`delta`, the tick's own, shrunk by the time scale):
## at full speed `delta`; while slowed one whole tick once the slowed clock has run one, else 0.0
## and the sim sits the tick out. The sim's step is never shortened.
func sim_dt(delta: float) -> float:
	if Engine.time_scale >= 1.0:
		_owed = 0.0
		return delta
	var whole := 1.0 / float(Engine.physics_ticks_per_second)
	_owed += delta
	if _owed + OWED_SLACK < whole:
		return 0.0
	_owed -= whole
	return whole


## A tick the sim sits out: the presses made on it wait for the next step (merge).
func sit_out(delta: float) -> void:
	var pressed := {}
	for action: String in ["signature", "ultimate", "dash"]:
		pressed[action] = Input.is_action_just_pressed(action)
	_waited.hold(pressed, delta)


## The step's own input `now` (RunInput.read) with the presses kept from the ticks the sim sat out.
func merge(now: Dictionary, dt: float) -> Dictionary:
	return _waited.through(false, now, dt)


func _apply() -> void:
	Engine.time_scale = speed_at(_age, _cfg)


## His death is playing (DeathOverload), the end beat is up, or the rampage is over: time stays
## whole, so the ending runs at the speed it was timed at.
func _suppressed() -> bool:
	return sim.over or sim.death.active() or (hud != null and hud.beat_running())


func _physics_process(delta: float) -> void:
	if get_tree().paused:  # the menu behind it runs at normal speed; the fall waits
		if active():
			Engine.time_scale = 1.0
		return
	var scale_then := Engine.time_scale  # this tick's delta was shrunk by this, before a new fall
	var events := sim.events
	if not is_same(events, _read):
		_read = events
		for event: Dictionary in events:
			if str(event.get("type", "")) == "landmark_felled":
				trigger()
	advance(delta / maxf(scale_then, FLOOR))


func _exit_tree() -> void:
	if active():
		Engine.time_scale = 1.0
