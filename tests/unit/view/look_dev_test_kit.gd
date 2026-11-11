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
