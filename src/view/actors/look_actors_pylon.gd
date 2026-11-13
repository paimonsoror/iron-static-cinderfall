class_name LookActorsPylon
extends RefCounted
## The hard-surface Ward Pylon (V4-R; the Aegis Array's escort, VARIETY_SPEC 6): a slim armoured obelisk 1.5 m high on a hex foot,
## three pale buttress fins, a collar and an emitter head that carries the single red optic as a lens band turned up toward the
## camera. It orbits its boss at 2.2 m, three of them in a ring, so it has to read as "one of a set": a tall thin post, nothing
## like a body.
## Three surfaces (gunmetal, ceramic, emit_red), about 140 triangles.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 97
const HEAD_AT: Vector3 = Vector3(0.0, 1.3, 0.0)
const HEAD_RADII: Vector3 = Vector3(0.14, 0.17, 0.14)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = LookActorsKit.frame(0.16)
	mb.cylinder(0.3, 0.34, 0.1, 6, LookActorsKit.at(0.0, 0.05, 0.0), G)
	mb.tint = LookActorsKit.frame(0.24)
	LookDevShapes.limb(mb, Vector3(0.0, 0.08, 0.0), Vector3(0.0, 1.2, 0.0), 0.13, 0.07, 6, G, LookActorsKit.ID, 0, false, true)
	mb.tint = LookActorsKit.plate(0.8)
	for k: int in 3:  # three buttress fins
		var a: float = TAU * float(k) / 3.0 + PI * 0.5
		LookDevShapes.limb(mb, Vector3(cos(a) * 0.3, 0.1, sin(a) * 0.3), Vector3(cos(a) * 0.09, 0.72, sin(a) * 0.09), 0.06, 0.02, 3, C, LookActorsKit.ID, 0, true, false)
	mb.tint = LookActorsKit.plate(0.7)
	LookDevShapes.limb(mb, Vector3(0.0, 0.62, 0.0), Vector3(0.0, 0.72, 0.0), 0.15, 0.15, 6, C, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.frame(0.2)
	var head: Transform3D = Transform3D(Basis.IDENTITY, HEAD_AT)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G)
	LookActorsKit.optic(mb, head, HEAD_RADII, 70.0, -0.02, 0.06, 0.8, 2, 0.5)
	LookActorsKit.cone(mb, HEAD_AT + Vector3(0.0, 0.14, 0.0), HEAD_AT + Vector3(0.0, 0.26, 0.0), 0.03, 3, G)
	return LookActorsKit.finish(mb, SEED, 1.5, HEAD_AT + Vector3(0.0, 0.0, -0.1), 0.5, 0.35)
