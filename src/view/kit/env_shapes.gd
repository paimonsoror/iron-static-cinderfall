class_name EnvShapes
extends RefCounted
## Shapes of the gritty yard (W3-E) that the hard-surface kit does not have, written into a MeshBuilder with explicit normals and a
## colour per vertex (baked paint, rust and grime: the vertex colour IS the albedo, so the shapes need no texture and no extra material).
## Conventions as MeshBuilder: the builder must have `use_colors` set; `xf` places the shape; winding is resolved from the normals.

const RUST: Color = Color(0.32, 0.15, 0.07)
## The surface slots of a styled prop mesh: the ids are existing MatLib ids (a mesh needs a known id per surface); `EnvMat.bind` swaps
## the real materials in by surface name.
const PAINT: StringName = &"steel_grey"  ## vertex-coloured paint (EnvMat.prop)
const AMBER: StringName = &"emit_amber"  ## lit windows and panels (EnvMat.emit)
const CYAN: StringName = &"emit_cyan"


## The linear vertex colour of a palette material (MatLib id) scaled in value by `k`; the alpha (edge wear) is 0.
static func paint(id: StringName, k: float = 1.0) -> Color:
	var c: Color = MatLib.mat(id).albedo_color
	return Color(c.r * k, c.g * k, c.b * k, 0.0).srgb_to_linear()


## The teal variant of the container paint: the palette cyan sunk into the obsidian.
static func teal(k: float = 1.0) -> Color:
	var c: Color = MatLib.mat(&"emit_cyan").albedo_color.lerp(MatLib.mat(&"dark_frame").albedo_color, 0.66)
	return Color(c.r * k, c.g * k, c.b * k, 0.0).srgb_to_linear()


## Finishes a styled prop builder: vertex colours on, surfaces named by their slot id.
static func finish(mb: MeshBuilder) -> ArrayMesh:
	mb.use_colors = true
	var mesh: ArrayMesh = mb.build()
	var ids: Array[StringName] = mb.surface_ids()
	for i: int in ids.size():
		mesh.surface_set_name(i, String(ids[i]))
	return mesh


## One triangle with a colour per vertex. The vertex alpha is the edge wear (0 here).
static func tri(
	mb: MeshBuilder, mat_id: StringName, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, n: Vector3,
	ca: Color, cb: Color, cc: Color
) -> void:
	mb.add_tri(mat_id, xf, a, b, c, n, n, n)
	var s: MeshBuilder.Surf = mb.surface_of(mat_id)
	var last: int = s.cols.size()
	s.cols[last - 3] = ca
	s.cols[last - 2] = cb
	s.cols[last - 1] = cc


## A quad (a, b, c, d in a loop) with one normal and a colour per corner.
static func quad(
	mb: MeshBuilder, mat_id: StringName, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
	ca: Color, cb: Color, cc: Color, cd: Color
) -> void:
	tri(mb, mat_id, xf, a, b, c, n, ca, cb, cc)
	tri(mb, mat_id, xf, a, c, d, n, ca, cc, cd)


## A flat quad of one colour.
static func flat(
	mb: MeshBuilder, mat_id: StringName, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color
) -> void:
	quad(mb, mat_id, xf, a, b, c, d, n, col, col, col, col)


## A wall of trapezoid corrugation (the ribs of a shipping container): the ridges lie in the local plane z = 0 facing +Z, the valleys
## sit `depth` behind it. It spans x in [-length/2, length/2] and y in [0, height] with `periods` ribs; the valleys are darkened
## (baked ambient occlusion) and the colour runs through `rows` (colours at the heights `ys`, a vertical gradient: rust at the foot).
static func corrugated(
	mb: MeshBuilder, mat_id: StringName, xf: Transform3D, length: float, height: float, depth: float, periods: int,
	ys: PackedFloat32Array, rows: Array[Color], valley_dark: float = 0.72, jitter: float = 0.0, salt: int = 0
) -> void:
	var p: float = length / float(periods)
	var fx: PackedFloat32Array = PackedFloat32Array([0.0, 0.3, 0.5, 0.8, 1.0])
	var fz: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, -depth, -depth, 0.0])
	var slope: float = 0.2 * p
	var n_down: Vector3 = Vector3(depth, 0.0, slope).normalized()
	var n_up: Vector3 = Vector3(-depth, 0.0, slope).normalized()
	var normals: Array[Vector3] = [Vector3.BACK, n_down, Vector3.BACK, n_up]
	for i: int in periods:
		var x0: float = -length * 0.5 + p * float(i)
		var kp: float = 1.0 + jitter * (_unit(salt, i) * 2.0 - 1.0)
		for s: int in 4:
			var xa: float = x0 + p * fx[s]
			var xb: float = x0 + p * fx[s + 1]
			var ka: float = 1.0 if fz[s] == 0.0 else valley_dark
			var kb: float = 1.0 if fz[s + 1] == 0.0 else valley_dark
			for r: int in rows.size() - 1:
				var ya: float = minf(ys[r], height)
				var yb: float = minf(ys[r + 1], height)
				var a: Vector3 = Vector3(xa, ya, fz[s])
				var b: Vector3 = Vector3(xb, ya, fz[s + 1])
				var c: Vector3 = Vector3(xb, yb, fz[s + 1])
				var d: Vector3 = Vector3(xa, yb, fz[s])
				quad(mb, mat_id, xf, a, b, c, d, normals[s], _k(rows[r], ka * kp), _k(rows[r], kb * kp), _k(rows[r + 1], kb * kp), _k(rows[r + 1], ka * kp))


## A convex profile (z, y points in a loop) extruded along local X by `length` (centred): the sides use the flat normal of each
## profile edge, the two ends are fans. The colour runs from `low` at y = 0 to `high` at the top of the profile.
static func extrude(
	mb: MeshBuilder, mat_id: StringName, xf: Transform3D, profile: PackedVector2Array, length: float, low: Color, high: Color
) -> void:
	var n: int = profile.size()
	var centre: Vector2 = Vector2.ZERO
	var top: float = 0.0001
	for pt: Vector2 in profile:
		centre += pt / float(n)
		top = maxf(top, pt.y)
	var hl: float = length * 0.5
	for i: int in n:
		var a2: Vector2 = profile[i]
		var b2: Vector2 = profile[(i + 1) % n]
		var edge: Vector2 = b2 - a2
		var out2: Vector2 = Vector2(edge.y, -edge.x).normalized()
		if out2.dot((a2 + b2) * 0.5 - centre) < 0.0:
			out2 = -out2
		var nrm: Vector3 = Vector3(0.0, out2.y, out2.x)
		var ca: Color = low.lerp(high, a2.y / top)
		var cb: Color = low.lerp(high, b2.y / top)
		quad(
			mb, mat_id, xf, Vector3(-hl, a2.y, a2.x), Vector3(hl, a2.y, a2.x), Vector3(hl, b2.y, b2.x), Vector3(-hl, b2.y, b2.x), nrm,
			ca, ca, cb, cb
		)
		for side: float in [-1.0, 1.0]:
			var cc: Color = low.lerp(high, centre.y / top)
			tri(
				mb, mat_id, xf, Vector3(side * hl, centre.y, centre.x), Vector3(side * hl, a2.y, a2.x), Vector3(side * hl, b2.y, b2.x),
				Vector3(side, 0.0, 0.0), cc, ca, cb
			)


## A colour scaled in value (rgb only).
static func _k(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## A deterministic value in 0..1 from two integers (per-rib dirt).
static func _unit(a: int, b: int) -> float:
	var h: int = (a * 374761393 + b * 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0
