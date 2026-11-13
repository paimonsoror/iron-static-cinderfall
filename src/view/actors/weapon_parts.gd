class_name WeaponParts
extends RefCounted
## Shared pieces of the weapon models of V4-R (`WeaponMeshes2`, `WeaponMeshes3`): the colour plan (a grey value on gunmetal, the
## Warden's bone on ceramic, white on the one cyan accent), a placed transform, a tilted grip and a quad that faces the muzzle.
## Same frames as `WeaponMeshes`: the grip is near the origin, the barrel points to -Z, y is up.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
const ID: Transform3D = Transform3D.IDENTITY
const SKIP: Array[StringName] = [L]


static func at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func grey(k: float) -> Color:
	return Color(k, k, k, 1.0)


static func bone(k: float) -> Color:
	var t: Color = LookDevWarden.BONE_TINT
	return Color(t.r * k, t.g * k, t.b * k, 1.0)


## A pistol-style grip hanging below the receiver at `z`, leaning back by `lean` radians.
static func grip(mb: MeshBuilder, z: float, size: Vector3 = Vector3(0.056, 0.16, 0.07), lean: float = 0.2, y: float = -0.09) -> void:
	mb.tint = grey(0.26)
	var xf: Transform3D = Transform3D(Basis(Vector3.RIGHT, lean) * Basis(Vector3.BACK, PI), Vector3(0.0, y, z))
	LookDevShapes.bevel_box(mb, size, xf, G, 0.012, Vector2.ONE, 0.0, true, true)


## A thin rod along -Z from `z0` to `z1` at height `y` and lateral offset `x`.
static func rod(
	mb: MeshBuilder, x: float, y: float, z0: float, z1: float, r0: float, r1: float, sides: int, mat_id: StringName = G,
	cap_a: bool = true, cap_b: bool = true
) -> void:
	LookDevShapes.limb(mb, Vector3(x, y, z0), Vector3(x, y, z1), r0, r1, sides, mat_id, ID, 0, cap_a, cap_b)


## A quad of `size` facing -Z (the lit mouth of a tube) centred on `centre`.
static func mouth(mb: MeshBuilder, centre: Vector3, size: Vector2) -> void:
	mb.quad(size, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), centre), L)


## The bake every weapon ends with: ambient occlusion of the plates into the vertex colours (the cyan stays full bright).
static func finish(mb: MeshBuilder) -> ArrayMesh:
	LookDevBake.ao(mb, 0.7, 0.07, 0.2, 1.3, 1.0, 0.1, SKIP)
	return mb.build()
