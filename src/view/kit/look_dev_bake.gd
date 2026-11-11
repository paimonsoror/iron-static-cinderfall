class_name LookDevBake
extends RefCounted
## Bakes ambient occlusion and gradients into the vertex colours of a MeshBuilder (W3-C), at build time and once per
## mesh: no extra draw calls, no per-frame cost. The AO is analytic: every vertex is darkened by the occluder spheres
## (registered by LookDevShapes) of the OTHER shapes that sit in front of its normal and within `reach`, so creases
## between armour plates, under the helmet, between the arm and the chest and behind the pack get dark. Two global
## terms follow: a sky term (faces turned down are darker) and a ground contact term (feet and boots near y = 0).
## The result multiplies the vertex tint: rgb stays within 0..1; the alpha (edge wear) is not touched.


## Darkens the vertex colours of every surface except those in `skip` (emissive parts keep their full tint).
## `ground_y` is the height of the mesh origin above the ground (a torso built around the waist passes 0.92).
static func ao(
	mb: MeshBuilder, strength: float = 0.75, reach: float = 0.14, sky: float = 0.25, ground_y: float = 0.0,
	foot_dark: float = 0.4, foot_h: float = 0.3, skip: Array[StringName] = []
) -> void:
	mb.use_colors = true
	var ids: Array[int] = []
	var centres: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var members: Array[PackedInt32Array] = []
	for j: int in mb.occ_c.size():
		var o: int = mb.occ_o[j]
		var g: int = ids.find(o)
		if g < 0:
			g = ids.size()
			ids.append(o)
			members.append(PackedInt32Array())
		members[g].append(j)
	for g: int in ids.size():
		var mean: Vector3 = Vector3.ZERO
		for j: int in members[g]:
			mean += mb.occ_c[j]
		mean /= float(members[g].size())
		var far: float = 0.0
		for j: int in members[g]:
			far = maxf(far, mean.distance_to(mb.occ_c[j]) + mb.occ_r[j])
		centres.append(mean)
		radii.append(far + reach)
	for mat_id: StringName in mb.surface_ids():
		if skip.has(mat_id):
			continue
		var s: MeshBuilder.Surf = mb.surface_of(mat_id)
		for i: int in s.verts.size():
			var p: Vector3 = s.verts[i]
			var n: Vector3 = s.norms[i]
			var mine: int = s.own[i]
			var occ: float = 0.0
			for g: int in ids.size():
				if ids[g] == mine:
					continue
				var reach_g: float = radii[g]
				if centres[g].distance_squared_to(p) > reach_g * reach_g:
					continue
				for j: int in members[g]:
					var d: Vector3 = mb.occ_c[j] - p
					var rj: float = mb.occ_r[j]
					var limit: float = rj + reach
					var d2: float = d.length_squared()
					if d2 > limit * limit:
						continue
					var dist: float = sqrt(d2)
					var facing: float = n.dot(d) / maxf(dist, 0.0001)
					if facing <= 0.0:
						continue
					var seen: float = minf(1.0, rj * rj / maxf(d2, 0.0001))
					occ += seen * facing * (1.0 - smoothstep(rj, limit, dist))
			var k: float = 1.0 - strength * minf(occ, 1.0)
			k *= lerpf(1.0 - sky, 1.0, n.y * 0.5 + 0.5)
			k *= lerpf(foot_dark, 1.0, smoothstep(0.0, foot_h, p.y + ground_y))
			var c: Color = s.cols[i]
			s.cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)


## Multiplies the vertex colours by a vertical ramp: `dark` at height `y_from`, `light` at `y_to` (meters above the
## ground, using `ground_y` as the height of the mesh origin), clamped outside.
static func gradient_y(
	mb: MeshBuilder, y_from: float, y_to: float, dark: float, light: float, ground_y: float = 0.0,
	skip: Array[StringName] = []
) -> void:
	mb.use_colors = true
	var span: float = maxf(y_to - y_from, 0.0001)
	for mat_id: StringName in mb.surface_ids():
		if skip.has(mat_id):
			continue
		var s: MeshBuilder.Surf = mb.surface_of(mat_id)
		for i: int in s.verts.size():
			var t: float = clampf((s.verts[i].y + ground_y - y_from) / span, 0.0, 1.0)
			var k: float = lerpf(dark, light, t)
			var c: Color = s.cols[i]
			s.cols[i] = Color(c.r * k, c.g * k, c.b * k, c.a)
