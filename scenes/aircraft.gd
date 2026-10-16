class_name Aircraft
extends Node3D
## A few aircraft crossing the evening sky far off: blinking navigation lights, nothing more.
## Presentation only; part of CitySkyline.

var _rng: RandomNumberGenerator
var _planes: Array[Node3D] = []
var _clock := 0.0


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func _ready() -> void:
	_aircraft()


func _process(delta: float) -> void:
	_clock += delta
	for plane: Node3D in _planes:
		var speed := Num.f(plane.get_meta("speed"))
		plane.position += plane.basis.z * -speed * delta
		if absf(plane.position.x) > 900.0:
			plane.position.x = -signf(plane.position.x) * 880.0
		var light: MeshInstance3D = plane.get_child(0)
		light.visible = fposmod(_clock + Num.f(plane.get_meta("phase")), 1.4) < 0.18


func _aircraft() -> void:
	var red := CityView.glow(Color(1.0, 0.2, 0.15), 8.0)
	var white := CityView.glow(Color(1.0, 0.95, 0.85), 8.0)
	for i: int in 3:
		var plane := Node3D.new()
		plane.position = Vector3(
			_rng.randf_range(-600, 600), _rng.randf_range(90, 150), -200 - i * 160
		)
		plane.rotation.y = PI * 0.5 if i % 2 == 0 else -PI * 0.5
		plane.set_meta("speed", _rng.randf_range(18.0, 30.0))
		plane.set_meta("phase", _rng.randf())
		var light := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.8
		mesh.height = 1.6
		mesh.material = red if i % 2 == 0 else white
		light.mesh = mesh
		light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plane.add_child(light)
		add_child(plane)
		_planes.append(plane)
