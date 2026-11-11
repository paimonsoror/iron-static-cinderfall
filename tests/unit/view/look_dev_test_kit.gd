class_name LookDevTestKit
extends RefCounted
## Helpers of the W3-C look-dev suites (`look_dev_*`). Not a suite itself.

const FNV_PRIME: int = 0x100000001b3
const FNV_BASIS: int = 0x4bf29ce484222325


## FNV-1a over a mesh: per surface the material name, vertices and normals (quantized to 0.1 mm) and the indices.
## Order matters, so a changed winding or vertex order changes the hash.
static func mesh_hash(mesh: Mesh) -> int:
	var h: int = FNV_BASIS
	for s: int in mesh.get_surface_count():
		var mat: Material = mesh.surface_get_material(s)
		var mat_name: String = ""
		if mat != null:
			mat_name = mat.resource_name
		for ch: int in mat_name.to_utf8_buffer():
			h = _mix(h, ch)
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for v: Vector3 in verts:
			h = _mix(h, roundi(v.x * 10000.0))
			h = _mix(h, roundi(v.y * 10000.0))
			h = _mix(h, roundi(v.z * 10000.0))
		for n: Vector3 in norms:
			h = _mix(h, roundi(n.x * 10000.0))
			h = _mix(h, roundi(n.y * 10000.0))
			h = _mix(h, roundi(n.z * 10000.0))
		for i: int in idx:
			h = _mix(h, i)
	return h


static func vertex_count(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		n += verts.size()
	return n


static func _mix(h: int, value: int) -> int:
	return ((h ^ (value & 0xFFFFFFFF)) * FNV_PRIME) & 0x7FFFFFFFFFFFFFFF


## Edge statistics of a mesh, welding vertices by position (0.1 mm). Every edge shared by exactly two triangles gives
##  - the facet angle: the angle between the two face normals (how sharp the geometry is there), and
##  - the crease: the angle between the vertex normals the two triangles carry at the shared vertices (how visible the edge
##    is in the shading: 0 when the two triangles share smooth normals).
## Returns {edges, hard, max_facet_smooth, max_crease}: the edge count, the number of edges with a crease above `crease_deg`,
## and the largest facet angle among the edges that are not hard (smooth-shaded edges).
static func edge_stats(mesh: Mesh, crease_deg: float = 20.0) -> Dictionary:
	var edges: int = 0
	var hard: int = 0
	var max_facet: float = 0.0
	var max_crease: float = 0.0
	for s: int in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var ids: Dictionary = {}
		var seen: Dictionary = {}  # edge key -> [face normal, normal at the low vertex, normal at the high vertex, lo, hi]
		for t: int in range(0, idx.size(), 3):
			var corner: Array[int] = []
			for k: int in 3:
				var v: Vector3 = verts[idx[t + k]]
				var key: Vector3i = Vector3i(roundi(v.x * 10000.0), roundi(v.y * 10000.0), roundi(v.z * 10000.0))
				if not ids.has(key):
					ids[key] = ids.size()
				var cid: int = ids[key]
				corner.append(cid)
			var fn: Vector3 = (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
			if fn.length_squared() < 0.0000000001:
				continue
			fn = fn.normalized()
			if fn.dot(norms[idx[t]] + norms[idx[t + 1]] + norms[idx[t + 2]]) < 0.0:
				fn = -fn
			for k: int in 3:
				var a: int = corner[k]
				var b: int = corner[(k + 1) % 3]
				var na: Vector3 = norms[idx[t + k]]
				var nb: Vector3 = norms[idx[t + (k + 1) % 3]]
				var lo: int = mini(a, b)
				var hi: int = maxi(a, b)
				var rec: Array = [fn, na if a == lo else nb, nb if a == lo else na]
				var ekey: int = lo * 1000003 + hi
				if not seen.has(ekey):
					seen[ekey] = rec
					continue
				var first: Array = seen[ekey]
				seen.erase(ekey)  # an edge is counted once; a third triangle on it starts a new record
				var f1: Vector3 = first[0]
				var l1: Vector3 = first[1]
				var h1: Vector3 = first[2]
				var l2: Vector3 = rec[1]
				var h2: Vector3 = rec[2]
				var facet: float = rad_to_deg(f1.angle_to(fn))
				var crease: float = rad_to_deg(maxf(l1.angle_to(l2), h1.angle_to(h2)))
				edges += 1
				max_crease = maxf(max_crease, crease)
				if crease > crease_deg:
					hard += 1
				else:
					max_facet = maxf(max_facet, facet)
	return {"edges": edges, "hard": hard, "max_facet_smooth": max_facet, "max_crease": max_crease}
