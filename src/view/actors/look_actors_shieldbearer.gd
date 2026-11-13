class_name LookActorsShieldbearer
extends RefCounted
## The hard-surface Shieldbearer (V4-R; VARIETY_SPEC 5.1): a tall biped 1.8 m high that holds a slab shield as wide as itself in front
## of it, the top edge tilted back toward the bearer so the top-down camera sees the whole upper face. The shield is pale plate with a
## dark rim and a round boss; its upper edge carries the single red optic as a bar on a dark housing. Behind it a dark armoured body
## with a ward emitter pack (two prongs), broad shoulder domes, thin forearms on the shield's grips and a small helm that shows over
## the top edge.
## Three surfaces (gunmetal, ceramic, emit_red), about 480 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const R: StringName = &"emit_red"
const SEED: int = 71
const SHIELD_AT: Vector3 = Vector3(0.0, 0.92, -0.5)
const SHIELD_SIZE: Vector3 = Vector3(1.08, 1.3, 0.12)
const SHIELD_TILT: float = 0.32
const HEAD_RADII: Vector3 = Vector3(0.14, 0.12, 0.15)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	_body(mb)
	_head(mb)
	_shield(mb)
	_optic_bar(mb)
	var spill: Vector3 = _shield_xf() * Vector3(0.0, 0.65, -0.1)
	return LookActorsKit.finish(mb, SEED, 1.8, spill, 0.6, 0.4)


static func _shield_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, SHIELD_TILT), SHIELD_AT)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(side * 0.17, 0.86, 0.15)
		var knee: Vector3 = Vector3(side * 0.2, 0.46, 0.08)
		var ankle: Vector3 = Vector3(side * 0.2, 0.1, 0.2)
		LookActorsParts.leg(mb, hip, knee, ankle, 0.14, 0.11, 0.08, 4, 0.22)
		mb.tint = LookActorsKit.frame(0.16)
		LookActorsParts.foot(mb, side * 0.2, 0.14, 0.14, 0.22)


static func _body(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.bevel_box(mb, Vector3(0.6, 0.6, 0.4), LookActorsKit.at(0.0, 1.14, 0.15), G, 0.06, Vector2(1.2, 1.1), 0.0, true)
	mb.tint = LookActorsKit.plate(0.85)  # the ward emitter pack on the back, with two prongs
	LookDevShapes.bevel_box(mb, Vector3(0.44, 0.5, 0.12), LookActorsKit.at(0.0, 1.18, 0.42), C, 0.05, Vector2.ONE, 0.0, false)
	mb.tint = LookActorsKit.frame(0.18)
	for side: float in [-1.0, 1.0]:
		LookActorsKit.cone(mb, Vector3(side * 0.14, 1.4, 0.44), Vector3(side * 0.16, 1.78, 0.48), 0.035, 4, G)
	for side: float in [-1.0, 1.0]:
		mb.tint = LookActorsKit.plate(0.9 if side > 0.0 else 0.66)
		LookActorsParts.dome(mb, Vector3(0.19, 0.15, 0.22), Vector3(side * 0.4, 1.38, 0.15), Vector3(side, 1.0, 0.0), C, 7, 2)
		var shoulder: Vector3 = Vector3(side * 0.4, 1.32, 0.12)  # the forearms reach the grips on the back of the shield
		var elbow: Vector3 = Vector3(side * 0.46, 1.1, -0.12)
		var wrist: Vector3 = Vector3(side * 0.3, 0.98, -0.4)
		mb.tint = LookActorsKit.frame(0.22)
		LookActorsKit.limb2(mb, shoulder, elbow, wrist, 0.07, 0.06, 0.05, 4, G)


static func _head(mb: MeshBuilder) -> void:
	var head: Transform3D = LookActorsKit.at(0.0, 1.68, 0.1)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G)
	mb.tint = LookActorsKit.plate(0.8)  # a pale crest over the dark helm: no optic here, the bar on the shield is the only red
	LookActorsParts.dome(mb, Vector3(0.05, 0.07, 0.14), Vector3(0.0, 1.76, 0.1), Vector3.UP, C, 6, 1)


static func _shield(mb: MeshBuilder) -> void:
	var xf: Transform3D = _shield_xf()
	mb.tint = LookActorsKit.plate(0.86)
	LookDevShapes.bevel_box(mb, SHIELD_SIZE, xf, C, 0.07, Vector2(0.94, 1.0), 0.0, true)
	mb.tint = LookActorsKit.frame(0.2)  # a raised dark rim on the sides and the bottom
	for side: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, xf * Vector3(side * 0.5, -0.6, -0.08), xf * Vector3(side * 0.47, 0.55, -0.08), 0.04, 0.04, 4, G, LookActorsKit.ID, 0, true, true)
	LookDevShapes.limb(mb, xf * Vector3(-0.5, -0.6, -0.08), xf * Vector3(0.5, -0.6, -0.08), 0.04, 0.04, 4, G, LookActorsKit.ID, 0, true, true)
	mb.tint = LookActorsKit.frame(0.3)  # the round boss in the middle
	LookDevShapes.ellipsoid(mb, Vector3(0.22, 0.2, 0.09), 6, 2, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, -0.05, -0.06)), G, true)


## The single optic: a bar along the upper edge of the shield (a dark housing, a dim halo strip and the bright core).
static func _optic_bar(mb: MeshBuilder) -> void:
	var xf: Transform3D = _shield_xf()
	mb.tint = LookActorsKit.frame(0.07)
	mb.box(Vector3(0.84, 0.08, 0.18), xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.67, -0.03)), G)
	var _part: int = mb.begin_part()
	mb.tint = Color(0.45, 0.45, 0.45, 1.0)
	mb.box(Vector3(0.74, 0.03, 0.14), xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.7, -0.03)), R)
	mb.tint = Color.WHITE
	mb.box(Vector3(0.62, 0.04, 0.09), xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.715, -0.03)), R)
