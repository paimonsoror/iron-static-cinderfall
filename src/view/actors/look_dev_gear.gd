class_name LookDevGear
extends RefCounted
## Arms, backpack, antenna, cable and the two weapons of the hard-surface Warden, v2 (W3-C round 2). Every part is a mesh
## built around its own PIVOT (a shoulder, the elbow, the pack mount, the antenna base ...) so the view can move one
## MeshInstance3D about the joint. An arm is two parts, an upper arm and a forearm, both built along -Z with their outer
## side on +Y; LookDevIk aims them from the shoulder, so the weapon hand and the support hand really hold the weapon.
## Weapons: grip near the origin, barrel toward -Z, muzzle where HeroMeshes puts it (PISTOL_MUZZLE, SMG_MUZZLE). The grip
## points below are in weapon space; WardenMotion transforms them with the hand node to aim the wrists.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
const ID: Transform3D = Transform3D.IDENTITY
const SKIP: Array[StringName] = [L]

## Weapon-space points: the weapon hand, the support hand while firing, and the bottom of the magazine (reload).
const PISTOL_GRIP_R: Vector3 = Vector3(0.0, -0.075, 0.03)
const PISTOL_GRIP_L: Vector3 = Vector3(-0.075, -0.07, 0.0)
const PISTOL_MAG: Vector3 = Vector3(0.0, -0.15, 0.035)
const SMG_GRIP_R: Vector3 = Vector3(0.0, -0.085, 0.0)
const SMG_GRIP_L: Vector3 = Vector3(0.0, -0.065, -0.2)
const SMG_MAG: Vector3 = Vector3(0.0, -0.17, -0.2)


static func grip_r(weapon: int) -> Vector3:
	return SMG_GRIP_R if weapon == 1 else PISTOL_GRIP_R


static func grip_l(weapon: int) -> Vector3:
	return SMG_GRIP_L if weapon == 1 else PISTOL_GRIP_L


static func mag_point(weapon: int) -> Vector3:
	return SMG_MAG if weapon == 1 else PISTOL_MAG


## An upper arm: a smooth tapered limb from the shoulder (origin) along -Z, with a smooth elbow cap on the outer side (+Y).
static func arm_upper(_side: float) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var la: float = LookDevWarden.ARM_UPPER
	mb.tint = LookDevWarden._suit(1.0)
	LookDevShapes.limb(mb, Vector3.ZERO, Vector3(0.0, 0.0, -la), 0.088, 0.074, 10, G, ID, 0, false, false)
	mb.tint = LookDevWarden._steel(0.8)
	LookDevShapes.ellipsoid(mb, Vector3(0.098, 0.074, 0.105), 10, 2, _at(0.0, 0.012, -la), G, true)
	LookDevBake.ao(mb, 0.8, 0.1, 0.15, 1.4, 1.0, 0.1, SKIP)
	return mb.build()


## A forearm from the elbow (origin) along -Z to the wrist: a cylindrical steel vambrace with rounded ends over the suit and a
## chunky glove beyond the wrist; the weapon arm (`side` > 0) has a cyan stripe on its vambrace, the support arm does not
## (the two arms are not mirror images).
static func arm_fore(side: float) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var lb: float = LookDevWarden.ARM_FORE
	mb.tint = LookDevWarden._suit(1.0)
	LookDevShapes.limb(mb, Vector3.ZERO, Vector3(0.0, 0.0, -lb), 0.072, 0.06, 10, G, ID, 0, false, false)
	mb.tint = LookDevWarden._steel(1.0)
	LookDevShapes.limb(mb, Vector3(0.0, 0.0, -0.08), Vector3(0.0, 0.0, -lb + 0.1), 0.088, 0.078, 8, G, ID, 1, true, true)
	mb.tint = LookDevWarden._suit(0.6)
	var glove: Transform3D = _at(0.0, 0.0, -lb - 0.04)
	LookDevShapes.bevel_box(mb, Vector3(0.11, 0.1, 0.15), glove, G, 0.04, Vector2.ONE, 0.0)
	if side > 0.0:
		mb.tint = Color.WHITE
		var _stripe: int = mb.begin_part()
		mb.box(Vector3(0.036, 0.012, 0.17), _at(0.0, 0.09, -lb * 0.52), L)
	LookDevBake.ao(mb, 0.8, 0.1, 0.15, 1.4, 1.0, 0.1, SKIP)
	return mb.build()


## Backpack: a big rounded dark body, two exhaust stacks with cyan caps, a cyan strip across the top (the camera looks down
## on it) and the big back panel (two tall cyan cells with a spine between them): the largest lit shape the camera sees.
## Pivot = LookDevWarden.PACK_PIVOT.
static func pack() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var _g: int = mb.begin_part()
	mb.add_occluder(Vector3(0.0, 0.42, 0.16), 0.2)
	mb.tint = LookDevWarden._steel(0.3)
	LookDevRound.rounded_box(mb, Vector3(0.58, 0.5, 0.26), _at(0.0, 0.43, 0.35), G, 0.07)
	for sx: float in [-1.0, 1.0]:
		mb.tint = LookDevWarden._steel(0.7)
		LookDevShapes.limb(mb, Vector3(sx * 0.19, 0.66, 0.4), Vector3(sx * 0.19, 0.8, 0.4), 0.052, 0.048, 6, G, ID, 0, false, true)
	mb.tint = Color.WHITE
	var _lit: int = mb.begin_part()
	for sx2: float in [-1.0, 1.0]:
		mb.box(Vector3(0.07, 0.014, 0.07), _at(sx2 * 0.19, 0.804, 0.4), L)
		mb.box(Vector3(0.2, 0.34, 0.012), _at(sx2 * 0.125, 0.43, 0.486), L)
	mb.box(Vector3(0.38, 0.012, 0.11), _at(0.0, 0.686, 0.34), L)
	mb.tint = LookDevWarden._suit(0.8)
	var _slats: int = mb.begin_part()
	for k: int in 2:
		mb.box(Vector3(0.5, 0.016, 0.018), _at(0.0, 0.43 + 0.075 * (1.0 - 2.0 * float(k)), 0.49), G)
	LookDevBake.ao(mb, 0.85, 0.13, 0.25, HeroMeshes.WARDEN_WAIST_Y, 1.0, 0.1, SKIP)
	mb.recentre(LookDevWarden.PACK_PIVOT)
	return mb.build()


## A whip antenna on the comm unit of the helmet. Pivot = LookDevWarden.ANTENNA_PIVOT; sways in the view.
static func antenna() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.use_colors = true
	mb.tint = _grey(0.4)
	LookDevShapes.limb(mb, Vector3.ZERO, Vector3(0.01, 0.14, 0.01), 0.014, 0.006, 6, G, ID, 0, false, false)
	mb.tint = Color.WHITE
	LookDevShapes.limb(mb, Vector3(0.01, 0.135, 0.01), Vector3(0.012, 0.17, 0.012), 0.016, 0.009, 6, L, ID, 0, true, true)
	return mb.build()


## A power cable from the pack's side canister down to the left hip. Pivot = LookDevWarden.CABLE_PIVOT.
static func cable() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.use_colors = true
	mb.tint = _grey(0.22)
	var path: Array[Vector3] = [
		Vector3.ZERO, Vector3(-0.1, -0.03, 0.0), Vector3(-0.17, -0.16, -0.05), Vector3(-0.14, -0.3, -0.13),
	]
	for k: int in path.size() - 1:
		LookDevShapes.limb(mb, path[k], path[k + 1], 0.02, 0.02, 6, G, ID, 0, false, k == path.size() - 2)
	return mb.build()


## Service pistol: steel slide with a cyan sight strip, dark frame, grip, barrel, cyan power cell.
static func pistol() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _grey(0.7)
	LookDevShapes.bevel_box(mb, Vector3(0.076, 0.09, 0.3), _at(0.0, 0.05, -0.17), G, 0.014)
	mb.tint = _grey(0.4)
	var frame: Transform3D = Transform3D(Basis(Vector3.BACK, PI), Vector3(0.0, 0.0, -0.11))
	LookDevShapes.bevel_box(mb, Vector3(0.064, 0.06, 0.2), frame, G, 0.012, Vector2.ONE, 0.0, true, true)
	mb.tint = _grey(0.26)
	var grip: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.22) * Basis(Vector3.BACK, PI), Vector3(0.0, -0.085, 0.025))
	LookDevShapes.bevel_box(mb, Vector3(0.066, 0.17, 0.085), grip, G, 0.014, Vector2.ONE, 0.0, true, true)
	mb.tint = _grey(0.5)
	LookDevShapes.limb(mb, Vector3(0.0, 0.045, -0.32), Vector3(0.0, 0.045, -0.455), 0.022, 0.019, 8, G, ID, 0, false, true)
	mb.tint = Color.WHITE
	var _strip: int = mb.begin_part()
	mb.box(Vector3(0.026, 0.012, 0.16), _at(0.0, 0.1, -0.17), L)
	mb.box(Vector3(0.012, 0.04, 0.08), _at(0.042, 0.04, -0.15), L)
	LookDevBake.ao(mb, 0.7, 0.07, 0.2, 1.3, 1.0, 0.1, SKIP)
	return mb.build()


## SMG: steel receiver and shroud, barrel, magazine, grip, a cyan strip on the rail and a cyan power cell.
static func smg() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _grey(0.66)
	LookDevShapes.bevel_box(mb, Vector3(0.078, 0.11, 0.4), _at(0.0, 0.04, -0.2), G, 0.014)
	mb.tint = _grey(0.5)
	LookDevShapes.limb(mb, Vector3(0.0, 0.045, -0.38), Vector3(0.0, 0.045, -0.53), 0.042, 0.04, 8, G, ID, 0, false, true)
	mb.tint = _grey(0.4)
	LookDevShapes.limb(mb, Vector3(0.0, 0.045, -0.52), Vector3(0.0, 0.045, -0.62), 0.018, 0.016, 8, G, ID, 0, false, true)
	mb.tint = _grey(0.26)
	var mag: Transform3D = Transform3D(Basis(Vector3.RIGHT, -0.12) * Basis(Vector3.BACK, PI), Vector3(0.0, -0.13, -0.2))
	LookDevShapes.bevel_box(mb, Vector3(0.052, 0.2, 0.078), mag, G, 0.012, Vector2.ONE, 0.0, true, true)
	var grip: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.2) * Basis(Vector3.BACK, PI), Vector3(0.0, -0.09, 0.0))
	LookDevShapes.bevel_box(mb, Vector3(0.056, 0.16, 0.07), grip, G, 0.012, Vector2.ONE, 0.0, true, true)
	mb.tint = Color.WHITE
	var _strip: int = mb.begin_part()
	mb.box(Vector3(0.024, 0.012, 0.22), _at(0.0, 0.098, -0.2), L)
	mb.box(Vector3(0.012, 0.05, 0.12), _at(0.044, 0.04, -0.2), L)
	LookDevBake.ao(mb, 0.7, 0.07, 0.2, 1.3, 1.0, 0.1, SKIP)
	return mb.build()


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func _grey(k: float) -> Color:
	return Color(k, k, k, 1.0)
