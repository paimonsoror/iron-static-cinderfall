class_name LookActorsTestKit
extends RefCounted
## Helpers of the W3-D actor rollout suites (`look_actors_*`). Not a suite itself.

const STYLED: int = LookDevStyle.Look.STYLISED
const ENEMIES: Array[StringName] = [&"skitter", &"hollow_warden", &"rusher", &"siege_hulk"]


static func roles(mesh: ArrayMesh) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: int in mesh.get_surface_count():
		out.append(StringName(mesh.surface_get_material(s).resource_name))
	return out


static func surface_of(mesh: ArrayMesh, role: StringName) -> int:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s).resource_name == String(role):
			return s
	return -1


## The connected pieces of the `emit_red` surface (welded by position to 1 mm, then pieces whose boxes touch are merged, so the
## core of the optic and its halo band are one piece). Each is {center: Vector3, tint: float (the brightest vertex tint)}.
static func red_clusters(mesh: ArrayMesh) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: int = surface_of(mesh, &"emit_red")
	if s < 0:
		return out
	var arrays: Array = mesh.surface_get_arrays(s)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parent: PackedInt32Array = PackedInt32Array()
	for i: int in verts.size():
		parent.append(i)
	var weld: Dictionary = {}
	for i: int in verts.size():
		var key: Vector3i = Vector3i(roundi(verts[i].x * 1000.0), roundi(verts[i].y * 1000.0), roundi(verts[i].z * 1000.0))
		if weld.has(key):
			var twin: int = weld[key]
			_union(parent, i, twin)
		else:
			weld[key] = i
	for t: int in range(0, idx.size(), 3):
		_union(parent, idx[t], idx[t + 1])
		_union(parent, idx[t], idx[t + 2])
	var boxes: Dictionary = {}
	var tints: Dictionary = {}
	for i: int in verts.size():
		var root: int = _find(parent, i)
		var box: AABB = AABB(verts[i], Vector3.ZERO)
		if boxes.has(root):
			var prev: AABB = boxes[root]
			box = prev.expand(verts[i])
		boxes[root] = box
		var seen_tint: float = tints.get(root, 0.0)
		tints[root] = maxf(seen_tint, cols[i].r)
	var roots: Array = boxes.keys()
	var group: Dictionary = {}
	for a: int in roots:
		group[a] = a
	for a: int in roots:
		for b: int in roots:
			var box_a: AABB = boxes[a]
			var box_b: AABB = boxes[b]
			if box_a.grow(0.01).intersects(box_b):
				var ga: int = group[a]
				var gb: int = group[b]
				for k: int in roots:
					if group[k] == gb:
						group[k] = ga
	var merged: Dictionary = {}
	for r: int in roots:
		var g: int = group[r]
		var box_r: AABB = boxes[r]
		var tint_r: float = tints[r]
		if merged.has(g):
			var rec: Dictionary = merged[g]
			var box_g: AABB = rec["box"]
			var tint_g: float = rec["tint"]
			rec["box"] = box_g.merge(box_r)
			rec["tint"] = maxf(tint_g, tint_r)
		else:
			merged[g] = {"box": box_r, "tint": tint_r}
	for g: int in merged:
		var rec2: Dictionary = merged[g]
		var box2: AABB = rec2["box"]
		out.append({"center": box2.get_center(), "tint": rec2["tint"]})
	return out


## Luma of the vertex colours of a surface: {min, max, mean, sigma}.
static func luma_stats(mesh: ArrayMesh, s: int) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(s)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var lo: float = 1.0
	var hi: float = 0.0
	var sum: float = 0.0
	var sum2: float = 0.0
	for c: Color in cols:
		var l: float = c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
		lo = minf(lo, l)
		hi = maxf(hi, l)
		sum += l
		sum2 += l * l
	var n: float = maxf(float(cols.size()), 1.0)
	var mean: float = sum / n
	return {"min": lo, "max": hi, "mean": mean, "sigma": sqrt(maxf(sum2 / n - mean * mean, 0.0))}


static func _find(parent: PackedInt32Array, i: int) -> int:
	var r: int = i
	while parent[r] != r:
		r = parent[r]
	return r


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra != rb:
		parent[rb] = ra
