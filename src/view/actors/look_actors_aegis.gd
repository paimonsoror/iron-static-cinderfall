class_name LookActorsAegis
extends RefCounted
## The hard-surface Aegis Array (V4-R; VARIETY_SPEC 6, NODE 6): a ward fortress 3.2 m high. A faceted hex chassis on four stubby legs,
## three hex sockets on its top (where the ward pylons dock), a central column and six tall pale panels that lean outward round it
## like the petals of a phased array: from above a star of six plates, a shape no other machine has. The column ends in a sensor
## head with the single red optic. The pylons (`LookActorsPylon`) orbit it at 2.2 m, outside the panels.
## Three surfaces (gunmetal, ceramic, emit_red), about 780 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 107
const COLUMN_TOP: float = 2.7
const HEAD_AT: Vector3 = Vector3(0.0, 2.95, 0.0)
const HEAD_RADII: Vector3 = Vector3(0.4, 0.3, 0.4)
const PANEL_LEAN: float = 0.5
const PANEL_SIZE: Vector3 = Vector3(0.82, 1.4, 0.1)
const PANEL_AT: float = 0.95


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_chassis(mb)
	_column(mb)
	_panels(mb)
	var head: Transform3D = Transform3D(Basis.IDENTITY, HEAD_AT)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 8, 2, head, G)
	mb.tint = LookActorsKit.plate(0.8)
	LookActorsParts.dome(mb, Vector3(0.26, 0.16, 0.34), HEAD_AT + Vector3(0.0, 0.22, 0.08), Vector3.UP, C, 6, 1)
	LookActorsKit.optic(mb, head, HEAD_RADII, 64.0, -0.02, 0.08, 0.7, 4, 0.5)
	var spill: Vector3 = HEAD_AT + Vector3(0.0, 0.0, -0.4)
	return LookActorsKit.finish(mb, SEED, 3.2, spill, 0.55, 0.4, 0.8, 0.2)


static func _chassis(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.28)
	LookDevShapes.ellipsoid(mb, Vector3(1.25, 0.5, 1.25), 6, 2, LookActorsKit.at(0.0, 0.95, 0.0), G)
	mb.tint = LookActorsKit.plate(0.7)  # a pale skirt plate round the chassis
	LookActorsParts.dome(mb, Vector3(1.1, 0.28, 1.1), Vector3(0.0, 1.2, 0.0), Vector3.UP, C, 6, 2)
	for sx: float in [-1.0, 1.0]:  # four stubby legs
		for sz: float in [-1.0, 1.0]:
			var top: Vector3 = Vector3(sx * 0.9, 0.9, sz * 0.8)
			var bottom: Vector3 = Vector3(sx * 1.1, 0.0, sz * 1.0)
			mb.tint = LookActorsKit.frame(0.2)
			LookDevShapes.limb(mb, top, bottom, 0.26, 0.2, 6, G, LookActorsKit.ID, 0, true, false)
			mb.tint = LookActorsKit.frame(0.14)
			LookActorsParts.foot(mb, bottom.x, bottom.z, 0.36, 0.36)
	mb.tint = LookActorsKit.frame(0.12)  # three hex docks on the top where the pylons plug in
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0 + PI
		mb.cylinder(0.2, 0.24, 0.1, 6, LookActorsKit.at(cos(a) * 0.95, 1.35, sin(a) * 0.95), G)


static func _column(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.22)
	LookDevShapes.limb(mb, Vector3(0.0, 1.2, 0.0), Vector3(0.0, COLUMN_TOP, 0.0), 0.4, 0.28, 8, G, LookActorsKit.ID, 0, true, true)
	mb.tint = LookActorsKit.plate(0.78)
	for y: float in [1.7, 2.2]:
		LookDevShapes.limb(mb, Vector3(0.0, y, 0.0), Vector3(0.0, y + 0.1, 0.0), 0.46 - 0.08 * (y - 1.7), 0.46 - 0.08 * (y - 1.7), 8, C, LookActorsKit.ID, 0, false, false)


## Six panels round the column, each leaning out at the top, with a dark strut back to the column.
static func _panels(mb: MeshBuilder) -> void:
	for k: int in 6:
		var phi: float = TAU * float(k) / 6.0
		var out: Vector3 = Vector3(sin(phi), 0.0, -cos(phi))
		var centre: Vector3 = out * PANEL_AT + Vector3(0.0, 2.05, 0.0)
		var normal: Vector3 = out * cos(PANEL_LEAN) + Vector3(0.0, -sin(PANEL_LEAN), 0.0)
		var basis: Basis = Basis.looking_at(normal, Vector3.UP)
		mb.tint = LookActorsKit.plate(0.9 - 0.06 * float(k % 3))
		LookDevShapes.bevel_box(mb, PANEL_SIZE, Transform3D(basis, centre), C, 0.06, Vector2.ONE, 0.0, true)
		mb.tint = LookActorsKit.frame(0.2)
		LookDevShapes.limb(mb, Vector3(0.0, 1.6, 0.0) + out * 0.28, centre + out * 0.02, 0.04, 0.035, 3, G, LookActorsKit.ID, 0, true, true)
