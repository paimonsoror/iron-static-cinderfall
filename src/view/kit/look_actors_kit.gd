class_name LookActorsKit
extends RefCounted
## Shared helpers of the hard-surface actor meshes of W3-D (turret, enemies, Hulk): colour plan, the single optic, a
## two-segment limb and the common finishing (ambient occlusion, weathering, optic light spill). Same frames as the rest
## of the kit: forward is -Z, feet at y = 0.
## Colour plan (value first, like the Warden): dark gunmetal frames (vertex value 0.1 to 0.5, lifted by the material
## gain), off-white weathered plates (0.55 to 1.0) and ONE red optic. The optic is an emissive band that follows the
## head and a dimmer, larger band under it that reads as its halo, in the same surface (no extra draw).

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const R: StringName = &"emit_red"
const L: StringName = &"emit_cyan"
const ID: Transform3D = Transform3D.IDENTITY
const SKIP_EMISSIVE: Array[StringName] = [R, L]


## Dark gunmetal tint, `k` is the value (a hint of cold blue so the frame is not brown next to the warm plates).
static func frame(k: float) -> Color:
	return Color(k * 0.94, k * 0.99, minf(k * 1.06, 1.0), 1.0)


## Off-white plate tint, `k` is the value: red and green pulled down so the warm palette bone reads as a neutral grey-white
## (like `LookDevWarden.BONE_TINT`), never cream or beige; the warm part of the mood comes from the shader's rim and bounce.
static func plate(k: float) -> Color:
	return Color(k * 0.86, k * 0.92, k, 1.0)


static func at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


## A tapered tube in two segments with a bend at `mid` (a leg or an arm): `ra` at a, `rm` at mid, `rb` at b.
static func limb2(
	mb: MeshBuilder, a: Vector3, mid: Vector3, b: Vector3, ra: float, rm: float, rb: float, sides: int, mat_id: StringName,
	xf: Transform3D = ID
) -> void:
	LookDevShapes.limb(mb, a, mid, ra, rm, sides, mat_id, xf, 0, true, false)
	LookDevShapes.limb(mb, mid, b, rm, rb, sides, mat_id, xf, 0, false, true)


## A cone (a spine, a spike, a claw tip): base radius `r` at `a`, a point at `b`.
static func cone(mb: MeshBuilder, a: Vector3, b: Vector3, r: float, sides: int, mat_id: StringName, xf: Transform3D = ID) -> void:
	LookDevShapes.limb(mb, a, b, r, 0.0, sides, mat_id, xf, 0, true, false)


## The single optic: a bright emissive band that follows an ellipsoid head of radii `radii` placed by `head`, spanning
## +-`half_deg` around the front (-Z), between the heights `y_lo` and `y_hi` (head space), turned about the head's X axis by
## `tilt` radians (positive raises the band toward the top, where the top-down camera sees it), plus a dim wider band under it
## (the halo).
## 2 * segs triangles for the core, the halo and the bezel each (about 36 together).
static func optic(
	mb: MeshBuilder, head: Transform3D, radii: Vector3, half_deg: float, y_lo: float, y_hi: float, tilt: float = 0.0,
	segs: int = 4, halo: float = 0.4
) -> void:
	var _part: int = mb.begin_part()
	var xf: Transform3D = head * Transform3D(Basis(Vector3.RIGHT, tilt), Vector3.ZERO)
	var grow: float = 0.045 * radii.y / 0.1
	mb.tint = frame(0.07)  # a dark bezel: the red reads against it whatever colour the head is
	_band(mb, xf, radii, deg_to_rad(half_deg + 22.0), y_lo - grow * 1.9, y_hi + grow * 1.9, segs + 2, 1.03, G)
	if halo > 0.0:
		mb.tint = Color(halo, halo, halo, 1.0)
		_band(mb, xf, radii, deg_to_rad(half_deg + 12.0), y_lo - grow, y_hi + grow, segs + 2, 1.05, R)
	mb.tint = Color.WHITE
	_band(mb, xf, radii, deg_to_rad(half_deg), y_lo, y_hi, segs, 1.075, R)


## The weathering and light of a finished actor: ambient occlusion from the occluder spheres of its shapes, dirt, chips and
## grime (LookActorsGrit), the red light spill of the optic at `optic_at`, then the mesh.
static func finish(
	mb: MeshBuilder, seed_i: int, height: float, optic_at: Vector3, plate_dirt: float = 0.55, frame_dirt: float = 0.4,
	ao_strength: float = 0.8, ao_reach: float = 0.12
) -> ArrayMesh:
	LookDevBake.ao(mb, ao_strength, ao_reach, 0.3, 0.0, 0.45, 0.12, SKIP_EMISSIVE)
	LookActorsGrit.bake(mb, seed_i, height, plate_dirt, frame_dirt, SKIP_EMISSIVE)
	LookActorsGrit.spill(mb, optic_at, height * 0.16, 0.45, SKIP_EMISSIVE)
	return mb.build()


## Largest horizontal distance from the origin of any vertex of a mesh (the footprint the sim reserves is a circle around it).
static func footprint_radius(mesh: Mesh) -> float:
	var r2: float = 0.0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			r2 = maxf(r2, v.x * v.x + v.z * v.z)
	return sqrt(r2)


static func _band(
	mb: MeshBuilder, xf: Transform3D, radii: Vector3, half: float, y_lo: float, y_hi: float, segs: int, offset: float,
	mat_id: StringName
) -> void:
	for i: int in segs:
		var t0: float = lerpf(-half, half, float(i) / float(segs))
		var t1: float = lerpf(-half, half, float(i + 1) / float(segs))
		var p00: Vector3 = _on_head(radii, t0, y_lo, offset)
		var p10: Vector3 = _on_head(radii, t1, y_lo, offset)
		var p01: Vector3 = _on_head(radii, t0, y_hi, offset)
		var p11: Vector3 = _on_head(radii, t1, y_hi, offset)
		var n0: Vector3 = _head_normal(radii, p00 / offset)
		var n1: Vector3 = _head_normal(radii, p10 / offset)
		var n2: Vector3 = _head_normal(radii, p01 / offset)
		var n3: Vector3 = _head_normal(radii, p11 / offset)
		mb.add_tri(mat_id, xf, p00, p10, p11, n0, n1, n3)
		mb.add_tri(mat_id, xf, p00, p11, p01, n0, n3, n2)


static func _on_head(radii: Vector3, theta: float, y: float, offset: float) -> Vector3:
	var yy: float = clampf(y / radii.y, -0.98, 0.98)
	var ring: float = sqrt(1.0 - yy * yy)
	return Vector3(radii.x * ring * sin(theta), y, -radii.z * ring * cos(theta)) * offset


static func _head_normal(radii: Vector3, p: Vector3) -> Vector3:
	return Vector3(p.x / (radii.x * radii.x), p.y / (radii.y * radii.y), p.z / (radii.z * radii.z)).normalized()
