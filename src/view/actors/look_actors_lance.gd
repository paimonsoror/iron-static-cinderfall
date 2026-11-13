class_name LookActorsLance
extends RefCounted
## The hard-surface Lance Platform (V4-R; VARIETY_SPEC 6, NODE 5): a mobile gun platform 3.2 m high that plants itself, so it stands
## on four long splayed hydraulic legs with wide foot pads under a dark deck and a pale armoured turret. The turret carries the
## lance, a barrel 2.6 m long with twin side rails, five pale coil rings and a muzzle block, pointing along -Z (the machine
## faces the core), vent louvres on the turret flanks (the charge opens them), a capacitor bank on its rear and a sensor head on a neck
## above the front that holds the single red optic. The long thin barrel is the silhouette: nothing else on the field is a line.
## Three surfaces (gunmetal, ceramic, emit_red), about 900 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 103
const BARREL_Y: float = 2.45
const HEAD_AT: Vector3 = Vector3(0.0, 3.0, -0.1)
const HEAD_RADII: Vector3 = Vector3(0.36, 0.28, 0.4)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	_turret(mb)
	_lance(mb)
	var head: Transform3D = Transform3D(Basis.IDENTITY, HEAD_AT)
	mb.tint = LookActorsKit.frame(0.18)
	LookDevShapes.limb(mb, Vector3(0.0, 2.7, -0.1), Vector3(0.0, 2.9, -0.1), 0.2, 0.17, 6, G, LookActorsKit.ID, 0, true, false)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 8, 2, head, G)
	LookActorsKit.optic(mb, head, HEAD_RADII, 62.0, 0.02, 0.12, 0.6, 4, 0.5)
	var spill: Vector3 = HEAD_AT + Vector3(0.0, 0.1, -0.4)
	return LookActorsKit.finish(mb, SEED, 3.2, spill, 0.55, 0.4, 0.8, 0.2)


static func _legs(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.28)  # the deck
	LookDevShapes.bevel_box(mb, Vector3(2.0, 0.5, 2.3), LookActorsKit.at(0.0, 1.5, 0.1), G, 0.08, Vector2.ONE, 0.0, true)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hip: Vector3 = Vector3(sx * 0.85, 1.4, sz * 0.9 + 0.1)
			var knee: Vector3 = Vector3(sx * 1.35, 1.75, sz * 1.4 + 0.1)
			var foot_at: Vector3 = Vector3(sx * 1.45, 0.0, sz * 1.5 + 0.1)
			LookActorsParts.leg(mb, hip, knee, foot_at, 0.2, 0.17, 0.12, 6, 0.22)
			mb.tint = LookActorsKit.plate(0.72)  # a pale armour collar on the knee
			LookDevShapes.limb(mb, knee + Vector3(0.0, 0.05, 0.0), knee + Vector3(0.0, 0.25, 0.0), 0.22, 0.22, 6, C, LookActorsKit.ID, 0, false, false)
			mb.tint = LookActorsKit.frame(0.14)
			LookActorsParts.foot(mb, foot_at.x, foot_at.z, 0.45, 0.45)


static func _turret(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.18)
	mb.cylinder(0.8, 0.9, 0.25, 12, LookActorsKit.at(0.0, 1.88, 0.1), G)
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.bevel_box(mb, Vector3(1.1, 0.7, 1.4), LookActorsKit.at(0.0, BARREL_Y, 0.2), G, 0.07, Vector2.ONE, 0.0, true)
	mb.tint = LookActorsKit.plate(0.88)  # a pale cover over the top
	LookDevShapes.bevel_box(mb, Vector3(0.96, 0.1, 1.2), LookActorsKit.at(0.0, 2.84, 0.2), C, 0.05, Vector2.ONE, 0.0, true, true)
	mb.tint = LookActorsKit.plate(0.7)  # vent louvres on both flanks
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.1, 0.2, 0.5]:
			mb.box(Vector3(0.05, 0.46, 0.1), LookActorsKit.at(side * 0.57, BARREL_Y, z), C)
	mb.tint = LookActorsKit.frame(0.3)  # the capacitor bank on the rear
	LookDevShapes.bevel_box(mb, Vector3(0.9, 0.6, 0.7), LookActorsKit.at(0.0, 2.35, 1.1), G, 0.06, Vector2.ONE, 0.0, true)
	mb.tint = LookActorsKit.plate(0.66)
	for side: float in [-1.0, 1.0]:
		LookActorsParts.dome(mb, Vector3(0.18, 0.2, 0.18), Vector3(side * 0.3, 2.65, 1.1), Vector3.UP, C, 6, 1)


## The lance: a barrel with twin side rails, five pale coil rings and a muzzle block.
static func _lance(mb: MeshBuilder) -> void:
	var from: Vector3 = Vector3(0.0, BARREL_Y, -0.5)
	var to: Vector3 = Vector3(0.0, BARREL_Y, -3.0)
	mb.tint = LookActorsKit.frame(0.22)
	LookDevShapes.limb(mb, from, to, 0.2, 0.15, 8, G, LookActorsKit.ID, 0, true, true)
	for side: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, from + Vector3(side * 0.28, -0.12, -0.1), to + Vector3(side * 0.24, -0.12, 0.2), 0.07, 0.06, 6, G, LookActorsKit.ID, 0, true, true)
	mb.tint = LookActorsKit.plate(0.8)
	for k: int in 5:
		var z: float = -0.85 - 0.45 * float(k)
		LookDevShapes.limb(mb, Vector3(0.0, BARREL_Y, z), Vector3(0.0, BARREL_Y, z - 0.14), 0.3, 0.3, 8, C, LookActorsKit.ID, 0, false, false)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.bevel_box(mb, Vector3(0.5, 0.4, 0.5), LookActorsKit.at(0.0, BARREL_Y, -3.1), G, 0.05, Vector2.ONE, 0.0, true)
