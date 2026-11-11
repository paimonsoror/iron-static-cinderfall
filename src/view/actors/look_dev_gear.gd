class_name LookDevGear
extends RefCounted
## Arms, backpack, antenna, cable and the two weapons of the hard-surface Warden (W3-C). Every part is a mesh built
## around its own PIVOT (the shoulder, the pack mount, the antenna base ...), so the view can rotate one
## MeshInstance3D about the joint for recoil, reload and secondary motion. Ambient occlusion is baked with the torso
## as a ghost occluder, so an arm still darkens where it meets the chest. Weapons: grip at the origin, barrel toward -Z,
## muzzle where HeroMeshes puts it (PISTOL_MUZZLE, SMG_MUZZLE).

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
const ID: Transform3D = Transform3D.IDENTITY
const SKIP: Array[StringName] = [L]


## The weapon arm (`side` = 1, shoulder pauldron right) or the support arm (-1), in the frame of its shoulder.
static func arm(side: float) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_torso_ghosts(mb)
	var shoulder: Vector3 = LookDevWarden.SHOULDER_R if side > 0.0 else LookDevWarden.SHOULDER_L
	var elbow: Vector3 = LookDevWarden.ELBOW_R if side > 0.0 else LookDevWarden.ELBOW_L
	var hand: Vector3 = HeroMeshes.WARDEN_HAND if side > 0.0 else LookDevWarden.HAND_L_REST
	var wrist: Vector3 = hand + (elbow - hand).normalized() * 0.07
	mb.tint = _grey(LookDevWarden.SUIT)
	LookDevShapes.limb(mb, shoulder, elbow, 0.072, 0.058, 8, G, ID, 0, false, false)
	LookDevShapes.limb(mb, elbow, wrist, 0.058, 0.047, 8, G, ID, 0, false, true)
	mb.tint = LookDevWarden._bone(1.0)
	var pad: Transform3D = Transform3D(
		LookDevShapes.facing(Vector3(side * 0.6, 0.15, 0.8)), elbow + Vector3(side * 0.02, 0.0, 0.03)
	)
	LookDevShapes.bevel_box(mb, Vector3(0.12, 0.06, 0.13), pad, C, 0.024, Vector2(0.8, 0.8), 0.6, false)
	if side > 0.0:  # only the weapon arm carries a bracer: the two arms are not mirror images
		mb.tint = LookDevWarden._bone(1.0 * 0.95)
		var bracer: Transform3D = LookDevShapes.frame_along(elbow, wrist, 0.62, Vector3(0.0, 0.012, 0.0))
		LookDevShapes.bevel_box(mb, Vector3(0.115, 0.1, 0.17), bracer, C, 0.02, Vector2.ONE, 0.55, false)
	mb.tint = _grey(LookDevWarden.SUIT * 0.6)
	var glove: Transform3D = LookDevShapes.frame_along(wrist, hand + (hand - wrist) * 0.7, 0.5)
	LookDevShapes.bevel_box(mb, Vector3(0.095, 0.085, 0.125), glove, G, 0.02, Vector2.ONE, 0.55, false)
	LookDevBake.ao(mb, 0.85, 0.12, 0.2, HeroMeshes.WARDEN_WAIST_Y, 1.0, 0.1, SKIP)
	mb.recentre(shoulder)
	return mb.build()


## Backpack with two exhaust stacks, glowing power bars, side canisters and a vent: the hero of the view from behind.
## Pivot = LookDevWarden.PACK_PIVOT.
static func pack() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var _g: int = mb.begin_part()
	mb.add_occluder(Vector3(0.0, 0.42, 0.14), 0.2)
	mb.tint = _grey(LookDevWarden.SUIT * 1.15)
	LookDevShapes.bevel_box(mb, Vector3(0.5, 0.48, 0.24), _at(0.0, 0.43, 0.34), G, 0.034, Vector2.ONE, 0.55, true)
	mb.tint = LookDevWarden._bone(1.0)
	LookDevShapes.bevel_box(mb, Vector3(0.46, 0.07, 0.26), _at(0.0, 0.69, 0.34), C, 0.024, Vector2.ONE, 0.55, false)
	for sx: float in [-1.0, 1.0]:
		mb.tint = _grey(LookDevWarden.SUIT * 1.2)
		LookDevShapes.limb(mb, Vector3(sx * 0.14, 0.68, 0.36), Vector3(sx * 0.14, 0.9, 0.36), 0.056, 0.05, 8, G, ID, 0, false, true)
	mb.tint = LookDevWarden._bone(1.0 * 0.95)
	LookDevShapes.limb(mb, Vector3(-0.25, 0.36, 0.35), Vector3(-0.42, 0.36, 0.35), 0.068, 0.068, 8, C, ID, 0, true, true)
	mb.tint = Color.WHITE
	for sx2: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, Vector3(sx2 * 0.14, 0.855, 0.36), Vector3(sx2 * 0.14, 0.9, 0.36), 0.06, 0.057, 6, L, ID, 0, true, true)
	var _bars: int = mb.begin_part()
	for sx3: float in [-1.0, 1.0]:
		mb.box(Vector3(0.056, 0.34, 0.016), _at(sx3 * 0.115, 0.45, 0.46), L)
	mb.box(Vector3(0.34, 0.03, 0.016), _at(0.0, 0.655, 0.46), L)
	LookDevBake.ao(mb, 0.85, 0.13, 0.25, HeroMeshes.WARDEN_WAIST_Y, 1.0, 0.1, SKIP)
	mb.recentre(LookDevWarden.PACK_PIVOT)
	return mb.build()


## A thin whip antenna on the helmet's rear right. Pivot = LookDevWarden.ANTENNA_PIVOT; sways in the view.
static func antenna() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var base: Vector3 = LookDevWarden.ANTENNA_PIVOT
	mb.use_colors = true
	mb.tint = _grey(0.45)
	LookDevShapes.limb(mb, base, base + Vector3(0.015, 0.17, 0.015), 0.013, 0.006, 5, G, ID, 0, false, false)
	mb.tint = Color.WHITE
	LookDevShapes.limb(mb, base + Vector3(0.015, 0.165, 0.015), base + Vector3(0.017, 0.2, 0.017), 0.014, 0.008, 5, L, ID, 0, true, true)
	mb.recentre(base)
	return mb.build()


## A power cable from the pack's side canister down to the left hip. Pivot = LookDevWarden.CABLE_PIVOT.
static func cable() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.use_colors = true
	mb.tint = _grey(0.22)
	var p: Vector3 = LookDevWarden.CABLE_PIVOT
	var path: Array[Vector3] = [
		p, p + Vector3(-0.1, -0.03, -0.0), p + Vector3(-0.17, -0.16, -0.05), p + Vector3(-0.14, -0.3, -0.13),
	]
	for k: int in path.size() - 1:
		LookDevShapes.limb(mb, path[k], path[k + 1], 0.02, 0.02, 5, G, ID, 0, false, k == path.size() - 2)
	mb.recentre(p)
	return mb.build()


## Service pistol: slide with a cyan sight strip, frame, barrel, grip, cyan power cell.
static func pistol() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _grey(0.86)
	LookDevShapes.bevel_box(mb, Vector3(0.078, 0.095, 0.3), _at(0.0, 0.05, -0.17), C, 0.014, Vector2.ONE, 0.5, false)
	mb.tint = _grey(0.44)
	LookDevShapes.bevel_box(mb, Vector3(0.066, 0.07, 0.2), _at(0.0, -0.01, -0.11), G, 0.012, Vector2.ONE, 0.5, false)
	var grip: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.22), Vector3(0.0, -0.085, 0.025))
	mb.tint = _grey(0.25)
	LookDevShapes.bevel_box(mb, Vector3(0.066, 0.17, 0.085), grip, G, 0.014, Vector2.ONE, 0.5, false)
	mb.tint = _grey(0.4)
	LookDevShapes.limb(mb, Vector3(0.0, 0.045, -0.32), Vector3(0.0, 0.045, -0.455), 0.022, 0.019, 8, G, ID, 0, false, true)
	mb.tint = Color.WHITE
	var _strip: int = mb.begin_part()
	mb.box(Vector3(0.026, 0.012, 0.16), _at(0.0, 0.1, -0.17), L)
	mb.box(Vector3(0.012, 0.04, 0.08), _at(0.042, 0.04, -0.15), L)
	LookDevBake.ao(mb, 0.7, 0.07, 0.2, 1.3, 1.0, 0.1, SKIP)
	return mb.build()


## SMG: receiver, ceramic shroud and barrel, magazine, stock, foregrip, rail with a cyan strip.
static func smg() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _grey(0.5)
	LookDevShapes.bevel_box(mb, Vector3(0.078, 0.11, 0.4), _at(0.0, 0.04, -0.2), G, 0.014, Vector2.ONE, 0.5, false)
	mb.tint = _grey(0.88)
	LookDevShapes.limb(mb, Vector3(0.0, 0.045, -0.38), Vector3(0.0, 0.045, -0.53), 0.042, 0.04, 8, C, ID, 0, false, true)
	mb.tint = _grey(0.4)
	LookDevShapes.limb(mb, Vector3(0.0, 0.045, -0.52), Vector3(0.0, 0.045, -0.62), 0.018, 0.016, 8, G, ID, 0, false, true)
	mb.tint = _grey(0.24)
	var mag: Transform3D = Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0.0, -0.13, -0.2))
	LookDevShapes.bevel_box(mb, Vector3(0.052, 0.2, 0.078), mag, G, 0.012, Vector2.ONE, 0.5, false)
	LookDevShapes.bevel_box(mb, Vector3(0.052, 0.085, 0.2), _at(0.0, 0.035, 0.13), G, 0.012, Vector2.ONE, 0.5, false)
	var grip: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0.0, -0.09, 0.0))
	LookDevShapes.bevel_box(mb, Vector3(0.056, 0.16, 0.07), grip, G, 0.012, Vector2.ONE, 0.5, false)
	mb.tint = Color.WHITE
	var _strip: int = mb.begin_part()
	mb.box(Vector3(0.024, 0.012, 0.22), _at(0.0, 0.098, -0.2), L)
	mb.box(Vector3(0.012, 0.05, 0.12), _at(0.044, 0.04, -0.2), L)
	LookDevBake.ao(mb, 0.7, 0.07, 0.2, 1.3, 1.0, 0.1, SKIP)
	return mb.build()


## Spheres of the torso for the arm bakes (the arm is built in torso space, then moved to its shoulder pivot).
static func _torso_ghosts(mb: MeshBuilder) -> void:
	var _g: int = mb.begin_part()
	mb.add_occluder(Vector3(0.0, 0.42, 0.0), 0.2)
	mb.add_occluder(Vector3(0.0, 0.5, -0.05), 0.2)
	mb.add_occluder(Vector3(0.0, 0.8, 0.0), 0.15)
	mb.add_occluder(Vector3(0.0, 0.2, 0.0), 0.17)


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func _grey(k: float) -> Color:
	return Color(k, k, k, 1.0)
