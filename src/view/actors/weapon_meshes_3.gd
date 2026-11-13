class_name WeaponMeshes3
extends RefCounted
## The last three weapon models of V4-R (VARIETY_SPEC 3.5): slag mortar, cutting torch and rail lance. At most 350 triangles each,
## gunmetal with ceramic plates and one cyan accent. The mortar is a fat short tube pitched up 35 degrees on a base plate with three
## ribs (its mouth is the highest point of anything the Warden carries), the torch has two gas tanks flanking the body and a cowled
## nozzle, the rail lance is the longest of all: two parallel rails, four brackets and a capacitor box at the rear.
## Frames: grip near the origin, barrel toward -Z. The points are in weapon space (see `WeaponMeshes` for the table that uses them).

const G: StringName = WeaponParts.G
const C: StringName = WeaponParts.C
const L: StringName = WeaponParts.L

const TUBE_PITCH: float = 0.61
const MORTAR_MUZZLE: Vector3 = Vector3(0.0, 0.32, -0.45)
const MORTAR_GRIP_R: Vector3 = Vector3(0.0, -0.085, 0.03)
const MORTAR_GRIP_L: Vector3 = Vector3(0.0, -0.03, -0.17)
const MORTAR_MAG: Vector3 = Vector3(0.0, 0.0, -0.1)
const TORCH_MUZZLE: Vector3 = Vector3(0.0, 0.045, -0.62)
const TORCH_GRIP_R: Vector3 = Vector3(0.0, -0.085, 0.02)
const TORCH_GRIP_L: Vector3 = Vector3(0.0, -0.05, -0.2)
const TORCH_MAG: Vector3 = Vector3(0.07, 0.0, 0.05)
const RAIL_MUZZLE: Vector3 = Vector3(0.0, 0.05, -1.13)
const RAIL_GRIP_R: Vector3 = Vector3(0.0, -0.085, 0.0)
const RAIL_GRIP_L: Vector3 = Vector3(0.0, -0.06, -0.2)
const RAIL_MAG: Vector3 = Vector3(0.0, -0.03, 0.12)


## Slag mortar: a fat ribbed tube on a base plate pitched up at 35 degrees with a flared mouth, a brace to the grip frame, a cyan strip
## along the top of the tube and a cyan breech light.
static func slag_mortar() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var dir: Vector3 = Vector3(0.0, sin(TUBE_PITCH), -cos(TUBE_PITCH))
	var base: Vector3 = Vector3(0.0, 0.0, -0.02)
	var tip: Vector3 = base + dir * 0.5
	mb.tint = WeaponParts.grey(0.6)
	LookDevShapes.limb(mb, base, tip, 0.075, 0.07, 10, G, WeaponParts.ID, 0, true, false)
	mb.tint = WeaponParts.bone(0.7)
	for t: float in [0.3, 0.5, 0.7]:  # three ribs
		var p: Vector3 = base + dir * 0.5 * t
		LookDevShapes.limb(mb, p - dir * 0.02, p + dir * 0.02, 0.098, 0.098, 10, C, WeaponParts.ID, 0, false, false)
	mb.tint = WeaponParts.bone(0.58)  # the flared mouth
	LookDevShapes.limb(mb, tip - dir * 0.06, tip + dir * 0.02, 0.07, 0.098, 10, C, WeaponParts.ID, 0, false, false)
	mb.tint = WeaponParts.grey(0.36)  # base plate under the breech
	LookDevShapes.bevel_box(mb, Vector3(0.18, 0.035, 0.22), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.0, -0.03, 0.02)), G, 0.012, Vector2.ONE, 0.0, true)
	mb.tint = WeaponParts.grey(0.28)  # a brace from the tube to the base
	LookDevShapes.limb(mb, Vector3(0.0, 0.16, -0.2), Vector3(0.0, -0.03, -0.12), 0.016, 0.014, 4, G, WeaponParts.ID, 0, true, true)
	WeaponParts.grip(mb, 0.03)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	var along: Transform3D = LookDevShapes.frame_along(base + dir * 0.06, base + dir * 0.4, 0.5, Vector3(0.0, 0.09, 0.0), Vector3.UP)
	mb.box(Vector3(0.016, 0.01, 0.34), along, L)
	mb.box(Vector3(0.03, 0.03, 0.012), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.0, 0.0, 0.07)), L)
	return WeaponParts.finish(mb)


## Cutting torch: a body with two gas tanks along its flanks (pale, with valves), a hose, a nozzle neck, a flared cowl and a nozzle with
## a cyan lit tip.
static func cutting_torch() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = WeaponParts.grey(0.64)
	LookDevShapes.bevel_box(mb, Vector3(0.07, 0.1, 0.26), WeaponParts.at(0.0, 0.04, -0.08), G, 0.014)
	mb.tint = WeaponParts.bone(0.7)  # the twin tanks
	for side: float in [-1.0, 1.0]:
		WeaponParts.rod(mb, side * 0.075, 0.02, 0.1, -0.2, 0.045, 0.045, 8, C)
		mb.tint = WeaponParts.grey(0.3)
		mb.box(Vector3(0.04, 0.03, 0.05), WeaponParts.at(side * 0.075, 0.07, -0.16), G)
		mb.tint = WeaponParts.bone(0.7)
	mb.tint = WeaponParts.grey(0.3)  # a hose from the tanks to the neck
	LookDevShapes.limb(mb, Vector3(-0.075, 0.07, -0.2), Vector3(0.0, 0.11, -0.28), 0.012, 0.012, 4, G, WeaponParts.ID, 0, true, true)
	LookDevShapes.limb(mb, Vector3(0.075, 0.07, -0.2), Vector3(0.0, 0.11, -0.28), 0.012, 0.012, 4, G, WeaponParts.ID, 0, true, true)
	mb.tint = WeaponParts.grey(0.52)
	WeaponParts.rod(mb, 0.0, 0.045, -0.2, -0.46, 0.03, 0.03, 6)
	mb.tint = WeaponParts.bone(0.6)  # the flared cowl
	LookDevShapes.limb(mb, Vector3(0.0, 0.045, -0.43), Vector3(0.0, 0.045, -0.6), 0.04, 0.078, 8, C, WeaponParts.ID, 0, false, false)
	mb.tint = WeaponParts.grey(0.7)
	WeaponParts.rod(mb, 0.0, 0.045, -0.5, -0.58, 0.02, 0.02, 6)
	WeaponParts.grip(mb, 0.02)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	WeaponParts.mouth(mb, Vector3(0.0, 0.045, -0.585), Vector2(0.044, 0.044))
	mb.box(Vector3(0.016, 0.012, 0.05), WeaponParts.at(0.0, 0.1, -0.06), L)
	return WeaponParts.finish(mb)


## Rail lance: a receiver, two long parallel rails with a cyan line between them, four brackets across them, a capacitor box at the
## rear with two cyan windows, a grip and a foregrip.
static func rail_lance() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = WeaponParts.grey(0.62)
	LookDevShapes.bevel_box(mb, Vector3(0.09, 0.1, 0.28), WeaponParts.at(0.0, 0.04, -0.06), G, 0.014)
	mb.tint = WeaponParts.grey(0.82)
	for side: float in [-1.0, 1.0]:
		LookDevShapes.bevel_box(mb, Vector3(0.02, 0.04, 1.05), WeaponParts.at(side * 0.032, 0.05, -0.6), G, 0.006, Vector2.ONE, 0.0, false)
	mb.tint = WeaponParts.bone(0.7)
	for z: float in [-0.25, -0.55, -0.85, -1.08]:  # four brackets
		mb.box(Vector3(0.11, 0.03, 0.04), WeaponParts.at(0.0, 0.078, z), C)
	mb.tint = WeaponParts.grey(0.4)  # the capacitor box on the rear
	LookDevShapes.bevel_box(mb, Vector3(0.12, 0.14, 0.22), WeaponParts.at(0.0, 0.04, 0.12), G, 0.016)
	WeaponParts.grip(mb, 0.0)
	WeaponParts.grip(mb, -0.2, Vector3(0.05, 0.1, 0.06), -0.1, -0.075)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	mb.box(Vector3(0.014, 0.012, 0.95), WeaponParts.at(0.0, 0.058, -0.62), L)
	mb.box(Vector3(0.126, 0.05, 0.01), WeaponParts.at(0.0, 0.05, 0.236), L)
	return WeaponParts.finish(mb)
