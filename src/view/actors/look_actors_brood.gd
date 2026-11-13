class_name LookActorsBrood
extends RefCounted
## The hard-surface Brood Carrier (V4-R; VARIETY_SPEC 6, NODE 3): a walking hive 3.0 m high. A huge dark abdomen under a pale dome
## that carries six hex hatch cells in two rows (it releases six motes at a time), two rear brood sacs, a smaller thorax and a low head
## that carries the single red optic between two mandibles, all on six armoured insect legs (hip, knee up and out, foot down). The
## silhouette is a wide domed body on a spread of legs: a nest on stilts, nothing like the Hulk's hunched brute.
## Three surfaces (gunmetal, ceramic, emit_red), about 980 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 101
const ABDOMEN_AT: Vector3 = Vector3(0.0, 1.95, 0.55)
const ABDOMEN_RADII: Vector3 = Vector3(1.05, 0.8, 1.25)
const DOME_AT: Vector3 = Vector3(0.0, 2.35, 0.5)
const DOME_RADII: Vector3 = Vector3(1.0, 0.55, 1.15)
const HEAD_AT: Vector3 = Vector3(0.0, 1.6, -1.4)
const HEAD_RADII: Vector3 = Vector3(0.3, 0.24, 0.34)
const LEG_Z: Array[float] = [-0.85, 0.1, 0.95]


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	_hive(mb)
	_head(mb)
	var spill: Vector3 = HEAD_AT + Vector3(0.0, 0.1, -0.3)
	return LookActorsKit.finish(mb, SEED, 3.0, spill, 0.55, 0.4, 0.8, 0.2)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in LEG_Z:
			var hip: Vector3 = Vector3(side * 0.85, 1.7, z)
			var knee: Vector3 = Vector3(side * 1.6, 2.4, z * 1.15)
			var foot_at: Vector3 = Vector3(side * 1.78, 0.0, z * 1.3)
			LookActorsParts.leg(mb, hip, knee, foot_at, 0.17, 0.14, 0.08, 5, 0.24)
			mb.tint = LookActorsKit.plate(0.8)  # a pale plate on the thigh, a dome on the knee
			var plate: Transform3D = LookDevShapes.frame_along(hip, knee, 0.5, Vector3(0.0, 0.17, 0.0), Vector3.UP)
			LookDevShapes.bevel_box(mb, Vector3(0.26, 0.06, 0.6), plate, C, 0.04, Vector2.ONE, 0.0, true, true)
			mb.tint = LookActorsKit.plate(0.66)
			LookActorsParts.dome(mb, Vector3(0.18, 0.12, 0.18), knee + Vector3(0.0, 0.06, 0.0), Vector3.UP, C, 5, 1)
			mb.tint = LookActorsKit.frame(0.14)
			LookActorsParts.foot(mb, foot_at.x, foot_at.z, 0.22, 0.22)


static func _hive(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.28)
	LookDevShapes.ellipsoid(mb, ABDOMEN_RADII, 10, 2, Transform3D(Basis.IDENTITY, ABDOMEN_AT), G)
	mb.tint = LookActorsKit.frame(0.2)  # a smaller thorax between the abdomen and the head
	LookDevShapes.ellipsoid(mb, Vector3(0.7, 0.55, 0.7), 8, 2, LookActorsKit.at(0.0, 1.85, -0.85), G)
	mb.tint = LookActorsKit.plate(0.9)
	LookActorsParts.dome(mb, DOME_RADII, DOME_AT, Vector3.UP, C, 10, 2)
	mb.tint = LookActorsKit.plate(0.72)  # a pale cap over the thorax
	LookActorsParts.dome(mb, Vector3(0.62, 0.32, 0.6), Vector3(0.0, 2.18, -0.85), Vector3.UP, C, 8, 2)
	for side: float in [-1.0, 1.0]:  # two brood sacs on the rear flanks
		mb.tint = LookActorsKit.plate(0.6)
		LookDevShapes.ellipsoid(mb, Vector3(0.36, 0.4, 0.42), 6, 2, LookActorsKit.at(side * 0.62, 1.62, 1.55), C)
	# six hatch cells on the crown of the dome: two columns of three
	for col: float in [-1.0, 1.0]:
		for z: float in [-0.05, 0.5, 1.05]:
			var x: float = col * 0.38
			var inside: float = maxf(0.0, 1.0 - pow(x / DOME_RADII.x, 2.0) - pow((z - DOME_AT.z) / DOME_RADII.z, 2.0))
			var y: float = DOME_AT.y + DOME_RADII.y * sqrt(inside) - 0.03
			mb.tint = LookActorsKit.frame(0.16)
			mb.cylinder(0.24, 0.28, 0.12, 6, LookActorsKit.at(x, y, z), G)


static func _head(mb: MeshBuilder) -> void:
	var head: Transform3D = Transform3D(Basis.IDENTITY, HEAD_AT)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G)
	mb.tint = LookActorsKit.plate(0.8)
	LookActorsParts.dome(mb, Vector3(0.14, 0.1, 0.3), HEAD_AT + Vector3(0.0, 0.14, 0.04), Vector3.UP, C, 6, 1)
	LookActorsKit.optic(mb, head, HEAD_RADII, 62.0, 0.04, 0.12, 0.9, 4, 0.5)
	mb.tint = LookActorsKit.plate(0.7)  # two mandibles
	for side: float in [-1.0, 1.0]:
		LookActorsKit.cone(mb, HEAD_AT + Vector3(side * 0.18, -0.1, -0.22), HEAD_AT + Vector3(side * 0.1, -0.5, -0.7), 0.1, 6, C)
