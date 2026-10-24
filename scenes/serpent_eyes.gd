class_name SerpentEyes
extends Node3D
## The cobra's eyes (director 2026-10-24: "the snakes eyes being comic white dots is also very
## ugly"): two dark glossy eyes, eye_size m across (x head_scale, about a fifth of the head's width
## as on a real cobra), set into the sides of the head on the ring eye_at m behind the snout so only
## a low cap stands out, each under a slight brow scale a shade darker than the head. Near-black
## with a small specular glint, never a pale disc. Placed by SerpentTube.build; presentation only.

const EYE := Color("120d08")
const BROW := Color("6b8530")
## Where on the head ring each eye sits: a share of the half width out and of the half height up.
const OUT := 0.82
const UP := 0.55
## How far into the head each eye's centre sits (share of its radius): a low dome shows.
const INSET := 0.4
## The brow scale: its size (x the eye: across, thick, along), how far above and toward the middle
## of the head it sits from the eye's centre (x the eye), so from the high camera it only lids the
## eye's inner rim, and how far it is sunk into the head (x the eye).
const BROW_SIZE := Vector3(0.7, 0.22, 1.2)
const BROW_UP := 0.25
const BROW_IN := 0.45
const BROW_SINK := 0.1

var _cfg: Dictionary
var _eyes: Array[MeshInstance3D] = []
var _brows: Array[MeshInstance3D] = []


func _init(cfg: Dictionary) -> void:
	_cfg = cfg
	name = "SerpentEyes"
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = EYE
	eye_mat.roughness = 0.25
	eye_mat.metallic_specular = 0.5
	var brow_mat := StandardMaterial3D.new()
	brow_mat.albedo_color = BROW
	brow_mat.roughness = 0.6
	for _i: int in 2:
		_eyes.append(_ball(eye_mat))
		_brows.append(_ball(brow_mat))


## Lays both eyes on the head ring `mid` (`frame`: its side, up and way; `size`: its width, height).
func place(mid: Vector3, frame: Basis, size: Vector2) -> void:
	var ball := Num.f(_cfg["eye_size"]) * Num.f(_cfg["head_scale"])
	for e: int in 2:
		var sign := 1.0 if e == 0 else -1.0
		var rx := size.x * 0.5
		var ry := size.y * 0.5
		var skin := mid + frame.x * (rx * OUT * sign) + frame.y * (ry * UP)
		var out := frame.x * (OUT * sign / maxf(rx, 0.01)) + frame.y * (UP / maxf(ry, 0.01))
		out = out.normalized()
		var at := skin - out * (ball * 0.5 * INSET)
		_eyes[e].transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * ball), at)
		var brow_at := skin + frame.y * (ball * BROW_UP) - frame.x * (ball * BROW_IN * sign)
		brow_at -= out * (ball * BROW_SINK)
		var lie := Basis(frame.x, frame.y, frame.z).orthonormalized()
		_brows[e].transform = Transform3D(lie.scaled_local(BROW_SIZE * ball), brow_at)


## A small ball (1 m across, scaled when placed) with `mat`, casting no shadow (raised, a speckle).
func _ball(mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
