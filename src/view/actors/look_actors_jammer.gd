class_name LookActorsJammer
extends RefCounted
## The hard-surface Jammer (V4-R; VARIETY_SPEC 5.1): a lean biped 1.8 m high with no head: instead a big upright ring antenna
## stands over its shoulders (a halo, tilted back 37 degrees so the top-down camera sees it as an ellipse from any side), carried on two
## struts from the shoulder domes, and a sensor hub in the ring's centre on three thin spokes. The hub holds the single red optic.
## Dark armoured body, a pale chest slab, pale shoulder domes, thin hanging arms. The ring is the silhouette.
## Three surfaces (gunmetal, ceramic, emit_red), about 380 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 83
const RING_AT: Vector3 = Vector3(0.0, 1.5, 0.06)
const RING_R: float = 0.4
const RING_TILT: float = 0.65
const HUB_RADII: Vector3 = Vector3(0.12, 0.11, 0.12)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	_body(mb)
	_arms(mb)
	_ring(mb)
	var hub: Transform3D = Transform3D(Basis.IDENTITY, RING_AT)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, HUB_RADII, 6, 2, hub, G)
	LookActorsKit.optic(mb, hub, HUB_RADII, 70.0, -0.015, 0.05, 0.55, 3, 0.5)
	return LookActorsKit.finish(mb, SEED, 1.8, RING_AT + Vector3(0.0, 0.0, -0.1), 0.6, 0.4)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(side * 0.15, 0.88, 0.0)
		var knee: Vector3 = Vector3(side * 0.18, 0.47, -0.08)
		var ankle: Vector3 = Vector3(side * 0.18, 0.1, 0.02)
		LookActorsParts.leg(mb, hip, knee, ankle, 0.11, 0.09, 0.065, 3, 0.22)
		mb.tint = LookActorsKit.frame(0.16)
		LookActorsParts.foot(mb, side * 0.18, -0.05, 0.12, 0.2)


static func _body(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.bevel_box(mb, Vector3(0.5, 0.62, 0.32), LookActorsKit.at(0.0, 1.12, 0.0), G, 0.06, Vector2(1.2, 1.1), 0.0, true)
	var front: Basis = LookDevShapes.facing(Vector3(0.0, -0.08, -1.0))
	mb.tint = LookActorsKit.plate(0.92)  # a pale chest slab
	LookDevShapes.bevel_box(mb, Vector3(0.38, 0.06, 0.4), Transform3D(front, Vector3(0.0, 1.14, -0.18)), C, 0.04, Vector2.ONE, 0.0, true, true)
	for side: float in [-1.0, 1.0]:
		mb.tint = LookActorsKit.plate(0.86 if side > 0.0 else 0.64)
		LookActorsParts.dome(mb, Vector3(0.17, 0.13, 0.19), Vector3(side * 0.37, 1.36, 0.0), Vector3(side, 1.0, 0.0), C, 6, 2)


static func _arms(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var shoulder: Vector3 = Vector3(side * 0.36, 1.3, 0.0)
		var elbow: Vector3 = Vector3(side * 0.44, 0.96, -0.06)
		var wrist: Vector3 = Vector3(side * 0.4, 0.66, -0.16)
		mb.tint = LookActorsKit.frame(0.22)
		LookActorsKit.limb2(mb, shoulder, elbow, wrist, 0.06, 0.055, 0.045, 4, G)


## The halo: a closed ring of straight tubes in a plane tilted back by RING_TILT, the three spokes to the hub and two struts down
## to the shoulder domes.
static func _ring(mb: MeshBuilder) -> void:
	var u: Vector3 = Vector3.RIGHT
	var v: Vector3 = Vector3(0.0, cos(RING_TILT), sin(RING_TILT))
	mb.tint = LookActorsKit.plate(0.82)
	LookActorsParts.ring(mb, RING_AT, u, v, RING_R, 0.04, 8, 3, C)
	mb.tint = LookActorsKit.frame(0.2)
	for k: int in 3:
		var a: float = PI * 0.5 + TAU * float(k) / 3.0
		var rim: Vector3 = RING_AT + (u * cos(a) + v * sin(a)) * RING_R
		LookDevShapes.limb(mb, RING_AT, rim, 0.022, 0.022, 3, G, LookActorsKit.ID, 0, false, false)
	for side: float in [-1.0, 1.0]:
		var low: Vector3 = RING_AT + (u * cos(PI * 1.5 + side * 0.9) + v * sin(PI * 1.5 + side * 0.9)) * RING_R
		LookDevShapes.limb(mb, Vector3(side * 0.34, 1.3, 0.04), low, 0.035, 0.03, 4, G, LookActorsKit.ID, 0, true, true)
