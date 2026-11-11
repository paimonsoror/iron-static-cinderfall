class_name LookDevRound
extends RefCounted
## Rounded hard-surface boxes for the Warden v3 (W3-C round 3). A rounded box has no sharp edge and no sharp corner: every
## edge is a quarter cylinder and every corner an eighth of a sphere of radius `radius`, built from a grid whose vertices are
## the projection of a cube grid onto the rounded shape. The normal of every vertex is the analytic normal of that shape
## (exactly the face normal on the flat parts and rolling smoothly through the round parts), so light slides over an edge
## instead of snapping. Plates, pauldron layers, the helmet, the chest and the boots use it where the old chamfered
## `LookDevShapes.bevel_box` (one 45 degree strip, flat corners) read as hard edges.
## Triangles: 108 for `cuts` 0 (two 45 degree facets per quarter circle), 300 for `cuts` 1 (see `triangle_count`). The
## vertex alpha (edge wear) is 1 on the round parts and 0 on the flat faces.

const MIN_RADIUS: float = 0.004


## A box of `size` placed by `xform`. `radius` is clamped to 98 percent of the smallest half size. `taper` scales the +Y face
## in X and Z (a frustum with round edges). `cuts` adds more facets per quarter circle (0: two, 1: four).
static func rounded_box(
	mb: MeshBuilder, size: Vector3, xform: Transform3D, mat_id: StringName, radius: float = 0.03,
	taper: Vector2 = Vector2.ONE, cuts: int = 0
) -> void:
	var _part: int = mb.begin_part()
	var h: Vector3 = size * 0.5
	var r: float = clampf(radius, MIN_RADIUS, minf(minf(h.x, h.y), h.z) * 0.98)
	var inner: Vector3 = h - Vector3(r, r, r)
	var fr: PackedFloat32Array = _fractions(cuts)
	var half: int = fr.size()
	var n: int = half * 2
	var lines: Array[PackedFloat32Array] = []
	for axis: int in 3:
		var line: PackedFloat32Array = PackedFloat32Array()
		for m: int in n:
			if m < half:
				line.append(-(inner[axis] + fr[half - 1 - m] * r))
			else:
				line.append(inner[axis] + fr[m - half] * r)
		lines.append(line)
	for axis: int in 3:
		var b: int = (axis + 1) % 3
		var c: int = (axis + 2) % 3
		for side: int in [0, n - 1]:
			for p: int in n - 1:
				for q: int in n - 1:
					var ids: Array[Vector3i] = []
					for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
						var id: Vector3i = Vector3i.ZERO
						id[axis] = side
						id[b] = p + corner.x
						id[c] = q + corner.y
						ids.append(id)
					var v: Array[Array] = []
					for id: Vector3i in ids:
						v.append(_vertex(lines, id, inner, r, h, taper))
					_tri(mb, mat_id, xform, v[0], v[1], v[2])
					_tri(mb, mat_id, xform, v[0], v[2], v[3])
	_occluders(mb, size, xform)


## Triangles of a `rounded_box` with `cuts` extra facets: 6 faces of (2 * (cuts + 2) - 1) ^ 2 quads.
static func triangle_count(cuts: int = 0) -> int:
	var cells: int = 2 * (cuts + 2) - 1
	return 6 * cells * cells * 2


## Vertex [position, normal, wear] of grid vertex `id`.
static func _vertex(lines: Array[PackedFloat32Array], id: Vector3i, inner: Vector3, r: float, h: Vector3, taper: Vector2) -> Array:
	var p0: Vector3 = Vector3(lines[0][id.x], lines[1][id.y], lines[2][id.z])
	var base: Vector3 = Vector3(
		clampf(p0.x, -inner.x, inner.x), clampf(p0.y, -inner.y, inner.y), clampf(p0.z, -inner.z, inner.z)
	)
	var d: Vector3 = p0 - base
	var nrm: Vector3 = d.normalized()
	var pos: Vector3 = base + nrm * r
	var round_axes: int = 0
	for axis: int in 3:
		if absf(d[axis]) > 0.000001:
			round_axes += 1
	var wear: float = 1.0 if round_axes >= 2 else 0.0
	if taper != Vector2.ONE:
		var u: float = (pos.y / h.y + 1.0) * 0.5
		var sx: float = lerpf(1.0, taper.x, u)
		var sz: float = lerpf(1.0, taper.y, u)
		var dsx: float = (taper.x - 1.0) / (2.0 * h.y)
		var dsz: float = (taper.y - 1.0) / (2.0 * h.y)
		var jac: Basis = Basis(Vector3(sx, 0.0, 0.0), Vector3(pos.x * dsx, 1.0, pos.z * dsz), Vector3(0.0, 0.0, sz))
		nrm = (jac.inverse().transposed() * nrm).normalized()
		pos = Vector3(pos.x * sx, pos.y, pos.z * sz)
	return [pos, nrm, wear]


static func _tri(mb: MeshBuilder, mat_id: StringName, xf: Transform3D, a: Array, b: Array, c: Array) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	if (pb - pa).cross(pc - pa).length_squared() < 0.0000000001:
		return  # a degenerate cell (the radius reaches the half size)
	var na: Vector3 = a[1]
	var nb: Vector3 = b[1]
	var nc: Vector3 = c[1]
	var wa: float = a[2]
	var wb: float = b[2]
	var wc: float = c[2]
	var wear: Vector3 = Vector3(wa, wb, wc)
	mb.add_tri(mat_id, xf, pa, pb, pc, na, nb, nc, wear)


## tan of the facet angles over the 45 degrees a face grid covers: 0 and 1 for two facets per quarter circle.
static func _fractions(cuts: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var steps: int = maxi(cuts, 0) + 1
	for k: int in steps + 1:
		out.append(tan(PI * 0.25 * float(k) / float(steps)))
	return out


static func _occluders(mb: MeshBuilder, size: Vector3, xform: Transform3D) -> void:
	var axis_i: int = 0
	if size.y > size[axis_i]:
		axis_i = 1
	if size.z > size[axis_i]:
		axis_i = 2
	var longest: float = size[axis_i]
	var r: float = 0.5 * sqrt(size[(axis_i + 1) % 3] * size[(axis_i + 2) % 3])
	var count: int = clampi(roundi(longest / maxf(2.0 * r, 0.001)), 1, 5)
	for i: int in count:
		var local: Vector3 = Vector3.ZERO
		local[axis_i] = ((float(i) + 0.5) / float(count) - 0.5) * longest
		mb.add_occluder(xform * local, r)
