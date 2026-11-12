class_name LookActorsRusher
extends RefCounted
## The hard-surface Rusher (W3-D): a lean 1.4 m sprinter with its torso pitched 34 degrees forward, reverse-jointed legs
## (the knee forward, the ankle back), a low wedge head with the single red optic band, forward-reaching arms that end in
## blades, three swept-back dorsal spines and a dim red glow strip along the spine (a secondary light, not an eye).
## Asymmetric damage: the third spine is snapped short, the left blade is broken and the left shoulder plate is missing.
## Three surfaces (gunmetal, ceramic, emit_red), about 440 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const R: StringName = &"emit_red"
const HEAD_RADII: Vector3 = Vector3(0.11, 0.09, 0.15)
const PITCH: float = -0.6
const SEED: int = 37


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var hip: Vector3 = Vector3(0.0, 0.7, 0.12)
	var frame: Transform3D = Transform3D(Basis(Vector3.RIGHT, PITCH), hip)
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.bevel_box(mb, Vector3(0.34, 0.5, 0.26), frame * LookActorsKit.at(0.0, 0.3, 0.0), G, 0.05, Vector2(1.3, 1.0), 0.0, true)
	mb.tint = LookActorsKit.plate(0.9)
	var front: Basis = LookDevShapes.facing(Vector3(0.0, -0.1, -1.0))
	LookDevShapes.bevel_box(mb, Vector3(0.3, 0.06, 0.34), frame * Transform3D(front, Vector3(0.0, 0.34, -0.15)), C, 0.045, Vector2.ONE, 0.0, true, true)
	_shoulders(mb, frame)
	_spines(mb, frame)
	var head: Transform3D = frame * LookActorsKit.at(0.0, 0.66, -0.12)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, frame * Vector3(0.0, 0.5, -0.02), frame * Vector3(0.0, 0.64, -0.1), 0.07, 0.06, 5, G, LookActorsKit.ID, 0, false, false)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G)
	mb.tint = LookActorsKit.plate(0.84)  # a pale brow plate over the dark head
	LookDevShapes.ellipsoid(mb, Vector3(0.05, 0.05, 0.12), 6, 2, head * LookActorsKit.at(0.0, 0.06, 0.03), C, true)
	LookActorsKit.optic(mb, head, HEAD_RADII, 72.0, -0.02, 0.075, 0.7, 4, 0.5)
	_arms(mb)
	_legs(mb)
	var spill: Vector3 = head * Vector3(0.0, 0.04, -0.12)
	return LookActorsKit.finish(mb, SEED, 1.4, spill, 0.5, 0.38)


static func _shoulders(mb: MeshBuilder, frame: Transform3D) -> void:
	mb.tint = LookActorsKit.plate(0.82)
	LookDevShapes.ellipsoid(mb, Vector3(0.15, 0.1, 0.16), 8, 2, frame * LookActorsKit.at(0.26, 0.52, 0.0), C, true)
	mb.tint = LookActorsKit.frame(0.3)  # the left plate is gone: a bare frame cap
	LookDevShapes.ellipsoid(mb, Vector3(0.1, 0.07, 0.11), 6, 2, frame * LookActorsKit.at(-0.25, 0.5, 0.0), G, true)


static func _spines(mb: MeshBuilder, frame: Transform3D) -> void:
	for k: int in 3:
		var base: Vector3 = Vector3(0.0, 0.2 + 0.17 * float(k), 0.14)
		var tip: Vector3 = Vector3(0.0, base.y + 0.12, 0.5 - 0.09 * float(k))
		if k == 2:
			tip = Vector3(0.0, base.y + 0.05, 0.28)  # snapped short
		mb.tint = LookActorsKit.plate(0.7 - 0.06 * float(k))
		LookActorsKit.cone(mb, frame * base, frame * tip, 0.07, 4, C)
	mb.tint = Color(0.7, 0.7, 0.7, 1.0)  # the dim glow strip along the spine (the optic is the only full-bright red)
	var _glow: int = mb.begin_part()
	mb.box(Vector3(0.035, 0.02, 0.34), frame * LookActorsKit.at(0.0, 0.5, 0.17), R)


static func _arms(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var shoulder: Vector3 = Vector3(side * 0.25, 1.08, -0.14)
		var elbow: Vector3 = Vector3(side * 0.31, 0.78, -0.36)
		var wrist: Vector3 = Vector3(side * 0.22, 0.56, -0.46)
		mb.tint = LookActorsKit.frame(0.24)
		LookActorsKit.limb2(mb, shoulder, elbow, wrist, 0.06, 0.05, 0.045, 4, G)
		mb.tint = LookActorsKit.plate(0.74)
		var tip: Vector3 = wrist + Vector3(side * -0.02, -0.1, -0.16)
		if side < 0.0:
			tip = wrist + Vector3(0.02, -0.05, -0.1)  # the broken blade
		LookActorsKit.cone(mb, wrist + Vector3(0.0, 0.03, 0.02), tip, 0.055, 4, C)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(side * 0.13, 0.66, 0.1)
		var knee: Vector3 = Vector3(side * 0.16, 0.4, -0.14)
		var ankle: Vector3 = Vector3(side * 0.15, 0.1, 0.2)
		mb.tint = LookActorsKit.frame(0.22)
		LookActorsKit.limb2(mb, hip, knee, ankle, 0.095, 0.075, 0.045, 4, G)
		mb.tint = LookActorsKit.plate(0.7)
		LookDevShapes.limb(mb, hip.lerp(knee, 0.3), knee + Vector3(0.0, 0.04, -0.02), 0.1, 0.085, 4, C, LookActorsKit.ID, 0, false, false)
		mb.tint = LookActorsKit.frame(0.16)
		LookDevShapes.bevel_box(mb, Vector3(0.13, 0.07, 0.34), LookActorsKit.at(side * 0.15, 0.035, 0.05), G, 0.03, Vector2.ONE, 0.0, true, true)
