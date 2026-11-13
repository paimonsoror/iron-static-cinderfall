class_name LookActorsSplitter
extends RefCounted
## The hard-surface Splitter (V4-R; VARIETY_SPEC 5.1): a low three-lobed body as wide as a Hollow Warden and a third lower, 1.3 m
## high. Three dark lobes side by side (the centre one taller, set forward, carrying the single red optic on its front), each under a
## pale shell that is tilted back so the dark front shows, each on two short legs; narrow gaps between the lobes show the frame
## beams that hold them together. Every lobe is one future shard: a lobe and two legs.
## Three surfaces (gunmetal, ceramic, emit_red), about 430 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 67
## Lobes: centre, radii, shell tilt (toward +Z, radians). Centre first.
const CENTRES: Array[Vector3] = [Vector3(0.0, 0.78, -0.08), Vector3(-0.47, 0.64, 0.1), Vector3(0.47, 0.64, 0.1)]
const RADII: Array[Vector3] = [Vector3(0.24, 0.5, 0.42), Vector3(0.18, 0.4, 0.36), Vector3(0.18, 0.4, 0.36)]
const EYE_RADII: Vector3 = Vector3(0.14, 0.1, 0.14)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	for k: int in 3:
		_lobe(mb, k)
	_frame(mb)
	var eye: Transform3D = LookActorsKit.at(0.0, 1.0, -0.34)  # a sensor pod on the front of the centre lobe carries the optic
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, EYE_RADII, 6, 2, eye, G)
	LookActorsKit.optic(mb, eye, EYE_RADII, 66.0, -0.015, 0.06, 0.55, 4, 0.5)
	var spill: Vector3 = Vector3(0.0, 1.0, -0.4)
	return LookActorsKit.finish(mb, SEED, 1.3, spill, 0.6, 0.4)


static func _lobe(mb: MeshBuilder, k: int) -> void:
	var c: Vector3 = CENTRES[k]
	var r: Vector3 = RADII[k]
	mb.tint = LookActorsKit.frame(0.3 - 0.04 * float(k))
	LookDevShapes.ellipsoid(mb, r, 8, 2, LookActorsKit.at(c.x, c.y, c.z), G)
	mb.tint = LookActorsKit.plate(0.92 - 0.1 * float(k))
	var dir: Vector3 = Vector3(0.0, 1.0, 0.55 if k == 0 else 0.3)
	LookActorsParts.dome(mb, r * Vector3(1.06, 0.7, 1.04), c + Vector3(0.0, 0.1, 0.1), dir, C, 8, 2)
	for side: float in [-1.0, 1.0]:  # two short legs under the lobe, set forward and back
		var foot_z: float = c.z + side * 0.18
		mb.tint = LookActorsKit.frame(0.18)
		LookDevShapes.limb(mb, Vector3(c.x, c.y - 0.3, c.z + side * 0.08), Vector3(c.x, 0.0, foot_z), 0.075, 0.055, 4, G, LookActorsKit.ID, 0, true, false)


## The beams in the seams between the lobes and a low frame under them.
static func _frame(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.14)
	for side: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, Vector3(side * 0.265, 0.3, 0.0), Vector3(side * 0.265, 1.0, 0.0), 0.05, 0.04, 6, G, LookActorsKit.ID, 0, true, true)
	LookDevShapes.limb(mb, Vector3(-0.6, 0.4, 0.1), Vector3(0.6, 0.4, 0.1), 0.06, 0.06, 6, G, LookActorsKit.ID, 0, true, true)
