class_name LookActorsShard
extends RefCounted
## The hard-surface Shard (V4-R; VARIETY_SPEC 5.1, 12.2): one lobe of a splitter with two legs, a fast mini 0.4 m high drawn 40 at a
## time as one transform-only MultiMesh (`MiniSwarm`), so the mesh is tiny (at most 40 triangles) and has two surfaces: ceramic (the
## lobe, its legs and a dorsal spike, pitched forward like a running blade) and emit_red (the slit, a full-bright core and a dim halo).
## The Mote is a round pale cap on three legs with the slit on its front; the Shard is a darker, longer wedge on two legs with a
## spike on its back and its slit turned up, so the two minis stay apart in a mixed stream.
## Forward is -Z, the feet are at y = 0.

const C: StringName = &"ceramic"
const R: StringName = &"emit_red"
const BODY_AT: Vector3 = Vector3(0.0, 0.19, 0.0)
const BODY_RADII: Vector3 = Vector3(0.12, 0.17, 0.3)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = LookActorsKit.plate(0.66)
	var lean: Basis = Basis(Vector3.RIGHT, -0.38)  # the nose dips: a running pose
	LookDevShapes.ellipsoid(mb, BODY_RADII, 5, 2, Transform3D(lean, BODY_AT), C, true)
	mb.tint = LookActorsKit.frame(0.3)  # two thin dark legs
	for side: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, Vector3(side * 0.07, 0.17, 0.08), Vector3(side * 0.15, 0.0, 0.28), 0.034, 0.02, 3, C, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.plate(0.85)  # a spike on the back
	LookActorsKit.cone(mb, Vector3(0.0, 0.28, 0.12), Vector3(0.0, 0.44, 0.36), 0.05, 3, C)
	# the slit: a dim halo strip under a full-bright core, tilted up toward the camera
	var face: Basis = LookDevShapes.facing(Vector3(0.0, 0.7, -0.7))
	var front: Vector3 = Vector3(0.0, 0.29, -0.17)
	var _part: int = mb.begin_part()
	mb.tint = Color(0.45, 0.45, 0.45, 1.0)
	mb.quad(Vector2(0.2, 0.12), Transform3D(face, front + Vector3(0.0, -0.005, -0.004)), R)
	mb.tint = Color.WHITE
	mb.quad(Vector2(0.16, 0.07), Transform3D(face, front + Vector3(0.0, 0.0, -0.012)), R)
	LookDevBake.ao(mb, 0.6, 0.05, 0.3, 0.0, 0.5, 0.1, LookActorsKit.SKIP_EMISSIVE)
	return mb.build()
