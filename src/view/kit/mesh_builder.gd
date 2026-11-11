class_name MeshBuilder
extends RefCounted
## Merges primitives into ONE ArrayMesh with one surface per distinct material (ARCH 8).
## Primitives are centered on their local origin; `xform` places them. Winding is resolved from the
## intended outward normal, so a primitive can never come out inside-out.
## Conventions: box/prism/sphere centered; cylinder along Y; prism has a triangular section in XY with
## the apex at +Y, extruded along Z; quad lies in the local XZ plane facing +Y (size.y = Z extent).


class Surf:
	extends RefCounted
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var idx: PackedInt32Array = PackedInt32Array()


var _order: Array[StringName] = []
var _surfs: Dictionary = {}  ## StringName -> Surf


func box(size: Vector3, xform: Transform3D, mat_id: StringName) -> MeshBuilder:
	var h: Vector3 = size * 0.5
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for a: int in 3:
		var n: Vector3 = axes[a]
		var t: Vector3 = axes[(a + 1) % 3]
		var b: Vector3 = axes[(a + 2) % 3]
		var he_n: float = absf(n.dot(h))
		var he_t: float = absf(t.dot(h))
		var he_b: float = absf(b.dot(h))
		for sign_n: float in [1.0, -1.0]:
			var c: Vector3 = n * (he_n * sign_n)
			_quad4(
				mat_id, xform, n * sign_n,
				c - t * he_t - b * he_b, c + t * he_t - b * he_b, c + t * he_t + b * he_b, c - t * he_t + b * he_b
			)
	return self


func cylinder(
	radius_top: float, radius_bottom: float, height: float, sides: int, xform: Transform3D, mat_id: StringName
) -> MeshBuilder:
	var n_sides: int = maxi(3, sides)
	var hy: float = height * 0.5
	for i: int in n_sides:
		var a0: float = TAU * float(i) / float(n_sides)
		var a1: float = TAU * float(i + 1) / float(n_sides)
		var r0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
		var r1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
		var b0: Vector3 = r0 * radius_bottom + Vector3(0.0, -hy, 0.0)
		var b1: Vector3 = r1 * radius_bottom + Vector3(0.0, -hy, 0.0)
		var t0: Vector3 = r0 * radius_top + Vector3(0.0, hy, 0.0)
		var t1: Vector3 = r1 * radius_top + Vector3(0.0, hy, 0.0)
		var n0: Vector3 = (r0 * height + Vector3.UP * (radius_bottom - radius_top)).normalized()
		var n1: Vector3 = (r1 * height + Vector3.UP * (radius_bottom - radius_top)).normalized()
		if radius_top <= 0.0:
			_tri(mat_id, xform, b0, b1, t0, n0, n1, n0)
		elif radius_bottom <= 0.0:
			_tri(mat_id, xform, b0, t1, t0, n0, n1, n0)
		else:
			_tri(mat_id, xform, b0, b1, t1, n0, n1, n1)
			_tri(mat_id, xform, b0, t1, t0, n0, n1, n0)
		if radius_top > 0.0:
			_tri(mat_id, xform, Vector3(0.0, hy, 0.0), t0, t1, Vector3.UP, Vector3.UP, Vector3.UP)
		if radius_bottom > 0.0:
			_tri(mat_id, xform, Vector3(0.0, -hy, 0.0), b0, b1, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	return self


func prism(size: Vector3, xform: Transform3D, mat_id: StringName) -> MeshBuilder:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var bl: Vector3 = Vector3(-hx, -hy, 0.0)
	var br: Vector3 = Vector3(hx, -hy, 0.0)
	var ap: Vector3 = Vector3(0.0, hy, 0.0)
	var zf: Vector3 = Vector3(0.0, 0.0, hz)
	var zb: Vector3 = Vector3(0.0, 0.0, -hz)
	_tri(mat_id, xform, bl + zf, br + zf, ap + zf, Vector3.BACK, Vector3.BACK, Vector3.BACK)
	_tri(mat_id, xform, bl + zb, br + zb, ap + zb, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD)
	_quad4(mat_id, xform, Vector3.DOWN, bl + zf, br + zf, br + zb, bl + zb)
	var nl: Vector3 = Vector3(-size.y, size.x * 0.5, 0.0).normalized()
	var nr: Vector3 = Vector3(size.y, size.x * 0.5, 0.0).normalized()
	_quad4(mat_id, xform, nl, bl + zf, ap + zf, ap + zb, bl + zb)
	_quad4(mat_id, xform, nr, br + zf, ap + zf, ap + zb, br + zb)
	return self


func sphere(radius: float, segments: int, xform: Transform3D, mat_id: StringName) -> MeshBuilder:
	var lon: int = maxi(3, segments)
	var rings: int = maxi(2, (lon + 1) >> 1)
	for r: int in rings:
		for i: int in lon:
			var pa: Vector3 = _sph(r, i, rings, lon)
			var pb: Vector3 = _sph(r, i + 1, rings, lon)
			var pc: Vector3 = _sph(r + 1, i + 1, rings, lon)
			var pd: Vector3 = _sph(r + 1, i, rings, lon)
			if r > 0:
				_tri(mat_id, xform, pa * radius, pb * radius, pc * radius, pa, pb, pc)
			if r < rings - 1:
				_tri(mat_id, xform, pa * radius, pc * radius, pd * radius, pa, pc, pd)
	return self


func quad(size: Vector2, xform: Transform3D, mat_id: StringName) -> MeshBuilder:
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	_quad4(
		mat_id, xform, Vector3.UP,
		Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz), Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz)
	)
	return self


## One ArrayMesh; one surface per distinct material, in order of first use, material already set.
func build() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for mat_id: StringName in _order:
		var s: Surf = _surfs[mat_id]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.norms
		arrays[Mesh.ARRAY_INDEX] = s.idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, MatLib.mat(mat_id))
	return mesh


## Triangles added so far (for budgets and tests).
func triangle_count() -> int:
	var n: int = 0
	for s_key: StringName in _order:
		var s: Surf = _surfs[s_key]
		n += floori(float(s.idx.size()) / 3.0)
	return n


static func _sph(ring: int, i: int, rings: int, lon: int) -> Vector3:
	var theta: float = PI * float(ring) / float(rings)
	var phi: float = TAU * float(i) / float(lon)
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


func _surf(mat_id: StringName) -> Surf:
	if not _surfs.has(mat_id):
		_surfs[mat_id] = Surf.new()
		_order.append(mat_id)
	var s: Surf = _surfs[mat_id]
	return s


func _quad4(mat_id: StringName, xf: Transform3D, n: Vector3, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_tri(mat_id, xf, p0, p1, p2, n, n, n)
	_tri(mat_id, xf, p0, p2, p3, n, n, n)


func _tri(
	mat_id: StringName, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3
) -> void:
	var s: Surf = _surf(mat_id)
	var wa: Vector3 = xf * a
	var wb: Vector3 = xf * b
	var wc: Vector3 = xf * c
	var wna: Vector3 = (xf.basis * na).normalized()
	var wnb: Vector3 = (xf.basis * nb).normalized()
	var wnc: Vector3 = (xf.basis * nc).normalized()
	var base: int = s.verts.size()
	s.verts.append(wa)
	s.verts.append(wb)
	s.verts.append(wc)
	s.norms.append(wna)
	s.norms.append(wnb)
	s.norms.append(wnc)
	# Godot front faces are clockwise: flip when the triangle is counter-clockwise seen from outside.
	var face: Vector3 = (wb - wa).cross(wc - wa)
	if face.dot(wna + wnb + wnc) > 0.0:
		s.idx.append_array(PackedInt32Array([base, base + 2, base + 1]))
	else:
		s.idx.append_array(PackedInt32Array([base, base + 1, base + 2]))
