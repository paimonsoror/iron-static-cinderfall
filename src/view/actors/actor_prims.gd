class_name ActorPrims
extends RefCounted
## Placement helpers shared by the procedural actor meshes. Conventions: forward is -Z, feet at y = 0,
## rotation about X with a negative angle leans the top toward -Z (forward).


## Transform that centers a primitive at `pos`.
static func at(pos: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos)


## Transform with an Euler rotation (radians, XYZ) and a center.
static func xf(pos: Vector3, euler: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(euler), pos)


## A box strut from `a` to `b` (long axis a->b, square section `thick`), placed inside `frame`.
static func strut(
	mb: MeshBuilder, a: Vector3, b: Vector3, thick: float, mat_id: StringName, frame: Transform3D = Transform3D.IDENTITY
) -> void:
	mb.box(Vector3(thick, thick, a.distance_to(b)), frame * _along(a, b), mat_id)


## A tapered prism strut (apex up, section `wide` x `high`) from `a` to `b`, placed inside `frame`.
static func blade(
	mb: MeshBuilder, a: Vector3, b: Vector3, wide: float, high: float, mat_id: StringName,
	frame: Transform3D = Transform3D.IDENTITY
) -> void:
	mb.prism(Vector3(wide, high, a.distance_to(b)), frame * _along(a, b), mat_id)


## A box of `size` centered at `center`, placed inside `frame`.
static func box_in(mb: MeshBuilder, size: Vector3, center: Vector3, mat_id: StringName, frame: Transform3D) -> void:
	mb.box(size, frame * Transform3D(Basis.IDENTITY, center), mat_id)


## A cable: a thin cylinder from `a` to `b`, placed inside `frame`.
static func cable(
	mb: MeshBuilder, a: Vector3, b: Vector3, radius: float, sides: int, mat_id: StringName,
	frame: Transform3D = Transform3D.IDENTITY
) -> void:
	var axis_to_z: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	mb.cylinder(radius, radius, a.distance_to(b), sides, frame * _along(a, b) * axis_to_z, mat_id)


## Pitch about X by `deg` degrees, pivoting around `pivot` (negative leans forward).
static func pitch_frame(deg: float, pivot: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(deg)), pivot)


static func _along(a: Vector3, b: Vector3) -> Transform3D:
	var d: Vector3 = b - a
	if d.length() < 0.0001:
		return Transform3D(Basis.IDENTITY, a)
	var dir: Vector3 = d.normalized()
	var up_hint: Vector3 = Vector3.UP
	if absf(dir.y) > 0.95:
		up_hint = Vector3.RIGHT
	return Transform3D(Basis.looking_at(dir, up_hint), (a + b) * 0.5)
