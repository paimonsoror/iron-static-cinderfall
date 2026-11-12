class_name LookActorsHulk
extends RefCounted
## The hard-surface Siege Hulk (W3-D): the heaviest and most menacing machine of the field, 3.4 m high, in the quadruped
## stance of the GDD (hunched, knuckles on the ground). A pitched dark frame under rounded off-white armour: two huge
## shoulder blocks with swept spikes, pillar forearms ending in big fists, short hind legs, a small head sunk between the
## shoulders with the single red optic band, and a red core in a dark housing on the chest (a lit core, not an eye), a few
## cables on the back. Asymmetric damage: the left shoulder plate is cracked off its block and one spike is broken, the right
## fist wears extra armour. Same placement as the old mesh (the frame pivots at the same point), so the footprint is unchanged.
## Three surfaces (gunmetal, ceramic, emit_red), about 1,300 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const R: StringName = &"emit_red"
const HEAD_RADII: Vector3 = Vector3(0.38, 0.3, 0.38)
const PIVOT: Vector3 = Vector3(0.0, 1.6, 0.3)
const PITCH: float = -0.314
const SEED: int = 53


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var frame: Transform3D = Transform3D(Basis(Vector3.RIGHT, PITCH), PIVOT)
	_body(mb, frame)
	_shoulders(mb, frame)
	_arms(mb, frame)
	_hind_legs(mb)
	var head: Transform3D = frame * LookActorsKit.at(0.0, 1.5, -0.62)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, frame * Vector3(0.0, 1.1, -0.3), frame * Vector3(0.0, 1.4, -0.55), 0.3, 0.26, 8, G, LookActorsKit.ID, 0, false, false)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 8, 2, head, G)
	mb.tint = LookActorsKit.plate(0.85)  # a pale brow plate over the dark helm
	LookDevShapes.ellipsoid(mb, Vector3(0.2, 0.15, 0.36), 8, 2, head * LookActorsKit.at(0.0, 0.16, 0.04), C, true)
	LookActorsKit.optic(mb, head, HEAD_RADII, 72.0, -0.08, 0.15, 0.4, 5, 0.5)
	_cables(mb, frame)
	var spill: Vector3 = head * Vector3(0.0, 0.05, -0.3)
	return LookActorsKit.finish(mb, SEED, 3.4, spill, 0.55, 0.4, 0.8, 0.2)


static func _body(mb: MeshBuilder, frame: Transform3D) -> void:
	mb.tint = LookActorsKit.frame(0.4)
	LookDevRound.rounded_box(mb, Vector3(1.9, 1.3, 1.7), frame * LookActorsKit.at(0.0, 0.6, 0.0), G, 0.22)
	mb.tint = LookActorsKit.plate(0.78)  # back hump: a dome, not a slab
	LookDevShapes.ellipsoid(mb, Vector3(0.95, 0.42, 0.9), 10, 2, frame * LookActorsKit.at(0.0, 1.2, 0.2), C, true)
	mb.tint = LookActorsKit.frame(0.16)  # two exhaust stacks on the back
	for sx: float in [-0.45, 0.45]:
		LookDevShapes.limb(mb, frame * Vector3(sx, 1.25, 0.85), frame * Vector3(sx, 1.95, 0.95), 0.14, 0.1, 6, G, LookActorsKit.ID, 0, true, true)
	var front: Basis = LookDevShapes.facing(Vector3(0.0, -0.1, -1.0))  # chest slab
	mb.tint = LookActorsKit.plate(0.9)
	LookDevShapes.bevel_box(mb, Vector3(1.3, 0.12, 0.74), frame * Transform3D(front, Vector3(0.0, 0.42, -0.88)), C, 0.08, Vector2.ONE, 0.0, true, true)
	# the chest core: a dark housing, a dim halo disc and the bright core (6 sided, facing forward)
	var face: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	mb.tint = LookActorsKit.frame(0.14)
	mb.cylinder(0.46, 0.46, 0.14, 6, frame * Transform3D(face, Vector3(0.0, 0.84, -0.9)), G)
	mb.tint = Color(0.4, 0.4, 0.4, 1.0)
	var _halo: int = mb.begin_part()
	mb.cylinder(0.38, 0.38, 0.05, 6, frame * Transform3D(face, Vector3(0.0, 0.84, -0.96)), R)
	mb.tint = Color(0.8, 0.8, 0.8, 1.0)  # a lit core, a notch dimmer than the head optic (the only full-bright red)
	mb.cylinder(0.25, 0.25, 0.06, 6, frame * Transform3D(face, Vector3(0.0, 0.84, -0.985)), R)


static func _shoulders(mb: MeshBuilder, frame: Transform3D) -> void:
	for side: float in [-1.0, 1.0]:
		var at_pos: Vector3 = Vector3(side * 1.3, 1.05, -0.1)
		mb.tint = LookActorsKit.frame(0.3) if side < 0.0 else LookActorsKit.plate(0.9)
		LookDevRound.rounded_box(mb, Vector3(1.1, 0.95, 1.3), frame * Transform3D(Basis.IDENTITY, at_pos), G if side < 0.0 else C, 0.2)
		if side < 0.0:  # the cracked-off plate: a smaller, dirtier slab hanging on the block
			mb.tint = LookActorsKit.plate(0.66)
			LookDevShapes.bevel_box(mb, Vector3(0.7, 0.14, 0.9), frame * Transform3D(Basis(Vector3.FORWARD, 0.25), at_pos + Vector3(-0.1, 0.52, 0.0)), C, 0.06, Vector2.ONE, 0.0, true, true)
		if side > 0.0:  # a second, smaller armour layer on the intact shoulder
			mb.tint = LookActorsKit.plate(0.7)
			LookDevShapes.bevel_box(mb, Vector3(0.8, 0.12, 0.9), frame * Transform3D(Basis.IDENTITY, at_pos + Vector3(0.05, 0.55, 0.0)), C, 0.05, Vector2.ONE, 0.0, true, true)
		for k: int in 3:
			var z: float = -0.45 + 0.45 * float(k)
			var base: Vector3 = at_pos + Vector3(side * 0.15, 0.5, z)
			var tip: Vector3 = base + Vector3(side * 0.15, 0.62, 0.35)
			if side < 0.0 and k == 1:
				tip = base + Vector3(side * 0.05, 0.2, 0.1)  # the broken spike
			mb.tint = LookActorsKit.plate(0.78)
			LookActorsKit.cone(mb, frame * base, frame * tip, 0.14, 5, C)


static func _arms(mb: MeshBuilder, frame: Transform3D) -> void:
	for side: float in [-1.0, 1.0]:
		var top: Vector3 = frame * Vector3(side * 1.45, 0.7, -0.1)
		var knuckle: Vector3 = frame * Vector3(side * 1.5, -0.7, -1.0)
		mb.tint = LookActorsKit.frame(0.25)
		LookDevShapes.limb(mb, top, knuckle, 0.36, 0.42, 8, G, LookActorsKit.ID, 1, true, true)
		mb.tint = LookActorsKit.plate(0.84)
		var plate: Transform3D = LookDevShapes.frame_along(top, knuckle, 0.5, Vector3(side * 0.42, 0.0, 0.0), Vector3.UP)
		LookDevShapes.bevel_box(mb, Vector3(0.1, 0.5, 1.0), plate, C, 0.05, Vector2.ONE, 0.0, true, true)
		mb.tint = LookActorsKit.frame(0.2)
		var fist: Vector3 = frame * Vector3(side * 1.5, -0.85, -1.05)
		LookDevRound.rounded_box(mb, Vector3(0.95, 0.55, 0.95), Transform3D(Basis.IDENTITY, fist), G, 0.18)
		mb.tint = LookActorsKit.plate(0.7)  # knuckle spikes
		for k: int in 3:
			var kx: float = (float(k) - 1.0) * 0.3
			LookActorsKit.cone(mb, fist + Vector3(kx, 0.0, -0.4), fist + Vector3(kx, -0.1, -0.7), 0.1, 4, C)
		if side > 0.0:  # the right fist wears extra armour
			mb.tint = LookActorsKit.plate(0.78)
			LookDevShapes.bevel_box(mb, Vector3(0.8, 0.12, 0.7), Transform3D(Basis.IDENTITY, fist + Vector3(0.0, 0.32, 0.0)), C, 0.05, Vector2.ONE, 0.0, true, true)


static func _hind_legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		mb.tint = LookActorsKit.frame(0.24)
		LookDevShapes.bevel_box(mb, Vector3(0.8, 1.3, 0.9), LookActorsKit.at(side * 0.85, 0.65, 0.6), G, 0.1, Vector2(0.9, 0.9), 0.0, true)
		mb.tint = LookActorsKit.frame(0.16)
		LookDevShapes.bevel_box(mb, Vector3(1.0, 0.24, 1.3), LookActorsKit.at(side * 0.85, 0.12, 0.5), G, 0.08, Vector2.ONE, 0.0, true, true)
		mb.tint = LookActorsKit.plate(0.78)
		LookDevShapes.bevel_box(mb, Vector3(0.7, 0.2, 0.5), LookActorsKit.at(side * 0.85, 1.25, 0.25), C, 0.07, Vector2.ONE, 0.0, true, true)


static func _cables(mb: MeshBuilder, frame: Transform3D) -> void:
	mb.tint = LookActorsKit.frame(0.18)
	for cx: float in [-0.5, 0.5]:
		var a: Vector3 = frame * Vector3(cx, 1.5, 0.7)
		var b: Vector3 = frame * Vector3(cx * 2.0, 1.75, -0.3)
		var c: Vector3 = frame * Vector3(cx * 2.4, 1.15, -0.7)
		LookDevShapes.limb(mb, a, b, 0.09, 0.09, 5, G, LookActorsKit.ID, 0, true, false)
		LookDevShapes.limb(mb, b, c, 0.09, 0.07, 4, G, LookActorsKit.ID, 0, false, true)
