extends RefCounted
## Where each continent's mission marker stands on the globe (GlobeView, D-418): from the
## landmass mask, per mask value, a texel well inside its area nearest the area's mean direction.

## Mask px between candidate anchors; an anchor's 8 neighbours this far away share its value.
const ANCHOR_STEP := 4


## Each mask value's anchor (index 0 the sea, 1..count the continents) as a unit-sphere point: the
## texel well inside its area (its 8 neighbours ANCHOR_STEP px away share it) nearest the area's
## mean direction, so an island chain's marker still stands on land. One pass over the mask.
static func anchors(mask: Image, count: int) -> Array[Vector3]:
	var w := mask.get_width()
	var h := mask.get_height()
	var px := mask.get_data()
	var means: Array[Vector3] = []
	var cands: Array[Array] = []
	for v in count + 1:
		means.append(Vector3.ZERO)
		cands.append([])
	var s := ANCHOR_STEP
	for y in range(s, h - s, s):
		for x in range(0, w, s):
			var v: int = px[y * w + x]
			if v > count:
				continue
			var p := GlobeView.point_of(_texel_uv(x, y, w, h))
			means[v] += p
			if _inside(px, x, y, w, v):
				cands[v].append(p)
	var out: Array[Vector3] = []
	for v in count + 1:
		out.append(_nearest(cands[v], means[v].normalized()))
	return out


## True when the 8 texels ANCHOR_STEP px round (x, y) all hold v; x wraps, y stays in range.
static func _inside(px: PackedByteArray, x: int, y: int, w: int, v: int) -> bool:
	var s := ANCHOR_STEP
	for dy: int in [-s, 0, s]:
		var row := (y + dy) * w
		for dx: int in [-s, 0, s]:
			if (dx != 0 or dy != 0) and px[row + posmod(x + dx, w)] != v:
				return false
	return true


## The point nearest dir (largest dot), or ZERO when there are none.
static func _nearest(points: Array, dir: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_dot := -2.0
	for p: Vector3 in points:
		if p.dot(dir) > best_dot:
			best_dot = p.dot(dir)
			best = p
	return best


static func _texel_uv(x: int, y: int, w: int, h: int) -> Vector2:
	return Vector2((x + 0.5) / w, (y + 0.5) / h)
