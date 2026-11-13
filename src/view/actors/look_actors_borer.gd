class_name LookActorsBorer
extends RefCounted
## The hard-surface Borer (V4-R; VARIETY_SPEC 5.1): a low, long wedge 0.8 m high, 1.4 m from the drill tip to the tail. A dark
## armoured body under three pale overlapping shell plates, four stubby digging legs, two spade claws at the sides and a banded drill
## nose (pale and dark cones, a point) on the front. The single red optic is a slit on the head just behind the drill, tilted up
## to the top-down camera.
## Three surfaces (gunmetal, ceramic, emit_red), about 330 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 89
const HEAD_AT: Vector3 = Vector3(0.0, 0.38, -0.25)
const HEAD_RADII: Vector3 = Vector3(0.2, 0.17, 0.24)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	_body(mb)
	_drill(mb)
	var head: Transform3D = Transform3D(Basis.IDENTITY, HEAD_AT)
	mb.tint = LookActorsKit.frame(0.22)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G)
	LookActorsKit.optic(mb, head, HEAD_RADII, 62.0, 0.0, 0.07, 0.7, 3, 0.5)
	return LookActorsKit.finish(mb, SEED, 0.8, HEAD_AT + Vector3(0.0, 0.08, -0.12), 0.6, 0.35)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in [0.0, 0.38]:
			mb.tint = LookActorsKit.frame(0.2)
			LookDevShapes.limb(mb, Vector3(side * 0.28, 0.32, z), Vector3(side * 0.4, 0.0, z - 0.08), 0.07, 0.05, 4, G, LookActorsKit.ID, 0, true, false)


static func _body(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.28)
	LookDevShapes.ellipsoid(mb, Vector3(0.34, 0.3, 0.5), 8, 2, LookActorsKit.at(0.0, 0.4, 0.12), G)
	var shells: Array[Vector3] = [Vector3(0.3, 0.18, 0.24), Vector3(0.28, 0.17, 0.22), Vector3(0.24, 0.16, 0.2)]
	for k: int in 3:  # three pale shell plates, each a little smaller than the one behind it
		mb.tint = LookActorsKit.plate(0.92 - 0.1 * float(k))
		LookActorsParts.dome(mb, shells[k], Vector3(0.0, 0.46 + 0.01 * float(k), 0.42 - 0.26 * float(k)), Vector3(0.0, 1.0, -0.1), C, 6, 2)
	mb.tint = LookActorsKit.frame(0.16)  # an exhaust stub at the tail
	LookDevShapes.limb(mb, Vector3(0.0, 0.5, 0.56), Vector3(0.0, 0.62, 0.72), 0.07, 0.05, 5, G, LookActorsKit.ID, 0, true, true)


## The drill: a collar, a pale cone, a dark cone and a pale point, nose forward (-Z).
static func _drill(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.16)
	LookDevShapes.limb(mb, Vector3(0.0, 0.36, -0.4), Vector3(0.0, 0.36, -0.44), 0.22, 0.22, 6, G, LookActorsKit.ID, 0, false, true)
	mb.tint = LookActorsKit.plate(0.82)
	LookDevShapes.limb(mb, Vector3(0.0, 0.36, -0.44), Vector3(0.0, 0.36, -0.58), 0.2, 0.15, 6, C, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, Vector3(0.0, 0.36, -0.58), Vector3(0.0, 0.36, -0.7), 0.15, 0.09, 6, G, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.plate(0.8)
	LookActorsKit.cone(mb, Vector3(0.0, 0.36, -0.7), Vector3(0.0, 0.36, -0.86), 0.09, 6, C)
	mb.tint = LookActorsKit.plate(0.6)  # two spade claws, angled out and forward
	for side: float in [-1.0, 1.0]:
		LookActorsKit.cone(mb, Vector3(side * 0.3, 0.24, -0.2), Vector3(side * 0.46, 0.08, -0.62), 0.07, 4, C)
