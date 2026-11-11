class_name LookDevShapes
extends RefCounted
## Hard-surface shapes for the stylised actors (W3-C): a chamfered box, smooth tapered limbs (optionally rounded),
## ellipsoids and domes, and curved armour plates. All write into a MeshBuilder with smooth normals, an edge wear
## mask in the vertex alpha (chamfers and corners = 1) and one occluder sphere set per shape for LookDevBake.
## Conventions as MeshBuilder: forward is -Z, `xform` / `frame` place the shape; winding is resolved by the builder.

## Cube topology: vertex id = x + 2 y + 4 z (a bit set = the + side); each face lists its four vertices in a loop.
const _FACES: Array = [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]]

static var _edges: Array = []  ## [vertex a, vertex b, face f, face g] x 12
static var _corners: Array = []  ## [vertex, face 1, face 2, face 3] x 8


## A chamfered box: 6 face quads, 12 chamfer strips and 8 corner triangles (44 triangles). `bevel` is the chamfer width
## in meters (clamped to 45 percent of the smallest side), `taper` scales the +Y face in X and Z (a frustum). `soft` 0 (the
## default since round 3) gives the chamfer strip the normals of the two faces at its two borders, so there is no shading
## crease at all and the highlight rolls across the strip; larger values lean the strip toward the neighbour face (a
## visible crease at the border, the round 1 look). With
## `closed` false the 8 corner triangles are left out (36 triangles): the pinholes are smaller than a centimeter, for
## small parts that are never seen up close (the open corners show as dark notches: prefer `plate`). With `plate` true
## the -Y face is left out, together with its four chamfers and corners, and the side faces run down to the bottom
## edge: a shell that sits on the body (30 triangles).
static func bevel_box(
	mb: MeshBuilder, size: Vector3, xform: Transform3D, mat_id: StringName, bevel: float = 0.02,
	taper: Vector2 = Vector2.ONE, soft: float = 0.0, closed: bool = true, plate: bool = false
) -> void:
	_topology()
	var _part: int = mb.begin_part()
	var h: Vector3 = size * 0.5
	var corner: Array[Vector3] = []
	for v: int in 8:
		var sx: float = 1.0 if (v & 1) != 0 else -1.0
		var sy: float = 1.0 if (v & 2) != 0 else -1.0
		var sz: float = 1.0 if (v & 4) != 0 else -1.0
		var sc: Vector2 = Vector2.ONE.lerp(taper, (sy + 1.0) * 0.5)
		corner.append(Vector3(sx * h.x * sc.x, sy * h.y, sz * h.z * sc.y))
	var b: float = clampf(bevel, 0.002, minf(minf(size.x, size.y), size.z) * 0.45)
	var mix_k: float = clampf(soft, 0.0, 1.0) * 0.6
	var ins: Array[PackedVector3Array] = []
	var nrm: Array[Vector3] = []
	for f: int in 6:
		var loop: Array = _FACES[f]
		var q: Array[Vector3] = []
		var centre: Vector3 = Vector3.ZERO
		for k: int in 4:
			var vid: int = loop[k]
			q.append(corner[vid])
			centre += corner[vid] * 0.25
		var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
		if n.dot(centre) < 0.0:
			n = -n
		nrm.append(n)
		var pts: PackedVector3Array = PackedVector3Array()
		for k: int in 4:
			var prev: Vector3 = q[(k + 3) % 4]
			var next: Vector3 = q[(k + 1) % 4]
			var inset: Vector3 = q[k] + b * ((prev - q[k]).normalized() + (next - q[k]).normalized())
			var vk: int = loop[k]
			if plate and f != 2 and f != 3 and (vk & 2) == 0:
				inset.y = q[k].y  # a plate's side faces run down to the bottom edge
			pts.append(inset)
		ins.append(pts)
		if plate and f == 2:
			continue
		mb.add_tri(mat_id, xform, pts[0], pts[1], pts[2], n, n, n)
		mb.add_tri(mat_id, xform, pts[0], pts[2], pts[3], n, n, n)
	var wear: Vector3 = Vector3.ONE
	for rec: Array in _edges:
		var va: int = rec[0]
		var vb: int = rec[1]
		var f: int = rec[2]
		var g: int = rec[3]
		if plate and (f == 2 or g == 2):
			continue
		var fa: Vector3 = ins[f][_slot(f, va)]
		var fb: Vector3 = ins[f][_slot(f, vb)]
		var gb: Vector3 = ins[g][_slot(g, vb)]
		var ga: Vector3 = ins[g][_slot(g, va)]
		var nf: Vector3 = (nrm[f] * (1.0 - mix_k) + nrm[g] * mix_k).normalized()
		var ng: Vector3 = (nrm[g] * (1.0 - mix_k) + nrm[f] * mix_k).normalized()
		mb.add_tri(mat_id, xform, fa, fb, gb, nf, nf, ng, wear)
		mb.add_tri(mat_id, xform, fa, gb, ga, nf, ng, ng, wear)
	for rec: Array in _corners:
		if not closed:
			break
		var vid: int = rec[0]
		if plate and (vid & 2) == 0:
			continue
		var pts3: Array[Vector3] = []
		var ns: Array[Vector3] = []
		var sum: Vector3 = Vector3.ZERO
		for j: int in 3:
			var fj: int = rec[j + 1]
			pts3.append(ins[fj][_slot(fj, vid)])
			sum += nrm[fj]
		for j: int in 3:
			var fj2: int = rec[j + 1]
			ns.append((nrm[fj2] * (1.0 - 2.0 * mix_k) + (sum - nrm[fj2]) * mix_k).normalized())
		mb.add_tri(mat_id, xform, pts3[0], pts3[1], pts3[2], ns[0], ns[1], ns[2], wear)
	_box_occluders(mb, size, xform)


## A smooth tapered tube from `a` to `b` (radius `ra` at a, `rb` at b) with `sides` facets, placed inside `frame`.
## `round_ends` 0 = flat caps, 1 = one rounded ring per end (a blunt dome). No cap at an end where `cap_a` / `cap_b`
## is false (a limb that disappears into armour).
static func limb(
	mb: MeshBuilder, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, mat_id: StringName,
	frame: Transform3D = Transform3D.IDENTITY, round_ends: int = 0, cap_a: bool = true, cap_b: bool = true
) -> void:
	var _part: int = mb.begin_part()
	var span: Vector3 = b - a
	var length: float = span.length()
	if length < 0.0001:
		return
	var axis: Vector3 = span / length
	var helper: Vector3 = Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var u: Vector3 = axis.cross(helper).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	var s_pos: PackedFloat32Array = PackedFloat32Array([0.0, length])
	var s_rad: PackedFloat32Array = PackedFloat32Array([ra, rb])
	if round_ends > 0:
		s_pos = PackedFloat32Array([-ra, -ra * 0.55, 0.0, length, length + rb * 0.55, length + rb])
		s_rad = PackedFloat32Array([0.0, ra * 0.82, ra, rb, rb * 0.82, 0.0])
	var n_rings: int = s_pos.size()
	var seg_n: Array[Vector2] = []  # (radial, axial) outward normal of the profile segment j -> j + 1
	for j: int in n_rings - 1:
		seg_n.append(Vector2(s_pos[j + 1] - s_pos[j], -(s_rad[j + 1] - s_rad[j])).normalized())
	var n_sides: int = maxi(3, sides)
	for j: int in n_rings - 1:
		var n0: Vector2 = seg_n[j]
		if j > 0:
			n0 = (seg_n[j - 1] + seg_n[j]).normalized()
		var n1: Vector2 = seg_n[j]
		if j + 1 < n_rings - 1:
			n1 = (seg_n[j] + seg_n[j + 1]).normalized()
		for i: int in n_sides:
			var t0: float = TAU * float(i) / float(n_sides)
			var t1: float = TAU * float(i + 1) / float(n_sides)
			var d0: Vector3 = u * cos(t0) + v * sin(t0)
			var d1: Vector3 = u * cos(t1) + v * sin(t1)
			var p00: Vector3 = a + axis * s_pos[j] + d0 * s_rad[j]
			var p01: Vector3 = a + axis * s_pos[j] + d1 * s_rad[j]
			var p10: Vector3 = a + axis * s_pos[j + 1] + d0 * s_rad[j + 1]
			var p11: Vector3 = a + axis * s_pos[j + 1] + d1 * s_rad[j + 1]
			var q00: Vector3 = d0 * n0.x + axis * n0.y
			var q01: Vector3 = d1 * n0.x + axis * n0.y
			var q10: Vector3 = d0 * n1.x + axis * n1.y
			var q11: Vector3 = d1 * n1.x + axis * n1.y
			if s_rad[j] > 0.0:
				mb.add_tri(mat_id, frame, p00, p01, p11, q00, q01, q11)
			if s_rad[j + 1] > 0.0:
				mb.add_tri(mat_id, frame, p00, p11, p10, q00, q11, q10)
	if round_ends == 0:
		for i: int in n_sides:
			var c0: float = TAU * float(i) / float(n_sides)
			var c1: float = TAU * float(i + 1) / float(n_sides)
			var e0: Vector3 = u * cos(c0) + v * sin(c0)
			var e1: Vector3 = u * cos(c1) + v * sin(c1)
			if cap_a:
				mb.add_tri(mat_id, frame, a, a + e1 * ra, a + e0 * ra, -axis, -axis, -axis)
			if cap_b:
				mb.add_tri(mat_id, frame, b, b + e0 * rb, b + e1 * rb, axis, axis, axis)
	var count: int = clampi(ceili(length / maxf(minf(ra, rb) * 1.6, 0.01)), 1, 6)
	for k: int in count:
		var t: float = (float(k) + 0.5) / float(count)
		mb.add_occluder(frame * (a + span * t), lerpf(ra, rb, t) * 0.95)


## An ellipsoid with radii `radii` (`upper_only` = the +Y half, open below: a pauldron, a helmet cap or a knee pad).
## `sides` facets around Y, `rings` latitude bands (per half when `upper_only`).
static func ellipsoid(
	mb: MeshBuilder, radii: Vector3, sides: int, rings: int, xform: Transform3D, mat_id: StringName,
	upper_only: bool = false
) -> void:
	var _part: int = mb.begin_part()
	var n_sides: int = maxi(3, sides)
	var bands: int = maxi(2, rings) * (1 if upper_only else 2)
	var sweep: float = PI * 0.5 if upper_only else PI
	for r: int in bands:
		var th0: float = sweep * float(r) / float(bands)
		var th1: float = sweep * float(r + 1) / float(bands)
		for i: int in n_sides:
			var ph0: float = TAU * float(i) / float(n_sides)
			var ph1: float = TAU * float(i + 1) / float(n_sides)
			var pa: Vector3 = _ell(radii, th0, ph0)
			var pb: Vector3 = _ell(radii, th0, ph1)
			var pc: Vector3 = _ell(radii, th1, ph1)
			var pd: Vector3 = _ell(radii, th1, ph0)
			var na: Vector3 = _ell_n(radii, th0, ph0)
			var nb: Vector3 = _ell_n(radii, th0, ph1)
			var nc: Vector3 = _ell_n(radii, th1, ph1)
			var nd: Vector3 = _ell_n(radii, th1, ph0)
			if r > 0:
				mb.add_tri(mat_id, xform, pa, pb, pc, na, nb, nc)
			if upper_only or r < bands - 1:
				mb.add_tri(mat_id, xform, pa, pc, pd, na, nc, nd)
	var mean: float = pow(radii.x * radii.y * radii.z, 1.0 / 3.0)
	var lift: float = radii.y * 0.3 if upper_only else 0.0
	mb.add_occluder(xform * Vector3(0.0, lift, 0.0), mean * 0.92)


## A curved armour plate: `width` along X (the arc length), `height` along Y, `thick` along the normal, bent by
## `bend` radians so the middle bulges toward -Z. `segs` columns. 6 * segs + 4 triangles (no inner surface).
static func curved_plate(
	mb: MeshBuilder, width: float, height: float, thick: float, bend: float, segs: int, xform: Transform3D,
	mat_id: StringName
) -> void:
	var _part: int = mb.begin_part()
	var n_seg: int = maxi(1, segs)
	var arc: float = maxf(absf(bend), 0.02)
	var radius: float = width / arc
	var hy: float = height * 0.5
	var outer: PackedVector3Array = PackedVector3Array()
	var inner: PackedVector3Array = PackedVector3Array()
	var dirs: PackedVector3Array = PackedVector3Array()
	for i: int in n_seg + 1:
		var th: float = -arc * 0.5 + arc * float(i) / float(n_seg)
		var d: Vector3 = Vector3(sin(th), 0.0, -cos(th))
		dirs.append(d)
		outer.append(Vector3(0.0, 0.0, radius) + d * radius)
		inner.append(Vector3(0.0, 0.0, radius) + d * (radius - thick))
	var up: Vector3 = Vector3(0.0, hy, 0.0)
	for i: int in n_seg:
		var o0: Vector3 = outer[i]
		var o1: Vector3 = outer[i + 1]
		var i0: Vector3 = inner[i]
		var i1: Vector3 = inner[i + 1]
		var d0: Vector3 = dirs[i]
		var d1: Vector3 = dirs[i + 1]
		mb.add_tri(mat_id, xform, o0 - up, o1 - up, o1 + up, d0, d1, d1)
		mb.add_tri(mat_id, xform, o0 - up, o1 + up, o0 + up, d0, d1, d0)
		mb.add_tri(mat_id, xform, o0 + up, o1 + up, i1 + up, Vector3.UP, Vector3.UP, Vector3.UP)
		mb.add_tri(mat_id, xform, o0 + up, i1 + up, i0 + up, Vector3.UP, Vector3.UP, Vector3.UP)
		mb.add_tri(mat_id, xform, o0 - up, i1 - up, o1 - up, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
		mb.add_tri(mat_id, xform, o0 - up, i0 - up, i1 - up, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	for end: int in [0, n_seg]:
		var side: float = -1.0 if end == 0 else 1.0
		var tangent: Vector3 = Vector3(dirs[end].z * -1.0, 0.0, dirs[end].x).normalized() * side
		mb.add_tri(mat_id, xform, outer[end] - up, outer[end] + up, inner[end] + up, tangent, tangent, tangent)
		mb.add_tri(mat_id, xform, outer[end] - up, inner[end] + up, inner[end] - up, tangent, tangent, tangent)
	var cols: int = clampi(ceili(float(n_seg) * 0.5), 1, 4)
	for k: int in cols:
		var at: int = roundi((float(k) + 0.5) / float(cols) * float(n_seg))
		mb.add_occluder(xform * ((outer[at] + inner[at]) * 0.5), minf(height, width / float(cols)) * 0.4)


## A frame whose -Z axis runs from `a` to `b` (so a box of depth |ab| lies along the segment), centered at the segment
## point `t` (0..1) and shifted by `offset` in that frame. +Y is `up` made perpendicular to the segment ("up" for a horizontal
## segment; pass Vector3.FORWARD for a leg so that +Y is the front of the limb whichever way the knee is bent).
static func frame_along(
	a: Vector3, b: Vector3, t: float = 0.5, offset: Vector3 = Vector3.ZERO, up: Vector3 = Vector3.UP
) -> Transform3D:
	var d: Vector3 = b - a
	var dir: Vector3 = d.normalized() if d.length() > 0.0001 else Vector3.FORWARD
	var up_hint: Vector3 = up if absf(dir.dot(up.normalized())) < 0.95 else Vector3.RIGHT
	var basis: Basis = Basis.looking_at(dir, up_hint)
	return Transform3D(basis, a.lerp(b, t) + basis * offset)


## A basis whose +Y axis points along `dir` (a dome or a plate that faces that way).
static func facing(dir: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, dir.normalized()))


static func _topology() -> void:
	if not _edges.is_empty():
		return
	var seen: Dictionary = {}
	for f: int in 6:
		var loop: Array = _FACES[f]
		for k: int in 4:
			var va: int = loop[k]
			var vb: int = loop[(k + 1) % 4]
			var key: int = mini(va, vb) * 8 + maxi(va, vb)
			if seen.has(key):
				var rec: Array = seen[key]
				rec.append(f)
			else:
				seen[key] = [va, vb, f]
	for key: int in seen.keys():
		_edges.append(seen[key])
	for vid: int in 8:
		var fs: Array = [vid]
		for f: int in 6:
			var loop2: Array = _FACES[f]
			if loop2.has(vid):
				fs.append(f)
		_corners.append(fs)


static func _slot(face: int, vertex: int) -> int:
	var loop: Array = _FACES[face]
	return loop.find(vertex)


static func _ell(radii: Vector3, theta: float, phi: float) -> Vector3:
	return Vector3(
		radii.x * sin(theta) * cos(phi), radii.y * cos(theta), radii.z * sin(theta) * sin(phi)
	)


static func _ell_n(radii: Vector3, theta: float, phi: float) -> Vector3:
	var p: Vector3 = _ell(radii, theta, phi)
	return Vector3(p.x / (radii.x * radii.x), p.y / (radii.y * radii.y), p.z / (radii.z * radii.z)).normalized()


static func _box_occluders(mb: MeshBuilder, size: Vector3, xform: Transform3D) -> void:
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
