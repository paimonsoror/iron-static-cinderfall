class_name ActorsRosterKit
extends RefCounted
## Helpers of the V4-R suites (`actors_roster_*`). Not a suite itself. `silhouette` rasterises a mesh the way the game camera sees it
## (orthographic, 50 degrees of pitch, the machine turned by `yaw` about Y) into a coarse mask in metres, so two machines can be compared
## at their real sizes; `plan` does the same from straight above (the weapons). Masks are aligned at the ground point of the mesh origin.

const CELL: float = 0.04
const SIZE: int = 200
const PITCH_DEG: float = 50.0


## The mask of `mesh` seen by the game camera with the machine turned by `yaw` (radians about Y; 0 = facing -Z, away from the camera).
static func silhouette(mesh: ArrayMesh, yaw: float) -> PackedByteArray:
	var pitch: float = deg_to_rad(PITCH_DEG)
	var rot: Basis = Basis(Vector3.UP, yaw)
	var out: PackedByteArray = PackedByteArray()
	out.resize(SIZE * SIZE)
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var pts: PackedVector2Array = PackedVector2Array()
		for v: Vector3 in verts:
			var p: Vector3 = rot * v
			pts.append(Vector2(p.x, p.y * cos(pitch) - p.z * sin(pitch)))
		for t: int in range(0, idx.size(), 3):
			_fill(out, pts[idx[t]], pts[idx[t + 1]], pts[idx[t + 2]], Vector2(float(SIZE) * 0.5, float(SIZE) * 0.72))
	return out


## The mask of `mesh` seen from straight above (x across, -z up the picture), aligned at its origin.
static func plan(mesh: ArrayMesh) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(SIZE * SIZE)
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var pts: PackedVector2Array = PackedVector2Array()
		for v: Vector3 in verts:
			pts.append(Vector2(v.x, -v.z))
		for t: int in range(0, idx.size(), 3):
			_fill(out, pts[idx[t]], pts[idx[t + 1]], pts[idx[t + 2]], Vector2(float(SIZE) * 0.5, float(SIZE) * 0.5))
	return out


static func area(mask: PackedByteArray) -> int:
	var n: int = 0
	for b: int in mask:
		n += b
	return n


## Intersection over union of two masks (0 = nothing in common, 1 = the same picture).
static func iou(a: PackedByteArray, b: PackedByteArray) -> float:
	var both: int = 0
	var either: int = 0
	for i: int in a.size():
		both += a[i] & b[i]
		either += a[i] | b[i]
	return float(both) / float(maxi(either, 1))


## The mask shifted so that its centroid sits in the middle of the picture, then scaled so that its area is `target` cells: the
## picture's shape without its size or place (a similarity test: two different machines must not be the same shape either).
static func shape(mask: PackedByteArray) -> PackedByteArray:
	var n: int = 0
	var cx: float = 0.0
	var cy: float = 0.0
	for i: int in mask.size():
		if mask[i] != 0:
			n += 1
			cx += float(i % SIZE)
			cy += float(floori(float(i) / float(SIZE)))
	var out: PackedByteArray = PackedByteArray()
	out.resize(SIZE * SIZE)
	if n == 0:
		return out
	cx /= float(n)
	cy /= float(n)
	var k: float = sqrt(2400.0 / float(n))  # every shape is drawn at an area of about 2,400 cells
	for y: int in SIZE:
		for x: int in SIZE:
			var sx: int = roundi(cx + (float(x) - float(SIZE) * 0.5) / k)
			var sy: int = roundi(cy + (float(y) - float(SIZE) * 0.5) / k)
			if sx >= 0 and sx < SIZE and sy >= 0 and sy < SIZE and mask[sy * SIZE + sx] != 0:
				out[y * SIZE + x] = 1
	return out


## Pixel width and height of the mask's bounding box in metres.
static func extent(mask: PackedByteArray) -> Vector2:
	var x0: int = SIZE
	var x1: int = -1
	var y0: int = SIZE
	var y1: int = -1
	for i: int in mask.size():
		if mask[i] != 0:
			var x: int = i % SIZE
			var y: int = floori(float(i) / float(SIZE))
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
	if x1 < 0:
		return Vector2.ZERO
	return Vector2(float(x1 - x0 + 1), float(y1 - y0 + 1)) * CELL


static func _fill(mask: PackedByteArray, a: Vector2, b: Vector2, c: Vector2, origin: Vector2) -> void:
	var pa: Vector2 = Vector2(origin.x + a.x / CELL, origin.y - a.y / CELL)
	var pb: Vector2 = Vector2(origin.x + b.x / CELL, origin.y - b.y / CELL)
	var pc: Vector2 = Vector2(origin.x + c.x / CELL, origin.y - c.y / CELL)
	var x0: int = maxi(floori(minf(pa.x, minf(pb.x, pc.x))), 0)
	var x1: int = mini(ceili(maxf(pa.x, maxf(pb.x, pc.x))), SIZE - 1)
	var y0: int = maxi(floori(minf(pa.y, minf(pb.y, pc.y))), 0)
	var y1: int = mini(ceili(maxf(pa.y, maxf(pb.y, pc.y))), SIZE - 1)
	var d: float = (pb.y - pc.y) * (pa.x - pc.x) + (pc.x - pb.x) * (pa.y - pc.y)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			if absf(d) < 0.000001:
				# a sliver: mark the cell when the bounding box is thinner than one cell
				mask[y * SIZE + x] = 1
				continue
			var w0: float = ((pb.y - pc.y) * (p.x - pc.x) + (pc.x - pb.x) * (p.y - pc.y)) / d
			var w1: float = ((pc.y - pa.y) * (p.x - pc.x) + (pa.x - pc.x) * (p.y - pc.y)) / d
			var w2: float = 1.0 - w0 - w1
			if w0 >= -0.01 and w1 >= -0.01 and w2 >= -0.01:
				mask[y * SIZE + x] = 1
