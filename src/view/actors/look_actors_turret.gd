class_name LookActorsTurret
extends RefCounted
## The hard-surface auto turret (W3-D; looks STYLISED and STYLISED_PLUS): a dark gunmetal tripod with a slewing ring and a
## yawing gun head with armour plates, a mantlet, twin shrouded barrels with muzzle brakes, a side ammo box with a feed,
## a single cyan sensor lens, a cyan status strip and a short antenna. Friendly colours: dark metal, clean off-white plates
## (the Warden's `BONE_TINT`), cyan lights; never red. Same frames as `HeroMeshes`: the base stands on the pad (y = 0), the head
## is built around its yaw pivot (the node sits `HeroMeshes.TURRET_HEAD_Y` above the pad) and the barrels end at
## `HeroMeshes.TURRET_MUZZLE`, so the shots and the tracers leave from the same place as before.
## Materials are the Warden's roles (`LookDevMat`): gunmetal, ceramic and emit_cyan. About 600 triangles together.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
const SEED_BASE: int = 71
const SEED_HEAD: int = 73
const SKIP: Array[StringName] = [L]
const ID: Transform3D = Transform3D.IDENTITY


## Tripod base: three legs with foot pads, a column and the slewing ring under the head.
static func base() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var apex: Vector3 = Vector3(0.0, 0.5, 0.0)
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0 + PI * 0.5
		var foot: Vector3 = Vector3(cos(a) * 0.55, 0.05, sin(a) * 0.55)
		mb.tint = _frame(0.08)
		LookDevShapes.limb(mb, foot, apex, 0.06, 0.075, 6, G, ID, 0, true, false)
		mb.tint = _frame(0.06)
		mb.box(Vector3(0.2, 0.07, 0.2), Transform3D(Basis(Vector3.UP, -a), Vector3(foot.x, 0.035, foot.z)), G)
	mb.tint = _frame(0.11)
	LookDevShapes.limb(mb, Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.54, 0.0), 0.2, 0.16, 8, G, ID, 0, true, false)
	mb.tint = _frame(0.07)
	mb.cylinder(0.25, 0.25, 0.06, 10, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.52, 0.0)), G)
	return _finish(mb, SEED_BASE, 0.0, 0.6)


## Yawing head, origin = the yaw pivot (0.62 m above the pad).
static func head() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _frame(0.07)
	mb.cylinder(0.27, 0.27, 0.08, 8, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)), G)
	mb.tint = _frame(0.08)
	LookDevShapes.bevel_box(mb, Vector3(0.5, 0.24, 0.44), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.04)), G, 0.05, Vector2(0.9, 0.9), 0.0, true)
	mb.tint = _bone(0.8)
	LookDevShapes.bevel_box(mb, Vector3(0.3, 0.05, 0.26), Transform3D(Basis(Vector3.RIGHT, 0.06), Vector3(0.0, 0.34, 0.06)), C, 0.04, Vector2.ONE, 0.0, true, true)
	mb.tint = _frame(0.10)
	LookDevShapes.bevel_box(mb, Vector3(0.34, 0.2, 0.2), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.22, -0.3)), G, 0.04, Vector2.ONE, 0.0, true)
	for side: float in [-1.0, 1.0]:
		mb.tint = _frame(0.07)
		LookDevShapes.limb(mb, Vector3(side * 0.1, 0.22, -0.34), Vector3(side * 0.1, 0.22, -0.8), 0.045, 0.036, 6, G, ID, 0, true, true)
		mb.tint = _bone(0.78)
		LookDevShapes.limb(mb, Vector3(side * 0.1, 0.22, -0.4), Vector3(side * 0.1, 0.22, -0.58), 0.066, 0.06, 6, C, ID, 0, true, true)
	# ammo box on the right with a feed to the gun
	mb.tint = _frame(0.10)
	LookDevShapes.bevel_box(mb, Vector3(0.14, 0.2, 0.26), Transform3D(Basis.IDENTITY, Vector3(0.34, 0.18, 0.02)), G, 0.03, Vector2.ONE, 0.0, true)
	mb.tint = _bone(0.7)
	LookDevShapes.bevel_box(mb, Vector3(0.12, 0.03, 0.2), Transform3D(Basis.IDENTITY, Vector3(0.34, 0.285, 0.02)), C, 0.02, Vector2.ONE, 0.0, true, true)
	# antenna, the cyan sensor lens and a status strip
	mb.tint = _frame(0.07)
	LookDevShapes.limb(mb, Vector3(-0.18, 0.32, 0.2), Vector3(-0.2, 0.62, 0.22), 0.011, 0.008, 4, G, ID, 0, true, true)
	mb.tint = Color.WHITE
	var _lights: int = mb.begin_part()
	mb.cylinder(0.05, 0.05, 0.04, 6, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.375, -0.1)), L)
	mb.box(Vector3(0.24, 0.02, 0.012), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.265)), L)
	mb.box(Vector3(0.025, 0.025, 0.025), Transform3D(Basis.IDENTITY, Vector3(-0.2, 0.625, 0.22)), L)
	return _finish(mb, SEED_HEAD, HeroMeshes.TURRET_HEAD_Y, 0.01)


static func _finish(mb: MeshBuilder, seed_i: int, ground_y: float, grime_height: float) -> ArrayMesh:
	LookDevBake.ao(mb, 0.8, 0.12, 0.3, ground_y, 0.45, 0.1, SKIP)
	LookActorsGrit.bake(mb, seed_i, grime_height, 0.3, 0.3, SKIP)
	return mb.build()


static func _frame(k: float) -> Color:
	return Color(k * 0.95, k, minf(k * 1.05, 1.0), 1.0)


## The Warden's clean off-white: red and green pulled down, blue left alone (`LookDevWarden.BONE_TINT`).
static func _bone(k: float) -> Color:
	return Color(LookDevWarden.BONE_TINT.r * k, LookDevWarden.BONE_TINT.g * k, LookDevWarden.BONE_TINT.b * k, 1.0)
