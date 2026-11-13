class_name WeaponMeshes
extends RefCounted
## The weapon models that the Warden holds beyond the pistol and the SMG (VARIETY_SPEC 3.5, 12.2). Same frames as `LookDevGear`:
## the grip is near the origin, the barrel points to -Z, and the grip points below are in weapon space (WardenMotion moves the
## wrists to them). At most `ActorMeshes.TRI_BUDGET[weapon]` (350) triangles each, three surfaces at most (gunmetal, ceramic,
## emit_cyan: "gunmetal with one cyan accent"), vertex colours baked like the Warden's own gear. V2-F built the arc projector here;
## V4-R builds the other seven in `WeaponMeshes2` (scattergun, assault rifle, hornet rack, LMG) and `WeaponMeshes3` (slag mortar,
## cutting torch, rail lance) and keeps the tables of muzzle, grip and magazine points in this file.
## The Warden has three weapon mounts (pistol, SMG and a third that shows every other weapon: `model_index`); the tables below are by
## weapon index (`Ids.WP_*`), because the hands and the muzzle follow the weapon, not the mount.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
const ID: Transform3D = Transform3D.IDENTITY
const SKIP: Array[StringName] = [L]

## The third mount of the Warden (named for the arc projector) draws every weapon except the pistol and the SMG.
const THIRD_MOUNT: int = 2
const ARC_MUZZLE: Vector3 = Vector3(0.0, 0.05, -0.72)
const ARC_GRIP_R: Vector3 = Vector3(0.0, -0.08, 0.03)
const ARC_GRIP_L: Vector3 = Vector3(0.0, -0.07, -0.23)
const ARC_MAG: Vector3 = Vector3(0.0, -0.12, -0.2)
const ARC_CORE_AT: Vector3 = Vector3(0.0, 0.05, -0.56)
## Muzzle, weapon hand, support hand and magazine (reload) point per weapon index; the first two (pistol, SMG) are `HeroMeshes`'
## and `LookDevGear`'s and are never read here.
const MUZZLES: Array[Vector3] = [
	Vector3.ZERO, Vector3.ZERO, WeaponMeshes2.SCATTER_MUZZLE, WeaponMeshes2.RIFLE_MUZZLE, WeaponMeshes2.HORNET_MUZZLE,
	WeaponMeshes2.LMG_MUZZLE, WeaponMeshes3.MORTAR_MUZZLE, WeaponMeshes3.TORCH_MUZZLE, ARC_MUZZLE, WeaponMeshes3.RAIL_MUZZLE,
]
const GRIPS_R: Array[Vector3] = [
	Vector3.ZERO, Vector3.ZERO, WeaponMeshes2.SCATTER_GRIP_R, WeaponMeshes2.RIFLE_GRIP_R, WeaponMeshes2.HORNET_GRIP_R,
	WeaponMeshes2.LMG_GRIP_R, WeaponMeshes3.MORTAR_GRIP_R, WeaponMeshes3.TORCH_GRIP_R, ARC_GRIP_R, WeaponMeshes3.RAIL_GRIP_R,
]
const GRIPS_L: Array[Vector3] = [
	Vector3.ZERO, Vector3.ZERO, WeaponMeshes2.SCATTER_GRIP_L, WeaponMeshes2.RIFLE_GRIP_L, WeaponMeshes2.HORNET_GRIP_L,
	WeaponMeshes2.LMG_GRIP_L, WeaponMeshes3.MORTAR_GRIP_L, WeaponMeshes3.TORCH_GRIP_L, ARC_GRIP_L, WeaponMeshes3.RAIL_GRIP_L,
]
const MAGS: Array[Vector3] = [
	Vector3.ZERO, Vector3.ZERO, WeaponMeshes2.SCATTER_MAG, WeaponMeshes2.RIFLE_MAG, WeaponMeshes2.HORNET_MAG,
	WeaponMeshes2.LMG_MAG, WeaponMeshes3.MORTAR_MAG, WeaponMeshes3.TORCH_MAG, ARC_MAG, WeaponMeshes3.RAIL_MAG,
]


## The mount (index into the Warden's three weapon mounts) that draws weapon `weapon_index` (`Ids.WP_*`): 0 for the pistol, 1 for the
## SMG, the third for every other weapon of the ten. A weapon index beyond the ten is drawn with the SMG so that a weapon in hand is
## never invisible.
static func model_index(weapon_index: int) -> int:
	if weapon_index == Ids.WP_PISTOL:
		return 0
	if weapon_index >= 2 and weapon_index < Ids.WEAPONS.size():
		return THIRD_MOUNT
	return 1


## The muzzle of weapon `weapon_index` in weapon space (where the tracers leave from).
static func muzzle(weapon_index: int) -> Vector3:
	if weapon_index == Ids.WP_PISTOL:
		return HeroMeshes.PISTOL_MUZZLE
	if weapon_index > 1 and weapon_index < MUZZLES.size():
		return MUZZLES[weapon_index]
	return HeroMeshes.SMG_MUZZLE


## Arc projector: a gunmetal receiver with a rear capacitor drum, a pale top plate and a cyan strip, a foregrip, and at the muzzle
## three prongs that flare out and bend back in around a glowing cyan core, with two coil rings behind them. Readable from above
## by its length and the three-pronged fork (nothing else the Warden carries has one).
static func arc_projector() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _grey(0.66)
	LookDevShapes.bevel_box(mb, Vector3(0.09, 0.1, 0.34), _at(0.0, 0.04, -0.17), G, 0.014)
	mb.tint = _grey(0.4)  # capacitor drum behind the receiver
	LookDevShapes.limb(mb, Vector3(0.0, 0.05, 0.02), Vector3(0.0, 0.05, 0.16), 0.052, 0.046, 8, G, ID, 0, true, true)
	mb.tint = _bone(0.8)  # pale top plate
	LookDevShapes.bevel_box(mb, Vector3(0.07, 0.025, 0.2), _at(0.0, 0.098, -0.15), C, 0.01, Vector2.ONE, 0.0, true, true)
	mb.tint = _grey(0.26)
	var grip: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.2) * Basis(Vector3.BACK, PI), Vector3(0.0, -0.09, 0.02))
	LookDevShapes.bevel_box(mb, Vector3(0.056, 0.16, 0.07), grip, G, 0.012, Vector2.ONE, 0.0, true, true)
	var fore: Transform3D = Transform3D(Basis(Vector3.RIGHT, -0.1) * Basis(Vector3.BACK, PI), Vector3(0.0, -0.075, -0.23))
	LookDevShapes.bevel_box(mb, Vector3(0.05, 0.1, 0.06), fore, G, 0.012, Vector2.ONE, 0.0, true, true)
	mb.tint = _grey(0.5)  # the collar the prongs grow from, and two coil rings in front of it
	LookDevShapes.limb(mb, Vector3(0.0, 0.05, -0.33), Vector3(0.0, 0.05, -0.4), 0.056, 0.05, 8, G, ID, 0, false, true)
	for z: float in [-0.43, -0.49]:
		mb.tint = _bone(0.6)
		LookDevShapes.limb(mb, Vector3(0.0, 0.05, z), Vector3(0.0, 0.05, z - 0.03), 0.07, 0.07, 8, C, ID, 0, false, false)
	for k: int in 3:  # three prongs: out and back in, tips around the core
		var a: float = TAU * float(k) / 3.0 + PI * 0.5
		var out: Vector3 = Vector3(cos(a), sin(a), 0.0)
		var base: Vector3 = Vector3(0.0, 0.05, -0.4) + out * 0.04
		var mid: Vector3 = Vector3(0.0, 0.05, -0.55) + out * 0.085
		var tip: Vector3 = Vector3(0.0, 0.05, -0.71) + out * 0.045
		mb.tint = _grey(0.62)
		LookDevShapes.limb(mb, base, mid, 0.028, 0.021, 4, G, ID, 0, true, false)
		mb.tint = _grey(0.8)
		LookDevShapes.limb(mb, mid, tip, 0.021, 0.011, 4, G, ID, 0, false, true)
	mb.tint = Color.WHITE  # the cyan: a core between the prongs and a strip along the receiver
	var _lit: int = mb.begin_part()
	mb.sphere(0.042, 6, _at(ARC_CORE_AT.x, ARC_CORE_AT.y, ARC_CORE_AT.z), L)
	mb.box(Vector3(0.024, 0.012, 0.16), _at(0.0, 0.113, -0.15), L)
	LookDevBake.ao(mb, 0.7, 0.07, 0.2, 1.3, 1.0, 0.1, SKIP)
	return mb.build()


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func _grey(k: float) -> Color:
	return Color(k, k, k, 1.0)


static func _bone(k: float) -> Color:
	var t: Color = LookDevWarden.BONE_TINT
	return Color(t.r * k, t.g * k, t.b * k, 1.0)
