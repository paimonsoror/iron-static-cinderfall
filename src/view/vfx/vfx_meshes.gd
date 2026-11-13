class_name VfxMeshes
extends RefCounted
## Small procedural meshes for the VFX pools and the blob shadows. Every flat mesh lies in the XZ plane facing
## +Y with unit scale (radius 1, or 1 x 1 for the streak), so a pool scales it per instance. Materials come
## from MatLib; winding is resolved from the intended normal, like MeshBuilder.


static var _dimmed: Dictionary[String, StandardMaterial3D] = {}


## The MatLib material `mat_id`, or a shared copy with its alpha scaled by `scale` (used for Reduced Flash and for
## soft effects: per-instance transparency is ignored by the Mobile renderer, so dimming is a material, not a node flag).
static func material(mat_id: StringName, scale: float = 1.0) -> StandardMaterial3D:
	var base: StandardMaterial3D = MatLib.mat(mat_id)
	if scale >= 0.999:
		return base
	var key: String = "%s@%.2f" % [String(mat_id), scale]
	if _dimmed.has(key):
		return _dimmed[key]
	var copy: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	copy.albedo_color.a = base.albedo_color.a * scale
	_dimmed[key] = copy
	return copy


## Triangle fan, radius `radius`, `sides` triangles.
static func disc(radius: float, sides: int, mat_id: StringName) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_disc(radius, sides)
	return b.build([mat_id], 1.0)


## Ring: an outer band (inner radius `inner` of 1) in `outer_mat` and a thin white-hot band in `core_mat`.
static func ring(
	inner: float, sides: int, outer_mat: StringName, core_mat: StringName, scale: float = 1.0
) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_band(inner, 1.0, sides, 0)
	b.add_band(lerpf(inner, 1.0, 0.55), lerpf(inner, 1.0, 0.8), sides, 1)
	return b.build([outer_mat, core_mat], scale)


## Soft dust puff: three stacked discs (radius 1, 0.7, 0.4) of one additive material, so overlap reads as a gradient.
static func puff(mat_id: StringName, scale: float = 1.0) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_disc_to(1.0, 14, 0)
	b.add_disc_to(0.7, 14, 0)
	b.add_disc_to(0.4, 14, 0)
	return b.build([mat_id], scale)


## Four long spikes (radius 1) between four short ones (radius 0.55) and a bright core disc.
static func star(star_mat: StringName, core_mat: StringName, scale: float = 1.0) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_star(1.0, 0.22, 4, 0, 0.0)
	b.add_star(0.55, 0.18, 4, 0, PI * 0.25)
	b.add_disc_to(0.34, 8, 1)
	return b.build([star_mat, core_mat], scale)


## Kite-shaped streak, 1 wide and 1 long (long axis Z, pointed at both ends); used for tracers and sparks.
static func streak(mat_id: StringName) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.tri(0, Vector3(0.0, 0.0, -0.5), Vector3(-0.5, 0.0, -0.15), Vector3(0.5, 0.0, -0.15))
	b.tri(0, Vector3(-0.5, 0.0, -0.15), Vector3(0.0, 0.0, 0.5), Vector3(0.5, 0.0, -0.15))
	return b.build([mat_id], 1.0)


## Tracer ribbon, 1 wide and 1 long: a hexagon with pointed ends, so a stretched tracer keeps an even width.
static func tracer(mat_id: StringName) -> ArrayMesh:
	var b: Builder = Builder.new()
	var outline: Array[Vector3] = [
		Vector3(0.0, 0.0, -0.5), Vector3(0.5, 0.0, -0.4), Vector3(0.5, 0.0, 0.3),
		Vector3(0.0, 0.0, 0.5), Vector3(-0.5, 0.0, 0.3), Vector3(-0.5, 0.0, -0.4),
	]
	for i: int in outline.size():
		b.tri(0, Vector3.ZERO, outline[i], outline[(i + 1) % outline.size()])
	return b.build([mat_id], 1.0)


## Arc bolt ribbon, 1 wide and 1 long: the tracer hexagon in `outer_mat` with a core a third as wide in `core_mat` (V2-F; the pool draws
## it thin, so a friendly arc is always narrower than a danger decal).
static func bolt(outer_mat: StringName, core_mat: StringName, scale: float = 1.0) -> ArrayMesh:
	var b: Builder = Builder.new()
	var outline: Array[Vector3] = [
		Vector3(0.0, 0.0, -0.5), Vector3(0.5, 0.0, -0.4), Vector3(0.5, 0.0, 0.3),
		Vector3(0.0, 0.0, 0.5), Vector3(-0.5, 0.0, 0.3), Vector3(-0.5, 0.0, -0.4),
	]
	for layer: int in 2:
		var w: float = 1.0 if layer == 0 else 0.34
		for i: int in outline.size():
			var p: Vector3 = outline[i]
			var q: Vector3 = outline[(i + 1) % outline.size()]
			b.tri(layer, Vector3.ZERO, Vector3(p.x * w, 0.0, p.z), Vector3(q.x * w, 0.0, q.z))
	return b.build([outer_mat, core_mat], scale)


## The red ring under an elite (VARIETY_SPEC 5.2): a band of radius 1 with four chevrons pointing at the centre.
static func elite_ring(mat_id: StringName) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_band(0.84, 1.0, 28, 0)
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = Vector3(-sin(a), 0.0, cos(a))
		b.tri(0, dir * 0.84 + side * 0.13, dir * 0.84 - side * 0.13, dir * 0.58)
	return b.build([mat_id], 1.0)


## A filled disc of radius 1 with planar UVs (a texture is mapped 0..1 across the diameter): the red hatch of a danger decal.
static func hatch_disc(mat_id: StringName, sides: int = 32) -> ArrayMesh:
	return MeshKit.begin().disc(1.0, sides, Transform3D.IDENTITY, mat_id).build()


## The flash of a blast (V4-X): a soft glow of two stacked discs under four long spikes, one additive colour, and a white-hot core. Radius 1.
## Bigger and softer than `star`, so a small blast at the far edge of the yard still reads at phone size.
static func blast_flash(glow_mat: StringName, core_mat: StringName, scale: float = 1.0) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_disc_to(0.78, 16, 0)
	b.add_disc_to(0.5, 12, 0)
	b.add_star(1.0, 0.2, 4, 0, 0.0)
	b.add_disc_to(0.3, 10, 1)
	return b.build([glow_mat, core_mat], scale)


## Two long edge bars of a lane (half-length 1, half-width 1; each bar is `thick` of the half-width): a pool scales x by the half-length
## and z by the half-width (`VfxPool.Mode.STRIP`), so the bars stay a constant share of the width. The ends are open.
static func lane_frame(mat_id: StringName, thick: float = 0.14) -> ArrayMesh:
	var b: Builder = Builder.new()
	for side: float in [-1.0, 1.0]:
		var z0: float = side * (1.0 - thick)
		var z1: float = side
		b.tri(0, Vector3(-1.0, 0.0, z0), Vector3(-1.0, 0.0, z1), Vector3(1.0, 0.0, z1))
		b.tri(0, Vector3(-1.0, 0.0, z0), Vector3(1.0, 0.0, z1), Vector3(1.0, 0.0, z0))
	return b.build([mat_id], 1.0)


## A rectangle (half-extents 1) whose UVs run 0..aspect along X and 0..1 along Z, so the hatch texture (3 repeats per unit through the
## material) keeps square stripes on a band that is `aspect` times as long as it is wide.
static func hatch_strip(mat_id: StringName, aspect: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.0, -1.0), Vector3(1.0, 0.0, 1.0), Vector3(-1.0, 0.0, 1.0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(aspect, 0.0), Vector2(aspect, 1.0), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, VfxMeshes.material(mat_id))
	return mesh


## The cracks of a floor breach: `arms` jagged cracks from the centre to radius 1, each a ribbon of three segments that thins out.
static func cracks(mat_id: StringName, arms: int = 6, width: float = 0.07) -> ArrayMesh:
	var b: Builder = Builder.new()
	for k: int in arms:
		var base: float = TAU * float(k) / float(arms) + 0.3
		var prev: Vector3 = Vector3.ZERO
		for j: int in 3:
			var r: float = float(j + 1) / 3.0
			var wobble: float = (0.18 if (j + k) % 2 == 0 else -0.18) * (1.0 if j < 2 else 0.0)
			var dir: Vector3 = Vector3(cos(base + wobble), 0.0, sin(base + wobble))
			var next: Vector3 = dir * r
			var side: Vector3 = Vector3(-dir.z, 0.0, dir.x) * width * (1.0 - 0.28 * float(j))
			b.tri(0, prev - side, prev + side, next)
			prev = next
	return b.build([mat_id], 1.0)


## A scorch mark (V4-X): three overlapping dark blots (the black shadow material, so the middle where they overlap is darker) with a faint
## warm rim band. Radius about 1. Calm by design: it is the aftermath of a blast, not a signal.
static func scorch_mark(rim_scale: float = 0.3) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_disc_at(Vector3.ZERO, 1.0, 20, 0)
	b.add_disc_at(Vector3(0.32, 0.0, 0.18), 0.7, 14, 0)
	b.add_disc_at(Vector3(-0.28, 0.0, -0.3), 0.62, 14, 0)
	b.add_band(0.9, 1.0, 20, 1)
	var mesh: ArrayMesh = b.build([&"shadow_blob", &"add_amber"], 1.0)
	mesh.surface_set_material(1, VfxMeshes.material(&"add_amber", rim_scale))
	return mesh


## A ring of `dashes` arcs with gaps between them (radius 1, the band starts at `inner`): the ring of a ward or an aura. Dashed on purpose:
## the shrinking outline of a danger decal is solid, so the two never read alike (shape, not only colour). `duty` is the share of each
## period that is drawn.
static func dashed_ring(inner: float, dashes: int, duty: float, mat_id: StringName, scale: float = 1.0) -> ArrayMesh:
	var b: Builder = Builder.new()
	var step: float = TAU / float(dashes)
	for k: int in dashes:
		var a0: float = step * float(k)
		var a1: float = a0 + step * duty
		var d0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
		var d1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
		b.tri(0, d0 * inner, d0, d1)
		b.tri(0, d0 * inner, d1, d1 * inner)
	return b.build([mat_id], scale)


## A glowing ball (radius 1) of `glow_mat` with a smaller `core_mat` heart: a lobbed shell, a hornet, a spitter's bolt. A billboard in the pool.
static func orb(glow_mat: StringName, core_mat: StringName, scale: float = 1.0) -> ArrayMesh:
	var b: Builder = Builder.new()
	b.add_disc_to(1.0, 14, 0)
	b.add_disc_to(0.55, 10, 1)
	return b.build([glow_mat, core_mat], scale)


## Unit cube (debris).
static func cube(mat_id: StringName) -> ArrayMesh:
	return MeshKit.begin().box(Vector3.ONE, Transform3D.IDENTITY, mat_id).build()


## Unit sphere (shield dome).
static func dome(mat_id: StringName, segments: int) -> ArrayMesh:
	return MeshKit.begin().sphere(1.0, segments, Transform3D.IDENTITY, mat_id).build()


## Triangle count of a mesh (all surfaces).
static func triangles(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += floori(float(idx.size()) / 3.0)
	return n


## Accumulates flat triangles per surface.
class Builder:
	extends RefCounted
	var verts: Array[PackedVector3Array] = []
	var idx: Array[PackedInt32Array] = []

	func _surf(s: int) -> void:
		while verts.size() <= s:
			verts.append(PackedVector3Array())
			idx.append(PackedInt32Array())

	## Adds one triangle facing +Y (swaps the winding when needed).
	func tri(s: int, a: Vector3, b: Vector3, c: Vector3) -> void:
		_surf(s)
		var base: int = verts[s].size()
		verts[s].append(a)
		verts[s].append(b)
		verts[s].append(c)
		var face: Vector3 = (b - a).cross(c - a)
		if face.y > 0.0:
			idx[s].append_array(PackedInt32Array([base, base + 2, base + 1]))
		else:
			idx[s].append_array(PackedInt32Array([base, base + 1, base + 2]))

	func add_disc(radius: float, sides: int) -> void:
		add_disc_to(radius, sides, 0)

	func add_disc_to(radius: float, sides: int, s: int) -> void:
		add_disc_at(Vector3.ZERO, radius, sides, s)

	func add_disc_at(center: Vector3, radius: float, sides: int, s: int) -> void:
		for i: int in sides:
			var a0: float = TAU * float(i) / float(sides)
			var a1: float = TAU * float(i + 1) / float(sides)
			tri(s, center, center + Vector3(cos(a0), 0.0, sin(a0)) * radius, center + Vector3(cos(a1), 0.0, sin(a1)) * radius)

	func add_band(r_in: float, r_out: float, sides: int, s: int) -> void:
		for i: int in sides:
			var a0: float = TAU * float(i) / float(sides)
			var a1: float = TAU * float(i + 1) / float(sides)
			var d0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
			var d1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
			tri(s, d0 * r_in, d0 * r_out, d1 * r_out)
			tri(s, d0 * r_in, d1 * r_out, d1 * r_in)

	func add_star(r_out: float, r_in: float, points: int, s: int, phase: float) -> void:
		var n: int = points * 2
		for i: int in n:
			var a0: float = phase + TAU * float(i) / float(n)
			var a1: float = phase + TAU * float(i + 1) / float(n)
			var ra: float = r_out if i % 2 == 0 else r_in
			var rb: float = r_out if (i + 1) % 2 == 0 else r_in
			tri(s, Vector3.ZERO, Vector3(cos(a0), 0.0, sin(a0)) * ra, Vector3(cos(a1), 0.0, sin(a1)) * rb)

	func build(mat_ids: Array[StringName], scale: float) -> ArrayMesh:
		var mesh: ArrayMesh = ArrayMesh.new()
		for s: int in verts.size():
			var norms: PackedVector3Array = PackedVector3Array()
			norms.resize(verts[s].size())
			norms.fill(Vector3.UP)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts[s]
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_INDEX] = idx[s]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(s, VfxMeshes.material(mat_ids[s], scale))
		return mesh
