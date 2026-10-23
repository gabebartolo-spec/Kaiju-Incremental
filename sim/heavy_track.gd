class_name HeavyTrack
extends RefCounted
## A heavy kaiju's drawn poses as the sim reads them (D-208): the .ktrack file baked from the clips
## the game draws (tools/capture/bake_heavy_tracks.gd). Per clip frame: every slot of the body (a
## piece of one bone's voxels) in body space at body scale 1, as the hull of an upright disc at its
## lowest point and one at its highest (a leaning, tapering column: a slanted shin or a domed back
## does not fill its square corners), SLOT values; the jaw's slots again with the maw held open;
## every bone's head [forward, across, height]; the hind toes; the root bone's turn (a quaternion,
## x100); and which hind feet the clip has down.
## Read once per file and shared; pure, no randomness.

const MAGIC := "KTRK"
const VERSION := 2
## Values per slot: [forward, across to the right, radius at its bottom, lowest, highest, forward,
## across, radius at its top] (the bottom disc's centre first, the top disc's after).
const SLOT := 8
static var _cache := {}

## The clip meta ClipClock takes: {"fps", "clips": {name: [frames, loops]}, "spans": {...}}.
var meta := {}
var bones: Array[String] = []
## Each slot's bone (an index into bones), and how many slots the jaw has.
var slot_bone: Array[int] = []
var jaw_slots := 0
## The walk clip's first footfall frame and frames per step (ClipSteps), the hips' forward offset
## and height over the ground (rig units), walk cycles in the walk clip.
var walk_land := 0.0
var step_frames := 1.0
var hips := 0.0
var hip_height := 1.0
## One walk cycle's length (rig units) and walk clip frames a foot is in the air each cycle
## (ClipSteps.swing_frames): a lifted foot's way back to its clip path (FootSwing).
var stride := 1.0
var swing_frames := 1.0
## The claw rake's reach as the bake drew it (BipedSwing.youth).
var youth := 0.0
## Each hind leg's length, thigh plus shin, the two apart, and its rest knee side (rig units/axes).
var legs: Array[float] = []
var leg_parts: Array[Vector2] = []
var leg_poles: Array[Vector3] = []
## The claw rake's arms: "p" / "n" (the side it rakes, + / -) -> that arm's bone names.
var rake_arms := {}
var _clips := {}  # name -> [first frame, frames, fps, loops]
var _raw := PackedByteArray()
var _data_at := 0
var _per_frame := 0  # values per frame


## The track for a rig kind ("reptilian_adult"), or null when it has none.
static func of(kind: String) -> HeavyTrack:
	if _cache.has(kind):
		var known: HeavyTrack = _cache[kind]
		return known
	var path := "res://assets/kaiju/%s.ktrack" % kind
	var track: HeavyTrack = null
	if FileAccess.file_exists(path):
		track = HeavyTrack.new()
		if not track._load(FileAccess.get_file_as_bytes(path)):
			push_warning("HeavyTrack: %s is not a track file" % path)
			track = null
	_cache[kind] = track
	return track


func _load(raw: PackedByteArray) -> bool:
	if raw.size() < 12 or raw.slice(0, 4).get_string_from_ascii() != MAGIC:
		return false
	if raw.decode_u32(4) != VERSION:
		return false
	var length := raw.decode_u32(8)
	var parsed: Variant = JSON.parse_string(raw.slice(12, 12 + length).get_string_from_utf8())
	if not parsed is Dictionary:
		return false
	var header: Dictionary = parsed
	for b: Variant in header["bones"]:
		bones.append(str(b))
	for b: Variant in header["slot_bones"]:
		slot_bone.append(Num.i(b))
	jaw_slots = Num.i(header["jaw_slots"])
	var walk: Array = header["walk"]
	walk_land = Num.f(walk[0])
	step_frames = Num.f(walk[1])
	hips = Num.f(header["hips"])
	hip_height = Num.f(header["hip_height"])
	stride = Num.f(header["stride"])
	swing_frames = Num.f(header["swing_frames"])
	rake_arms = header["rake_arms"]
	youth = Num.f(header["youth"])
	for leg: Array in header["legs"]:
		legs.append(Num.f(leg[0]) + Num.f(leg[1]))
		leg_parts.append(Vector2(Num.f(leg[0]), Num.f(leg[1])))
		leg_poles.append(Vector3(Num.f(leg[2]), Num.f(leg[3]), Num.f(leg[4])))
	_per_frame = (slot_bone.size() + jaw_slots) * SLOT + bones.size() * 3 + legs.size() * 3 + 4 + 1
	var clips := {}
	var total := 0
	for c: Dictionary in header["clips"]:
		var row := [Num.i(c["first"]), Num.i(c["frames"]), Num.f(c["fps"]), c["loop"] == true]
		_clips[str(c["name"])] = row
		clips[str(c["name"])] = [row[1], row[3]]
		total = maxi(total, Num.i(row[0]) + Num.i(row[1]))
	meta = {"fps": Num.f(_clips["idle"][2]), "clips": clips, "spans": header["spans"]}
	_raw = raw
	_data_at = 12 + length
	return raw.size() == _data_at + total * _per_frame * 2


func has_clip(clip: String) -> bool:
	return _clips.has(clip)


## Frames a clip holds, and its frame rate.
func frames_of(clip: String) -> int:
	return Num.i(_clips[clip][1])


func fps_of(clip: String) -> float:
	return Num.f(_clips[clip][2])


## The walk clip's frame at the sim's step clock (ClipSteps.frame_at): footfalls on integers.
func walk_frame(phase: float) -> float:
	return fposmod(walk_land + phase * step_frames, float(frames_of("walk")))


## The two stored frames either side of time t (frames; a looped clip wraps, others hold their
## ends) and the weight of the second: Vector3(first index, second index, weight).
func frames_at(clip: String, t: float) -> Vector3:
	var c: Array = _clips[clip]
	var n := Num.i(c[1])
	var at := fposmod(t, n) if c[3] else clampf(t, 0.0, n - 1)
	var i0 := floori(at)
	var i1 := (i0 + 1) % n if c[3] else mini(i0 + 1, n - 1)
	return Vector3(Num.i(c[0]) + i0, Num.i(c[0]) + i1, at - i0)


## Value k of stored frame `frame` (body scale 1 units).
func value(frame: int, k: int) -> float:
	return _raw.decode_s16(_data_at + (frame * _per_frame + k) * 2) * 0.01


## Where slot j's SLOT values start in a frame; the jaw's open slots follow the slots.
func slot_at(j: int) -> int:
	return j * SLOT


func open_at(n: int) -> int:
	return (slot_bone.size() + n) * SLOT


## Where bone b's head starts in a frame; then hind toe i's; then the planted bits.
func head_at(b: int) -> int:
	return (slot_bone.size() + jaw_slots) * SLOT + b * 3


func toe_at(i: int) -> int:
	return head_at(bones.size()) + i * 3


## The hind feet the clip has down at stored frame `frame` (bit 0 left, bit 1 right).
func planted(frame: int) -> int:
	return roundi(value(frame, _per_frame - 1) * 100.0)
