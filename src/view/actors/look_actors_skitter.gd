class_name LookActorsSkitter
extends RefCounted
## The hard-surface Skitter (W3-D; looks STYLISED and STYLISED_PLUS). A low, hunched crawler 0.9 m high drawn from scratch:
## a pitched dark thorax under three overlapping pale shell plates (dark gaps between them), a dark head with a pale brow plate
## that carries the single red optic on a dark bezel, two raised mantis forelimbs that end in pale claws, and four digitigrade
## legs that stay inside the sim's slot footprint (the old legs spread 1.3 m wide and piled up at 50 enemies: here the feet are
## within 0.4 m of the centre and the body is 0.4 m wide).
## Asymmetric damage: the rear left leg is broken off at the shin and the left forelimb hangs lower and bent.
## Three surfaces (gunmetal, ceramic, emit_red), about 440 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const HEAD_RADII: Vector3 = Vector3(0.12, 0.1, 0.135)
const SEED: int = 11


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var body: Transform3D = Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0.0, 0.47, 0.05))
	# thorax and abdomen (dark frame), the pale shell plates over them, each a little smaller than the one before
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, Vector3(0.0, 0.0, -0.2), Vector3(0.0, 0.0, 0.26), 0.12, 0.13, 6, G, body, 0, false, false)
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.ellipsoid(mb, Vector3(0.12, 0.1, 0.16), 6, 2, body * LookActorsKit.at(0.0, -0.02, 0.28), G)
	var shells: Array[Vector3] = [Vector3(0.2, 0.14, 0.13), Vector3(0.185, 0.13, 0.12), Vector3(0.16, 0.115, 0.11)]
	for k: int in shells.size():
		mb.tint = LookActorsKit.plate(0.95 - 0.12 * float(k))
		var z: float = -0.1 + 0.17 * float(k)
		LookDevShapes.ellipsoid(mb, shells[k], 8, 2, body * LookActorsKit.at(0.0, 0.03 - 0.012 * float(k), z), C, true)
	# head: a dark helm with a pale brow plate, the single optic band on its upper front
	var head: Transform3D = body * LookActorsKit.at(0.0, -0.03, -0.3)
	mb.tint = LookActorsKit.frame(0.22)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 8, 2, head, G)
	mb.tint = LookActorsKit.plate(0.8)
	LookDevShapes.ellipsoid(mb, Vector3(0.05, 0.05, 0.11), 6, 2, head * LookActorsKit.at(0.0, 0.08, 0.04), C, true)
	mb.tint = LookActorsKit.frame(0.18)
	LookDevShapes.limb(mb, Vector3(0.0, 0.0, 0.1), Vector3(0.0, 0.0, -0.1), 0.07, 0.065, 6, G, head, 0, false, false)
	_limbs(mb)
	LookActorsKit.optic(mb, head, HEAD_RADII, 78.0, -0.02, 0.085, 0.7, 4, 0.5)
	var spill: Vector3 = head * Vector3(0.0, 0.06, -0.1)
	return LookActorsKit.finish(mb, SEED, 0.9, spill, 0.6, 0.35)


static func _limbs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		# four digitigrade legs: the knee goes up and out, the foot comes down close to the body
		for z: float in [0.02, 0.22]:
			var hip: Vector3 = Vector3(side * 0.12, 0.41, z)
			var knee: Vector3 = Vector3(side * 0.28, 0.58, z + 0.03)
			var foot: Vector3 = Vector3(side * 0.36, 0.0, z + 0.1)
			var broken: bool = side < 0.0 and z > 0.1
			if broken:
				foot = knee + Vector3(-0.05, -0.27, 0.02)
			mb.tint = LookActorsKit.frame(0.24 if broken else 0.2)
			LookActorsKit.limb2(mb, hip, knee, foot, 0.042, 0.036, 0.026 if not broken else 0.034, 5, G)
		# raised mantis forelimbs, claw tips forward
		var shoulder: Vector3 = Vector3(side * 0.12, 0.5, -0.14)
		var elbow: Vector3 = Vector3(side * 0.25, 0.86, -0.2)
		var wrist: Vector3 = Vector3(side * 0.15, 0.56, -0.44)
		if side < 0.0:
			elbow = Vector3(-0.24, 0.72, -0.18)  # the damaged arm hangs lower
		mb.tint = LookActorsKit.frame(0.22)
		LookActorsKit.limb2(mb, shoulder, elbow, wrist, 0.05, 0.04, 0.035, 5, G)
		mb.tint = LookActorsKit.plate(0.72)
		LookActorsKit.cone(mb, wrist + Vector3(0.0, 0.03, 0.04), wrist + Vector3(side * -0.02, -0.12, -0.1), 0.05, 5, C)
