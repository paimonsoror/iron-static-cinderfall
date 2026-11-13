class_name LookActorsParts
extends RefCounted
## Small shapes shared by the variety enemies and bosses of V4-R (spitter, splitter, shieldbearer, reclaimer, jammer, borer, pylon,
## shard and the four boss nodes). They build on `LookDevShapes` and `LookActorsKit`; every helper says what it costs in triangles.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const ID: Transform3D = Transform3D.IDENTITY


## A closed ring of `segs` straight tubes of `sides` facets (open ends), centred on `centre` in the plane spanned by the unit
## vectors `u` and `v`. `2 * sides * segs` triangles. The caller sets `mb.tint`.
static func ring(
	mb: MeshBuilder, centre: Vector3, u: Vector3, v: Vector3, radius: float, thickness: float, segs: int, sides: int, mat_id: StringName
) -> void:
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0: Vector3 = centre + (u * cos(a0) + v * sin(a0)) * radius
		var p1: Vector3 = centre + (u * cos(a1) + v * sin(a1)) * radius
		LookDevShapes.limb(mb, p0, p1, thickness, thickness, sides, mat_id, ID, 0, false, false)


## A flat foot pad: a low dome (`6` triangles) of radii (`rx`, `rz`) standing on the ground at (`x`, `z`).
static func foot(mb: MeshBuilder, x: float, z: float, rx: float, rz: float, mat_id: StringName = G) -> void:
	LookDevShapes.ellipsoid(mb, Vector3(rx, 0.06, rz), 6, 1, LookActorsKit.at(x, 0.0, z), mat_id, true)


## A dome of `radii` whose crown points along `dir` (an armour dome on any side of a body).
static func dome(
	mb: MeshBuilder, radii: Vector3, centre: Vector3, dir: Vector3, mat_id: StringName, sides: int = 7, rings: int = 2
) -> void:
	LookDevShapes.ellipsoid(mb, radii, sides, rings, Transform3D(LookDevShapes.facing(dir), centre), mat_id, true)


## A two-bone leg with a bend at `knee` (`ra` thigh, `rm` knee, `rb` ankle radius).
static func leg(mb: MeshBuilder, hip: Vector3, knee: Vector3, foot_at: Vector3, ra: float, rm: float, rb: float, sides: int, k: float) -> void:
	mb.tint = LookActorsKit.frame(k)
	LookActorsKit.limb2(mb, hip, knee, foot_at, ra, rm, rb, sides, G)


## A straight tube from `a` to `b` of one radius with both ends capped.
static func tube(mb: MeshBuilder, a: Vector3, b: Vector3, r: float, sides: int, mat_id: StringName, caps: bool = true) -> void:
	LookDevShapes.limb(mb, a, b, r, r, sides, mat_id, ID, 0, caps, caps)
