class_name LookActorsSpitter
extends RefCounted
## The hard-surface Spitter (V4-R; VARIETY_SPEC 5.1): standoff artillery 1.6 m high on a tripod stance (two splayed forelegs and one
## trailing leg), a dark armoured body under a pale dome, and a long slag tube on its back angled up and forward at 45 degrees:
## a thin diagonal that no other machine carries. The single red optic is a lens on the housing at the tube's base, turned up and
## back so that the top-down camera sees it whichever way the machine faces.
## Three surfaces (gunmetal, ceramic, emit_red), about 380 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 61
const BREECH_AT: Vector3 = Vector3(0.0, 0.88, 0.34)
const TUBE_DIR: Vector3 = Vector3(0.0, 0.7071, -0.7071)
const TUBE_LEN: float = 1.0
const BREECH_RADII: Vector3 = Vector3(0.17, 0.14, 0.17)
const HIPS: Array[Vector3] = [Vector3(-0.2, 0.66, -0.16), Vector3(0.2, 0.66, -0.16), Vector3(0.0, 0.62, 0.3)]
const KNEES: Array[Vector3] = [Vector3(-0.46, 0.5, -0.3), Vector3(0.46, 0.5, -0.3), Vector3(0.0, 0.5, 0.66)]
const FEET: Array[Vector3] = [Vector3(-0.46, 0.0, -0.5), Vector3(0.46, 0.0, -0.5), Vector3(0.0, 0.0, 0.7)]


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	_body(mb)
	_tube(mb)
	_breech(mb)
	return LookActorsKit.finish(mb, SEED, 1.6, BREECH_AT + Vector3(0.0, 0.16, 0.05), 0.55, 0.4)


static func _legs(mb: MeshBuilder) -> void:
	for k: int in 3:
		LookActorsParts.leg(mb, HIPS[k], KNEES[k], FEET[k], 0.085, 0.07, 0.045, 4, 0.22)
		mb.tint = LookActorsKit.frame(0.15)
		LookActorsParts.foot(mb, FEET[k].x, FEET[k].z, 0.12, 0.15)


static func _body(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.28)
	LookDevShapes.ellipsoid(mb, Vector3(0.3, 0.24, 0.42), 8, 2, LookActorsKit.at(0.0, 0.72, 0.0), G)
	mb.tint = LookActorsKit.plate(0.9)  # a pale armour dome over the forward half of the body
	LookActorsParts.dome(mb, Vector3(0.26, 0.15, 0.3), Vector3(0.0, 0.84, -0.1), Vector3(0.0, 1.0, -0.15), C)
	mb.tint = LookActorsKit.plate(0.72)  # two small side pods: the slag tanks
	for side: float in [-1.0, 1.0]:
		LookActorsParts.dome(mb, Vector3(0.1, 0.12, 0.2), Vector3(side * 0.3, 0.72, 0.12), Vector3(side, 0.4, 0.0), C, 5, 1)


static func _tube(mb: MeshBuilder) -> void:
	var tip: Vector3 = BREECH_AT + TUBE_DIR * TUBE_LEN
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, BREECH_AT, tip, 0.1, 0.085, 8, G, LookActorsKit.ID, 0, true, false)
	mb.tint = LookActorsKit.plate(0.8)
	for t: float in [0.32, 0.6]:  # two armour collars
		var at_t: Vector3 = BREECH_AT + TUBE_DIR * TUBE_LEN * t
		LookDevShapes.limb(mb, at_t - TUBE_DIR * 0.05, at_t + TUBE_DIR * 0.05, 0.125, 0.125, 8, C, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.plate(0.66)  # the muzzle flare
	LookDevShapes.limb(mb, tip - TUBE_DIR * 0.14, tip + TUBE_DIR * 0.02, 0.1, 0.14, 8, C, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.frame(0.18)  # a brace from the body to the tube
	LookDevShapes.limb(mb, Vector3(0.0, 0.78, -0.12), BREECH_AT + TUBE_DIR * TUBE_LEN * 0.5, 0.04, 0.035, 4, G, LookActorsKit.ID, 0, true, true)


static func _breech(mb: MeshBuilder) -> void:
	var head: Transform3D = Transform3D(Basis(Vector3.UP, PI), BREECH_AT)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, BREECH_RADII, 6, 2, head, G)
	LookActorsKit.optic(mb, head, BREECH_RADII, 70.0, -0.02, 0.07, 0.9, 3, 0.5)
