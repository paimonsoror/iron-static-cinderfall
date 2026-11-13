class_name WeaponMeshes2
extends RefCounted
## The first four weapon models of V4-R (VARIETY_SPEC 3.5): scattergun, assault rifle, hornet rack and LMG. At most 350 triangles
## each, gunmetal with ceramic plates and one cyan accent, vertex colours baked like the Warden's own gear. Each one is readable from
## above by its length and one signature shape: the scattergun is short and thick with twin stacked barrels and a shell rack, the
## assault rifle is long with a top rail box and an angled magazine, the hornet rack is a block of six tubes with lit mouths, the LMG is
## the longest of the three with a perforated shroud, a drum under the receiver and a bipod stub.
## Frames: grip near the origin, barrel toward -Z. The points are in weapon space (see `WeaponMeshes` for the table that uses them).

const G: StringName = WeaponParts.G
const C: StringName = WeaponParts.C
const L: StringName = WeaponParts.L

const SCATTER_MUZZLE: Vector3 = Vector3(0.0, 0.05, -0.52)
const SCATTER_GRIP_R: Vector3 = Vector3(0.0, -0.085, 0.025)
const SCATTER_GRIP_L: Vector3 = Vector3(0.0, -0.03, -0.2)
const SCATTER_MAG: Vector3 = Vector3(0.0, -0.03, -0.12)
const RIFLE_MUZZLE: Vector3 = Vector3(0.0, 0.04, -0.8)
const RIFLE_GRIP_R: Vector3 = Vector3(0.0, -0.085, 0.0)
const RIFLE_GRIP_L: Vector3 = Vector3(0.0, -0.05, -0.2)
const RIFLE_MAG: Vector3 = Vector3(0.0, -0.2, -0.2)
const HORNET_MUZZLE: Vector3 = Vector3(0.0, 0.05, -0.46)
const HORNET_GRIP_R: Vector3 = Vector3(0.0, -0.075, 0.03)
const HORNET_GRIP_L: Vector3 = Vector3(0.0, -0.06, -0.2)
const HORNET_MAG: Vector3 = Vector3(0.0, -0.02, -0.14)
const LMG_MUZZLE: Vector3 = Vector3(0.0, 0.045, -1.0)
const LMG_GRIP_R: Vector3 = Vector3(0.0, -0.085, 0.0)
const LMG_GRIP_L: Vector3 = Vector3(0.0, -0.06, -0.2)
const LMG_MAG: Vector3 = Vector3(0.0, -0.2, -0.17)


## Scattergun: a short thick receiver, two stacked barrels in two collars, a pale pump forend, a stock, a grip and on its right flank a
## pale shell rack with four cyan shell caps.
static func scattergun() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = WeaponParts.grey(0.66)
	LookDevShapes.bevel_box(mb, Vector3(0.1, 0.12, 0.3), WeaponParts.at(0.0, 0.04, -0.1), G, 0.016)
	mb.tint = WeaponParts.grey(0.48)
	WeaponParts.rod(mb, 0.0, 0.09, -0.24, -0.5, 0.036, 0.034, 8, G, false, true)  # the upper barrel
	WeaponParts.rod(mb, 0.0, 0.016, -0.24, -0.5, 0.036, 0.034, 8, G, false, true)  # the lower barrel
	mb.tint = WeaponParts.bone(0.6)
	for z: float in [-0.3, -0.46]:  # two collars round the pair
		WeaponParts.rod(mb, 0.0, 0.053, z, z - 0.04, 0.066, 0.066, 8, C, false, false)
	mb.tint = WeaponParts.bone(0.8)  # the pump forend
	LookDevShapes.bevel_box(mb, Vector3(0.086, 0.07, 0.15), WeaponParts.at(0.0, 0.0, -0.22), C, 0.014, Vector2.ONE, 0.0, false)
	mb.tint = WeaponParts.grey(0.4)
	LookDevShapes.bevel_box(mb, Vector3(0.06, 0.1, 0.15), WeaponParts.at(0.0, 0.02, 0.12), G, 0.014, Vector2.ONE, 0.0, false)
	WeaponParts.grip(mb, 0.03)
	mb.tint = WeaponParts.bone(0.66)  # the shell rack on the right flank
	LookDevShapes.bevel_box(mb, Vector3(0.02, 0.09, 0.2), WeaponParts.at(0.07, 0.04, -0.1), C, 0.008, Vector2.ONE, 0.0, false)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	for k: int in 4:
		mb.box(Vector3(0.02, 0.026, 0.026), WeaponParts.at(0.086, 0.04, -0.17 + 0.05 * float(k)), L)
	return WeaponParts.finish(mb)


## Assault rifle: a long receiver, a pale handguard, a thin barrel with a flash hider, a top rail with an optic box and a cyan lens,
## an angled magazine with a cyan window, a grip and a stock.
static func assault_rifle() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = WeaponParts.grey(0.66)
	LookDevShapes.bevel_box(mb, Vector3(0.078, 0.11, 0.4), WeaponParts.at(0.0, 0.04, -0.14), G, 0.014)
	mb.tint = WeaponParts.bone(0.72)
	LookDevShapes.bevel_box(mb, Vector3(0.07, 0.08, 0.26), WeaponParts.at(0.0, 0.035, -0.47), C, 0.014, Vector2.ONE, 0.0, false)
	mb.tint = WeaponParts.grey(0.5)
	WeaponParts.rod(mb, 0.0, 0.04, -0.58, -0.76, 0.016, 0.014, 4)
	WeaponParts.rod(mb, 0.0, 0.04, -0.74, -0.8, 0.026, 0.026, 4)
	mb.tint = WeaponParts.grey(0.8)
	LookDevShapes.bevel_box(mb, Vector3(0.03, 0.025, 0.36), WeaponParts.at(0.0, 0.108, -0.14), G, 0.008, Vector2.ONE, 0.0, false)
	mb.tint = WeaponParts.bone(0.6)  # the optic box on the rail
	LookDevShapes.bevel_box(mb, Vector3(0.05, 0.05, 0.12), WeaponParts.at(0.0, 0.14, -0.09), C, 0.01, Vector2.ONE, 0.0, false)
	mb.tint = WeaponParts.grey(0.26)  # the angled magazine
	var mag: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.32) * Basis(Vector3.BACK, PI), Vector3(0.0, -0.1, -0.22))
	LookDevShapes.bevel_box(mb, Vector3(0.05, 0.2, 0.07), mag, G, 0.012, Vector2.ONE, 0.0, true, true)
	WeaponParts.grip(mb, 0.0)
	mb.tint = WeaponParts.grey(0.4)
	LookDevShapes.bevel_box(mb, Vector3(0.06, 0.1, 0.2), WeaponParts.at(0.0, 0.02, 0.16), G, 0.014, Vector2.ONE, 0.0, false)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	mb.box(Vector3(0.034, 0.03, 0.012), WeaponParts.at(0.0, 0.146, -0.152), L)
	mb.box(Vector3(0.012, 0.09, 0.04), WeaponParts.at(0.03, -0.09, -0.19), L)
	return WeaponParts.finish(mb)


## Hornet rack: six tubes in three columns and two rows, each with a lit mouth, in a rear housing and two front straps, with a top rail
## carrying a cyan strip and a foregrip under the front. Held at the hip: short and wide.
static func hornet_rack() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = WeaponParts.grey(0.6)
	LookDevShapes.bevel_box(mb, Vector3(0.25, 0.19, 0.16), WeaponParts.at(0.0, 0.05, -0.1), G, 0.02)
	mb.tint = WeaponParts.grey(0.74)
	for col: float in [-1.0, 0.0, 1.0]:
		for row: float in [-1.0, 1.0]:
			WeaponParts.rod(mb, col * 0.072, 0.05 + row * 0.036, -0.18, -0.44, 0.034, 0.034, 6, G, false, false)
	mb.tint = WeaponParts.bone(0.7)  # two straps round the block
	for z: float in [-0.26, -0.4]:
		mb.box(Vector3(0.25, 0.02, 0.04), WeaponParts.at(0.0, 0.1, z), C)
		mb.box(Vector3(0.25, 0.02, 0.04), WeaponParts.at(0.0, 0.0, z), C)
		mb.box(Vector3(0.02, 0.1, 0.04), WeaponParts.at(-0.125, 0.05, z), C)
		mb.box(Vector3(0.02, 0.1, 0.04), WeaponParts.at(0.125, 0.05, z), C)
	mb.tint = WeaponParts.grey(0.8)
	LookDevShapes.bevel_box(mb, Vector3(0.03, 0.02, 0.4), WeaponParts.at(0.0, 0.15, -0.22), G, 0.008, Vector2.ONE, 0.0, false)
	WeaponParts.grip(mb, 0.03)
	WeaponParts.grip(mb, -0.2, Vector3(0.05, 0.1, 0.06), -0.1, -0.075)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	for col: float in [-1.0, 0.0, 1.0]:
		for row: float in [-1.0, 1.0]:
			WeaponParts.mouth(mb, Vector3(col * 0.072, 0.05 + row * 0.036, -0.445), Vector2(0.056, 0.056))
	mb.box(Vector3(0.016, 0.01, 0.26), WeaponParts.at(0.0, 0.162, -0.22), L)
	return WeaponParts.finish(mb)


## LMG: the longest of the new weapons: a receiver, a ceramic shroud with two dark vents on top, a long barrel, a drum with a cyan
## ring under the receiver, a bipod stub, a cyan top strip, a grip and a stock.
static func lmg() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = WeaponParts.grey(0.64)
	LookDevShapes.bevel_box(mb, Vector3(0.09, 0.13, 0.45), WeaponParts.at(0.0, 0.04, -0.16), G, 0.016)
	mb.tint = WeaponParts.bone(0.7)
	WeaponParts.rod(mb, 0.0, 0.045, -0.4, -0.76, 0.05, 0.05, 8, C, false, false)
	mb.tint = WeaponParts.grey(0.1)  # the perforations: two dark vents on the top of the shroud
	for z: float in [-0.5, -0.66]:
		mb.box(Vector3(0.03, 0.012, 0.05), WeaponParts.at(0.0, 0.094, z), G)
	mb.tint = WeaponParts.grey(0.5)
	WeaponParts.rod(mb, 0.0, 0.045, -0.74, -0.96, 0.018, 0.016, 6)
	WeaponParts.rod(mb, 0.0, 0.045, -0.94, -1.0, 0.03, 0.03, 6)
	mb.tint = WeaponParts.bone(0.62)  # the drum under the receiver, its axis across the weapon
	mb.cylinder(0.11, 0.11, 0.1, 8, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, -0.12, -0.17)), C)
	mb.tint = WeaponParts.grey(0.3)  # the bipod stub
	for side: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, Vector3(side * 0.03, 0.0, -0.78), Vector3(side * 0.07, -0.14, -0.86), 0.013, 0.01, 4, G, WeaponParts.ID, 0, true, true)
	mb.tint = WeaponParts.grey(0.8)
	LookDevShapes.bevel_box(mb, Vector3(0.03, 0.04, 0.2), WeaponParts.at(0.0, 0.12, -0.2), G, 0.008, Vector2.ONE, 0.0, false)
	WeaponParts.grip(mb, 0.0)
	mb.tint = WeaponParts.grey(0.4)
	LookDevShapes.bevel_box(mb, Vector3(0.07, 0.11, 0.22), WeaponParts.at(0.0, 0.0, 0.17), G, 0.014, Vector2.ONE, 0.0, false)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	mb.ring(0.05, 0.085, 8, Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.052, -0.12, -0.17)), L)
	mb.box(Vector3(0.016, 0.01, 0.2), WeaponParts.at(0.0, 0.142, -0.2), L)
	return WeaponParts.finish(mb)
