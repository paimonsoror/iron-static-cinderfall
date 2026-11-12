class_name LookActorsHollow
extends RefCounted
## The hard-surface Hollow Warden (W3-D): a heavy, hunched biped 1.7 m high. Pale slab plates over a dark frame, a small dark
## helm sunk between broad shoulders that carries the single red visor bar on a dark bezel (no eyes, no face), long arms that
## hang to the knees ending in big fists. Original design: the upper body leans forward 11 degrees from the hips.
## Asymmetric damage: the left shoulder plate is gone (a bare frame stub shows) and that arm is thin and clawed, the right arm
## is a heavy plated ram, the chest slab covers only the right half of the chest (the left half is gone).
## Three surfaces (gunmetal, ceramic, emit_red), about 500 triangles, weathering baked in the vertex colours.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const HEAD_RADII: Vector3 = Vector3(0.14, 0.115, 0.15)
const SEED: int = 23


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	var up: Transform3D = Transform3D(Basis(Vector3.RIGHT, -0.19), Vector3(0.0, 0.9, 0.02))
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.bevel_box(mb, Vector3(0.6, 0.6, 0.38), up * LookActorsKit.at(0.0, 0.3, 0.0), G, 0.06, Vector2(1.32, 1.1), 0.0, true)
	var front: Basis = LookDevShapes.facing(Vector3(0.0, -0.06, -1.0))
	mb.tint = LookActorsKit.plate(0.95)
	LookDevShapes.bevel_box(mb, Vector3(0.4, 0.07, 0.36), up * Transform3D(front, Vector3(0.1, 0.52, -0.2)), C, 0.05, Vector2.ONE, 0.0, true, true)  # the right half of the slab: the left half is gone
	# shoulders: a big plated dome on the right, a bare frame stub on the left
	mb.tint = LookActorsKit.plate(0.9)
	LookDevShapes.ellipsoid(mb, Vector3(0.23, 0.17, 0.26), 8, 2, up * LookActorsKit.at(0.43, 0.7, 0.0), C, true)
	mb.tint = LookActorsKit.frame(0.28)
	LookDevShapes.ellipsoid(mb, Vector3(0.15, 0.1, 0.18), 6, 2, up * LookActorsKit.at(-0.45, 0.68, 0.0), G, true)
	_head(mb, up)
	_arms(mb, up)
	var spill: Vector3 = up * Vector3(0.0, 0.88, -0.3)
	return LookActorsKit.finish(mb, SEED, 1.7, spill, 0.6, 0.4)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(side * 0.17, 0.88, 0.0)
		var knee: Vector3 = Vector3(side * 0.2, 0.46, -0.1)
		var ankle: Vector3 = Vector3(side * 0.2, 0.12, 0.02)
		mb.tint = LookActorsKit.frame(0.22)
		LookActorsKit.limb2(mb, hip, knee, ankle, 0.15, 0.12, 0.085, 5, G)
		mb.tint = LookActorsKit.plate(0.85)  # a thigh plate down to the knee
		var thigh: Transform3D = LookDevShapes.frame_along(hip, knee, 0.5, Vector3(0.0, 0.15, 0.0), Vector3.FORWARD)
		LookDevShapes.bevel_box(mb, Vector3(0.2, 0.05, 0.36), thigh, C, 0.04, Vector2(0.8, 0.9), 0.0, true, true)
		mb.tint = LookActorsKit.frame(0.16)
		LookDevShapes.bevel_box(mb, Vector3(0.25, 0.12, 0.42), LookActorsKit.at(side * 0.2, 0.06, -0.06), G, 0.05, Vector2.ONE, 0.0, true, true)


static func _head(mb: MeshBuilder, up: Transform3D) -> void:
	var head: Transform3D = up * LookActorsKit.at(0.0, 0.82, -0.12)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, up * Vector3(0.0, 0.66, -0.04), up * Vector3(0.0, 0.8, -0.1), 0.08, 0.07, 5, G, LookActorsKit.ID, 0, false, false)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G)
	mb.tint = LookActorsKit.plate(0.88)  # a pale brow plate over the dark helm
	LookDevShapes.ellipsoid(mb, Vector3(0.06, 0.06, 0.14), 6, 2, head * LookActorsKit.at(0.0, 0.08, 0.02), C, true)
	LookActorsKit.optic(mb, head, HEAD_RADII, 70.0, -0.025, 0.045, 0.3, 4, 0.5)


static func _arms(mb: MeshBuilder, up: Transform3D) -> void:
	# right: a heavy plated ram that hangs to the knee
	var sr: Vector3 = up * Vector3(0.5, 0.66, 0.0)
	var er: Vector3 = up * Vector3(0.53, 0.3, -0.06)
	var wr: Vector3 = up * Vector3(0.49, 0.0, -0.16)
	mb.tint = LookActorsKit.frame(0.24)
	LookActorsKit.limb2(mb, sr, er, wr, 0.115, 0.105, 0.09, 5, G)
	mb.tint = LookActorsKit.plate(0.8)
	LookDevShapes.bevel_box(mb, Vector3(0.22, 0.2, 0.26), Transform3D(Basis(Vector3.RIGHT, -0.19), wr + Vector3(0.0, -0.1, -0.02)), C, 0.05, Vector2.ONE, 0.0, true, true)
	# left: a thin arm with a claw
	var sl: Vector3 = up * Vector3(-0.42, 0.62, 0.0)
	var el: Vector3 = up * Vector3(-0.5, 0.28, -0.1)
	var wl: Vector3 = up * Vector3(-0.44, -0.02, -0.26)
	mb.tint = LookActorsKit.frame(0.2)
	LookActorsKit.limb2(mb, sl, el, wl, 0.07, 0.06, 0.05, 5, G)
	mb.tint = LookActorsKit.plate(0.6)
	LookActorsKit.cone(mb, wl + Vector3(0.0, 0.0, 0.0), wl + Vector3(0.03, -0.2, -0.1), 0.045, 4, C)
