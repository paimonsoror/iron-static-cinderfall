class_name LookActorsTremor
extends RefCounted
## The hard-surface Tremor Rig (V4-R; VARIETY_SPEC 6, NODE 7): a stomping drill rig 3.4 m high. A dark chassis on four massive piston
## legs that end in broad finned stomp pads (from above: four discs at the corners), a lattice derrick of four slanted legs and two
## braces rising to a pale crown with the sensor head and the single red optic, a big auger on the front pointing forward and down (the
## breach points it opens) and an engine block with two stacks behind. Four discs and a tower: nothing else is symmetrical like this.
## Three surfaces (gunmetal, ceramic, emit_red), about 850 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const SEED: int = 109
const CROWN_AT: Vector3 = Vector3(0.0, 3.1, 0.0)
const HEAD_AT: Vector3 = Vector3(0.0, 3.3, -0.12)
const HEAD_RADII: Vector3 = Vector3(0.26, 0.2, 0.28)


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_chassis(mb)
	_pistons(mb)
	_derrick(mb)
	_auger(mb)
	var head: Transform3D = Transform3D(Basis.IDENTITY, HEAD_AT)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 8, 2, head, G)
	LookActorsKit.optic(mb, head, HEAD_RADII, 62.0, 0.0, 0.08, 0.6, 4, 0.5)
	var spill: Vector3 = HEAD_AT + Vector3(0.0, 0.0, -0.3)
	return LookActorsKit.finish(mb, SEED, 3.4, spill, 0.55, 0.4, 0.8, 0.2)


static func _chassis(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.bevel_box(mb, Vector3(2.4, 0.9, 2.2), LookActorsKit.at(0.0, 1.55, 0.0), G, 0.09, Vector2.ONE, 0.0, true)
	mb.tint = LookActorsKit.plate(0.86)  # pale cover plates on the top, left and right of the derrick
	for side: float in [-1.0, 1.0]:
		LookDevShapes.bevel_box(mb, Vector3(0.7, 0.1, 1.9), LookActorsKit.at(side * 0.85, 2.04, 0.0), C, 0.05, Vector2.ONE, 0.0, true, true)
	mb.tint = LookActorsKit.frame(0.28)  # the engine block with two stacks on the rear
	LookDevShapes.bevel_box(mb, Vector3(1.2, 0.8, 0.7), LookActorsKit.at(0.0, 1.75, 1.4), G, 0.06, Vector2.ONE, 0.0, true)
	mb.tint = LookActorsKit.frame(0.16)
	for side: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, Vector3(side * 0.34, 2.1, 1.5), Vector3(side * 0.34, 2.85, 1.55), 0.12, 0.09, 6, G, LookActorsKit.ID, 0, true, true)


## Four massive piston legs: a sleeve and a rod to a broad stomp pad with two fins.
static func _pistons(mb: MeshBuilder) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var top: Vector3 = Vector3(sx * 1.05, 1.5, sz * 0.95)
			var low: Vector3 = Vector3(sx * 1.2, 0.3, sz * 1.1)
			mb.tint = LookActorsKit.frame(0.24)
			LookDevShapes.limb(mb, top, low, 0.3, 0.26, 8, G, LookActorsKit.ID, 0, true, true)
			mb.tint = LookActorsKit.plate(0.78)
			LookDevShapes.limb(mb, top + Vector3(0.0, -0.1, 0.0), top + Vector3(sx * 0.05, -0.55, sz * 0.06), 0.36, 0.36, 8, C, LookActorsKit.ID, 0, false, false)
			mb.tint = LookActorsKit.frame(0.16)
			mb.cylinder(0.55, 0.6, 0.3, 8, LookActorsKit.at(low.x, 0.15, low.z), G)
			mb.tint = LookActorsKit.plate(0.6)
			LookDevShapes.limb(mb, Vector3(low.x, 0.2, low.z), Vector3(low.x, 0.26, low.z), 0.66, 0.66, 8, C, LookActorsKit.ID, 0, false, false)


## A derrick: four slanted legs to a crown and two ring braces.
static func _derrick(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.22)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			LookDevShapes.limb(mb, Vector3(sx * 0.62, 2.0, sz * 0.55), Vector3(sx * 0.2, 3.0, sz * 0.2), 0.08, 0.06, 4, G, LookActorsKit.ID, 0, true, true)
	for level: float in [0.35, 0.7]:
		var half: Vector2 = Vector2(lerpf(0.62, 0.2, level), lerpf(0.55, 0.2, level))
		var y: float = lerpf(2.0, 3.0, level)
		LookActorsParts.ring(mb, Vector3(0.0, y, 0.0), Vector3.RIGHT, Vector3.BACK, half.x * 1.2, 0.045, 4, 3, G)
	mb.tint = LookActorsKit.plate(0.9)
	LookDevShapes.bevel_box(mb, Vector3(0.7, 0.3, 0.7), LookActorsKit.at(CROWN_AT.x, CROWN_AT.y, CROWN_AT.z), C, 0.06, Vector2.ONE, 0.0, true)


## The auger on the front, pointing forward and down: a collar block, a fat cone with a banded middle.
static func _auger(mb: MeshBuilder) -> void:
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.bevel_box(mb, Vector3(0.9, 0.7, 0.5), LookActorsKit.at(0.0, 1.35, -1.25), G, 0.06, Vector2.ONE, 0.0, true)
	var a: Vector3 = Vector3(0.0, 1.3, -1.45)
	var b: Vector3 = Vector3(0.0, 0.62, -2.5)
	mb.tint = LookActorsKit.plate(0.78)
	LookDevShapes.limb(mb, a, a.lerp(b, 0.5), 0.42, 0.3, 8, C, LookActorsKit.ID, 0, true, false)
	mb.tint = LookActorsKit.frame(0.18)
	LookDevShapes.limb(mb, a.lerp(b, 0.5), b, 0.3, 0.0, 8, G, LookActorsKit.ID, 0, false, false)
