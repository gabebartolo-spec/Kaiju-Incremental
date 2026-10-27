class_name FxPool
extends Node3D
## Pre-built particle systems that are reused, not built and freed per burst (render plan item 8,
## tuning render_opt.fx_pool). Every dust puff, footfall, spark, blast burst and fire used to
## create a GPUParticles3D, duplicate its process material and free both a moment later: a small
## hitch each time. Here each kind has a fixed number of slots made once; a burst takes one,
## sets its per-burst values, restart()s it (so no stale particle shows) and gives it back when
## its particles are done (the `finished` signal, with a timer as the safety net).
## Two sorts of kind:
##   - material kinds (register): the slot owns ONE duplicate of the kind's base process
##     material and shares its mesh; a take puts the few values bursts change back to the base's.
##   - bare kinds (register_bare): the slot is an empty node; the caller gives it its own
##     material and mesh (a blast, a fire, a helicopter's smoke differ every time) and a host.
## When a kind has no free slot (or the flag is off) take returns null and the caller builds a
## system as before, so a burst is never dropped. Presentation only: what a system draws (its
## materials, meshes, colours) is untouched (D-190); visibility boxes are the callers' own.

## The node properties a user may change; each is put back to a fresh node's value on take.
const NODE_PROPS: Array[String] = [
	"one_shot",
	"explosiveness",
	"randomness",
	"preprocess",
	"fixed_fps",
	"speed_scale",
	"lifetime",
	"cast_shadow",
	"visibility_aabb",
	"local_coords",
	"draw_order",
]
## The process-material values the bursts change after taking a slot (Fx.dust, footfall, puff,
## tree_puff, _slam_puff); put back to the base material's on take.
const MAT_PROPS: Array[String] = [
	"emission_box_extents",
	"scale_min",
	"scale_max",
	"initial_velocity_min",
	"initial_velocity_max",
]
const FREE := 0
const BUSY := 1
const PARKING := 2

## The pool in use (the Fx node's), for the fire, blast and helicopter code that has no Fx.
static var shared: FxPool

## Whether pooling is on (tuning render_opt.fx_pool.enabled); tests switch it per pool.
var on := true
## Takes that found no free slot and used the old create path (tests, the bench).
var fallbacks := 0

var _kinds: Dictionary = {}  # kind -> {base, mesh, free: Array, out: Dictionary, count: int}
var _defaults := GPUParticles3D.new()


## True when render_opt.fx_pool.enabled is on (default on; a flag that is off needs a decision id).
## A bench turns it off with `--tune=render_opt.fx_pool=0` (a plain number in place of the table).
static func flag_on() -> bool:
	var entry: Variant = Content.section("render_opt").get("fx_pool", {})
	if typeof(entry) != TYPE_DICTIONARY:
		return Num.f(entry) != 0.0
	var cfg: Dictionary = entry
	return cfg.get("enabled", true) == true


## Slots per kind from tuning render_opt.fx_pool.slots (provisional until the bench's peak
## concurrency re-sizes them).
static func slots_for(kind: String, fallback: int) -> int:
	var entry: Variant = Content.section("render_opt").get("fx_pool", {})
	if typeof(entry) != TYPE_DICTIONARY:
		return fallback
	var cfg: Dictionary = entry
	var slots: Dictionary = cfg.get("slots", {})
	return Num.i(slots.get(kind, fallback))


## A slot of `kind` taken out of whichever pool is in use, detached (add it to its host), or null
## (no pool, flag off, kind unknown, no free slot). Fx takes its material kinds with acquire.
static func take(kind: String, amount: int) -> GPUParticles3D:
	if shared == null or not is_instance_valid(shared):
		return null
	var p := shared.acquire(kind, amount)
	if p != null and p.get_parent() == shared:
		shared.remove_child(p)
	return p


## Gives a taken slot back after `seconds` (or sooner when its particles finish). Call it once
## the slot is in the tree.
static func give_after(p: GPUParticles3D, seconds: float) -> void:
	p.get_tree().create_timer(seconds).timeout.connect(_timeout.bind(p.get_instance_id(), _gen(p)))


## Gives a taken slot back now; false when it is not a pool slot or there is no pool (the caller
## frees it).
static func give(p: Node) -> bool:
	if shared == null or not is_instance_valid(shared) or not p.has_meta("fx_gen"):
		return false
	shared.release(p as GPUParticles3D)
	return true


static func _gen(p: Node) -> int:
	return Num.i(p.get_meta("fx_gen", 0))


static func _timeout(id: int, gen: int) -> void:
	var p := instance_from_id(id) as GPUParticles3D
	if p == null or not is_instance_valid(p) or _gen(p) != gen:
		return  # freed, or already given back (and maybe taken again)
	if shared != null and is_instance_valid(shared):
		shared.release(p)
	else:
		p.queue_free()


func _enter_tree() -> void:
	shared = self
	on = flag_on()


func _exit_tree() -> void:
	if shared == self:
		shared = null
	if OS.get_cmdline_user_args().has("--fx-pool-report"):
		print(report())


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _defaults != null:
		_defaults.free()


## `count` slots of `kind`, each with its own duplicate of `base` and the shared `mesh`.
func register(kind: String, base: ParticleProcessMaterial, mesh: Mesh, count: int) -> void:
	_kinds[kind] = {"base": base, "mesh": mesh, "free": [], "out": {}, "count": count, "peak": 0}
	for i: int in count:
		_make(kind)


## `count` empty slots of `kind` (the caller sets material, mesh and host).
func register_bare(kind: String, count: int) -> void:
	_kinds[kind] = {"base": null, "mesh": null, "free": [], "out": {}, "count": count, "peak": 0}
	for i: int in count:
		_make(kind)


## A free slot of `kind` made ready (values back to the defaults, visible, not yet emitting), or
## null. Prefers a slot already sized for `amount` (changing a system's amount re-allocates its
## buffer). The caller sets its per-burst values, then calls restart().
func acquire(kind: String, amount: int) -> GPUParticles3D:
	if not on or not _kinds.has(kind):
		return null
	var k: Dictionary = _kinds[kind]
	var spare: Array = k["free"]
	if spare.is_empty():
		_replace_lost(kind)
	if spare.is_empty():
		fallbacks += 1
		return null
	var at := spare.size() - 1
	for i: int in spare.size():
		var candidate: GPUParticles3D = spare[i]
		if candidate.amount == amount:
			at = i
			break
	var p: GPUParticles3D = spare[at]
	spare[at] = spare[spare.size() - 1]
	spare.pop_back()
	var out := _out(kind)
	out[p.get_instance_id()] = true
	k["peak"] = maxi(Num.i(k["peak"]), out.size())
	_reset(p, k)
	p.set_meta("fx_state", BUSY)
	p.set_meta("fx_gen", _gen(p) + 1)
	p.visible = true
	return p


## Gives a slot back: it stops, hides and waits to be taken again. Safe to call twice.
func release(p: GPUParticles3D) -> void:
	if p == null or not is_instance_valid(p) or Num.i(p.get_meta("fx_state", FREE)) != BUSY:
		return
	p.set_meta("fx_gen", _gen(p) + 1)  # any timer still pending for the last take is void
	p.emitting = false
	p.visible = false
	p.amount_ratio = GraphicsPresets.cap("particles")  # an idle slot holds the run's cap, not more
	if p.get_parent() == self:
		_file(p)
	else:
		p.set_meta("fx_state", PARKING)
		_park.call_deferred(p)


## Slots of `kind` in use (tests).
func busy(kind: String) -> Array[GPUParticles3D]:
	var found: Array[GPUParticles3D] = []
	if not _kinds.has(kind):
		return found
	for id: Variant in _out(kind).keys():
		var p := instance_from_id(Num.i(id)) as GPUParticles3D
		if p != null and is_instance_valid(p) and Num.i(p.get_meta("fx_state", FREE)) == BUSY:
			found.append(p)
	return found


## Free slots of `kind` (tests, the bench).
func free_count(kind: String) -> int:
	if not _kinds.has(kind):
		return 0
	var k: Dictionary = _kinds[kind]
	var spare: Array = k["free"]
	return spare.size()


## The base process material and the mesh `kind` was registered with (the create path's).
func base_of(kind: String) -> ParticleProcessMaterial:
	var k: Dictionary = _kinds[kind]
	var base: ParticleProcessMaterial = k["base"]
	return base


func mesh_of(kind: String) -> Mesh:
	var k: Dictionary = _kinds[kind]
	var mesh: Mesh = k["mesh"]
	return mesh


## One line of the most slots in use at once per kind, the slots made and the takes that found
## none (the bench prints it with --fx-pool-report; it re-sizes render_opt.fx_pool.slots).
func report() -> String:
	var parts: PackedStringArray = []
	for kind: String in _kinds:
		var k: Dictionary = _kinds[kind]
		parts.append("%s=%d/%d" % [kind, Num.i(k["peak"]), Num.i(k["count"])])
	return "FXPOOL peak/slots %s fallbacks=%d" % [" ".join(parts), fallbacks]


## Slots made for `kind` (tests, the bench).
func slot_count(kind: String) -> int:
	if not _kinds.has(kind):
		return 0
	var k: Dictionary = _kinds[kind]
	return Num.i(k["count"])


func _out(kind: String) -> Dictionary:
	var k: Dictionary = _kinds[kind]
	var out: Dictionary = k["out"]
	return out


func _make(kind: String) -> void:
	var k: Dictionary = _kinds[kind]
	var p := GPUParticles3D.new()
	p.visible = false
	p.emitting = false
	if k["base"] != null:
		var base: ParticleProcessMaterial = k["base"]
		var mesh: Mesh = k["mesh"]
		p.process_material = base.duplicate()
		p.draw_pass_1 = mesh
	p.set_meta("fx_kind", kind)
	p.set_meta("fx_state", FREE)
	p.set_meta("fx_gen", 0)
	p.amount_ratio = GraphicsPresets.cap("particles")  # an idle slot holds the run's cap
	p.finished.connect(_on_finished.bind(p))
	add_child(p)
	var spare: Array = k["free"]
	spare.append(p)


## A slot lost to a host that was freed under it is made again, so the pool does not shrink.
func _replace_lost(kind: String) -> void:
	var k: Dictionary = _kinds[kind]
	var out := _out(kind)
	for id: Variant in out.keys():
		var gone := instance_from_id(Num.i(id))
		if gone == null or not is_instance_valid(gone):
			out.erase(id)
	var spare: Array = k["free"]
	if spare.size() + out.size() < Num.i(k["count"]):
		_make(kind)


func _on_finished(p: GPUParticles3D) -> void:
	release(p)


func _park(p: GPUParticles3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	if p.get_parent() != self:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		add_child(p)
	_file(p)


func _file(p: GPUParticles3D) -> void:
	p.set_meta("fx_state", FREE)
	var kind := str(p.get_meta("fx_kind"))
	var k: Dictionary = _kinds[kind]
	_out(kind).erase(p.get_instance_id())
	var spare: Array = k["free"]
	spare.append(p)


## Everything a user may have changed goes back: a stale value from the last burst never leaks.
func _reset(p: GPUParticles3D, k: Dictionary) -> void:
	for prop: String in NODE_PROPS:
		var want: Variant = _defaults.get(prop)
		if p.get(prop) != want:
			p.set(prop, want)
	p.amount_ratio = 1.0
	if k["base"] == null:
		return
	var base: ParticleProcessMaterial = k["base"]
	var mat := p.process_material as ParticleProcessMaterial
	for prop: String in MAT_PROPS:
		var want: Variant = base.get(prop)
		if mat.get(prop) != want:
			mat.set(prop, want)
	# A ramp the base has is put back (a tinted dust replaced it); one it has not is left, since
	# adding and removing a ramp would switch the material's shader variant every burst.
	if base.color_ramp != null and mat.color_ramp != base.color_ramp:
		mat.color_ramp = base.color_ramp
