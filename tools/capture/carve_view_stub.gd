extends Node3D
## CAPTURE ONLY, NOT SHIPPED: draws what still stands of a stub grid (WP4's region mesher stands
## in here), one mesh per region of 16 cells a side through CarveMesh, so the standing part and
## its falling islands are meshed alike and an island leaves no seam or pop at hand-over.
@warning_ignore_start("integer_division")

const REGION := 16

var site: CarveSite
var _regions: Dictionary = {}  # region -> MeshInstance3D


func _init(p_site: CarveSite) -> void:
	site = p_site


func build(grid: PackedByteArray) -> void:
	var n := (site.size + Vector3i.ONE * (REGION - 1)) / REGION
	for y: int in n.y:
		for z: int in n.z:
			for x: int in n.x:
				_remesh(grid, Vector3i(x, y, z))


## Remeshes every region that holds one of `cells` or borders it.
func touched(grid: PackedByteArray, cells: PackedInt32Array) -> void:
	var dirty := {}
	for i: int in cells:
		var c := site.cell(i)
		dirty[c / REGION] = true
		for step: Vector3i in CarveMesh.STEPS:
			var q := c + step
			if site.inside(q):
				dirty[q / REGION] = true
	for key: Vector3i in dirty:
		_remesh(grid, key)


func _remesh(grid: PackedByteArray, key: Vector3i) -> void:
	var own := PackedInt32Array()
	var mats := PackedByteArray()
	var lo := key * REGION
	for y: int in range(lo.y, mini(site.size.y, lo.y + REGION)):
		for z: int in range(lo.z, mini(site.size.z, lo.z + REGION)):
			for x: int in range(lo.x, mini(site.size.x, lo.x + REGION)):
				var i := site.index(Vector3i(x, y, z))
				if grid[i] != 0:
					own.append(i)
					mats.append(grid[i])
	var mesh := CarveMesh.build(site, own, mats, grid)
	var mi: MeshInstance3D = _regions.get(key)
	if mesh == null:
		if mi != null:
			mi.queue_free()
			_regions.erase(key)
		return
	if mi == null:
		mi = MeshInstance3D.new()
		add_child(mi)
		_regions[key] = mi
	mi.mesh = mesh
