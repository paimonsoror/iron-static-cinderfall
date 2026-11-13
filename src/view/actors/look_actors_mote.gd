class_name LookActorsMote
extends RefCounted
## The hard-surface Mote (V2-F; VARIETY_SPEC 5.1): a hand-sized hopping tripod 0.4 m high whose whole body is a small pale ceramic
## cap with one red slit. It is drawn 40 at a time as one transform-only MultiMesh (MiniSwarm), so the mesh is tiny (at most 40
## triangles) and has two surfaces: ceramic (cap and legs, dirt and ambient occlusion baked into the vertex colours) and emit_red
## (the slit, two quads: a full-bright core and a dim halo strip under it, turned up to the camera). V4-R made it readable at phone
## size (it was 18 px of pale grain with a 4 px red mark): a wider cap, pale legs spread to 0.46 m and a red mark twice as large.
## Forward is -Z, the feet are at y = 0.

const C: StringName = &"ceramic"
const R: StringName = &"emit_red"
const SEED: int = 53
const CAP_AT: Vector3 = Vector3(0.0, 0.2, 0.0)
const CAP_RADII: Vector3 = Vector3(0.22, 0.2, 0.23)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = LookActorsKit.plate(0.95)
	LookDevShapes.ellipsoid(mb, CAP_RADII, 5, 2, Transform3D(Basis.IDENTITY, CAP_AT), C, true)
	mb.tint = LookActorsKit.plate(0.7)  # three pale legs (they read against the dark yard): one forward, two back
	for k: int in 3:
		var a: float = PI * 0.5 + TAU * float(k) / 3.0 + PI
		var hip: Vector3 = Vector3(cos(a) * 0.11, 0.2, sin(a) * 0.11)
		var foot: Vector3 = Vector3(cos(a) * 0.23, 0.0, sin(a) * 0.23)
		LookDevShapes.limb(mb, hip, foot, 0.035, 0.025, 3, C, LookActorsKit.ID, 0, false, false)
	# the slit: a dim halo strip under a full-bright core, both on the front of the cap, tilted up toward the camera
	var face: Basis = LookDevShapes.facing(Vector3(0.0, 0.8, -0.6))
	var front: Vector3 = CAP_AT + Vector3(0.0, 0.15, -0.14)
	var _part: int = mb.begin_part()
	mb.tint = Color(0.45, 0.45, 0.45, 1.0)
	mb.quad(Vector2(0.26, 0.12), Transform3D(face, front + Vector3(0.0, -0.005, -0.004)), R)
	mb.tint = Color.WHITE
	mb.quad(Vector2(0.2, 0.07), Transform3D(face, front + Vector3(0.0, 0.0, -0.012)), R)
	LookDevBake.ao(mb, 0.6, 0.05, 0.3, 0.0, 0.5, 0.1, LookActorsKit.SKIP_EMISSIVE)
	return mb.build()
