class_name LookActorsReclaimer
extends RefCounted
## The hard-surface Reclaimer (V4-R; VARIETY_SPEC 5.1): a low, wide six-legged crawler (a dark body under a pale dome) that carries a
## tall thin mast, 2.0 m high with a lens turret on its head that holds the single red optic, and three long cable arms that arch
## forward from the body and end in clamps near the ground (the repair tethers). Low and wide below, a spindle above: nothing else
## on the field is both.
## Three surfaces (gunmetal, ceramic, emit_red), about 450 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 79
const MAST_BASE: Vector3 = Vector3(0.0, 0.52, 0.08)
const MAST_TOP: Vector3 = Vector3(0.0, 1.72, 0.08)
const HEAD_AT: Vector3 = Vector3(0.0, 1.82, 0.08)
const HEAD_RADII: Vector3 = Vector3(0.15, 0.12, 0.15)
const ARM_YAWS: Array[float] = [-0.85, 0.0, 0.85]


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	_body(mb)
	_mast(mb)
	_arms(mb)
	var head: Transform3D = Transform3D(Basis.IDENTITY, HEAD_AT)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G)
	LookActorsKit.optic(mb, head, HEAD_RADII, 72.0, -0.02, 0.06, 0.6, 3, 0.5)
	return LookActorsKit.finish(mb, SEED, 2.0, HEAD_AT + Vector3(0.0, -0.05, -0.1), 0.6, 0.4)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.3, 0.08, 0.44]:
			var hip: Vector3 = Vector3(side * 0.38, 0.4, z)
			var knee: Vector3 = Vector3(side * 0.7, 0.56, z * 1.05)
			var foot_at: Vector3 = Vector3(side * 0.78, 0.0, z * 1.12)
			LookActorsParts.leg(mb, hip, knee, foot_at, 0.065, 0.055, 0.035, 3, 0.2)


static func _body(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.28)
	LookDevShapes.ellipsoid(mb, Vector3(0.5, 0.2, 0.56), 8, 2, LookActorsKit.at(0.0, 0.42, 0.06), G)
	mb.tint = LookActorsKit.plate(0.9)
	LookActorsParts.dome(mb, Vector3(0.42, 0.14, 0.45), Vector3(0.0, 0.52, 0.0), Vector3.UP, C, 8, 2)
	mb.tint = LookActorsKit.plate(0.66)  # a pale power module on the rear
	LookActorsParts.dome(mb, Vector3(0.26, 0.15, 0.2), Vector3(0.0, 0.5, 0.46), Vector3(0.0, 1.0, 0.3), C, 6, 2)


static func _mast(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, MAST_BASE, MAST_TOP, 0.07, 0.045, 6, G, LookActorsKit.ID, 0, true, true)
	mb.tint = LookActorsKit.plate(0.78)
	for y: float in [0.8, 1.1, 1.4]:  # three pale collars
		LookDevShapes.limb(mb, Vector3(0.0, y, 0.08), Vector3(0.0, y + 0.06, 0.08), 0.1, 0.1, 6, C, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.frame(0.18)  # three braces from the body to the mast
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0 + 0.5
		LookDevShapes.limb(mb, Vector3(cos(a) * 0.3, 0.5, 0.08 + sin(a) * 0.3), Vector3(0.0, 1.0, 0.08), 0.03, 0.025, 3, G, LookActorsKit.ID, 0, true, true)
	LookActorsKit.cone(mb, HEAD_AT + Vector3(0.0, 0.1, 0.0), HEAD_AT + Vector3(0.0, 0.2, 0.0), 0.03, 4, G)


## Three cable arms: each arches up and out of the front of the body and ends in a clamp near the ground.
static func _arms(mb: MeshBuilder) -> void:
	for yaw: float in ARM_YAWS:
		var f: Vector3 = Vector3(sin(yaw), 0.0, -cos(yaw))
		var root: Vector3 = f * 0.3 + Vector3(0.0, 0.5, 0.1)
		var mid: Vector3 = f * 0.62 + Vector3(0.0, 1.0, 0.04)
		var tip: Vector3 = f * 0.76 + Vector3(0.0, 0.3, 0.0)
		mb.tint = LookActorsKit.frame(0.18)
		LookActorsKit.limb2(mb, root, mid, tip, 0.055, 0.05, 0.045, 4, G)
		mb.tint = LookActorsKit.plate(0.7)
		LookActorsKit.cone(mb, tip + Vector3(0.0, 0.04, 0.0), tip + f * 0.08 + Vector3(0.0, -0.3, 0.0), 0.06, 4, C)
