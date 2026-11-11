class_name HeroMeshes
extends RefCounted
## Procedural merged meshes of the friendly side: the Warden (legs and torso), the two weapons and the auto turret
## (tripod base and yawing head). Forward is -Z, feet at y = 0. Palette: bone-ceramic plates over gunmetal, cyan
## visor strip and lights. Weapons are modelled with the grip at the origin and the barrel toward -Z.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
const D: StringName = &"dark_frame"

## Height of the waist pivot of the Warden (the torso mesh is built around it).
const WARDEN_WAIST_Y: float = 0.92
## Weapon mount in torso space and the muzzle tips in weapon space.
const WARDEN_HAND: Vector3 = Vector3(0.14, 0.38, -0.42)
const PISTOL_MUZZLE: Vector3 = Vector3(0.0, 0.04, -0.45)
const SMG_MUZZLE: Vector3 = Vector3(0.0, 0.04, -0.62)
## The turret head pivots at this height above its pad; the muzzle is in head space.
const TURRET_HEAD_Y: float = 0.62
const TURRET_MUZZLE: Vector3 = Vector3(0.0, 0.22, -0.78)


## Legs and hips: wide gunmetal stance, ceramic knee plates, thin cyan belt.
static func warden_legs() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(0.6, 0.2, 0.34), ActorPrims.at(Vector3(0.0, 0.84, 0.0)), G)
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(side * 0.22, 0.82, 0.0)
		var knee: Vector3 = Vector3(side * 0.34, 0.5, -0.1)
		var ankle: Vector3 = Vector3(side * 0.4, 0.14, 0.0)
		ActorPrims.strut(mb, hip, knee, 0.2, G)
		ActorPrims.strut(mb, knee, ankle, 0.17, G)
		mb.box(Vector3(0.26, 0.14, 0.5), ActorPrims.at(Vector3(side * 0.4, 0.07, -0.07)), G)
		mb.box(Vector3(0.22, 0.2, 0.12), ActorPrims.at(Vector3(side * 0.34, 0.52, -0.2)), C)
	mb.box(Vector3(0.64, 0.04, 0.38), ActorPrims.at(Vector3(0.0, 0.95, 0.0)), L)
	return mb.build()


## Torso, arms, head, in a frame whose origin is the waist (place it at WARDEN_WAIST_Y).
static func warden_torso() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(0.44, 0.2, 0.3), ActorPrims.at(Vector3(0.0, 0.08, 0.0)), G)
	mb.box(Vector3(0.56, 0.5, 0.34), ActorPrims.at(Vector3(0.0, 0.4, 0.0)), G)
	mb.box(Vector3(0.62, 0.4, 0.12), ActorPrims.at(Vector3(0.0, 0.44, -0.19)), C)
	mb.box(Vector3(0.44, 0.44, 0.22), ActorPrims.at(Vector3(0.0, 0.42, 0.28)), C)
	mb.box(Vector3(0.3, 0.05, 0.14), ActorPrims.at(Vector3(0.0, 0.665, 0.28)), L)
	for side: float in [-1.0, 1.0]:
		mb.box(Vector3(0.32, 0.24, 0.38), ActorPrims.at(Vector3(side * 0.44, 0.62, 0.0)), C)
		mb.box(Vector3(0.12, 0.05, 0.14), ActorPrims.at(Vector3(side * 0.44, 0.765, 0.0)), L)
	mb.box(Vector3(0.14, 0.12, 0.14), ActorPrims.at(Vector3(0.0, 0.7, -0.02)), G)
	mb.box(Vector3(0.28, 0.26, 0.3), ActorPrims.at(Vector3(0.0, 0.86, -0.02)), C)
	mb.box(Vector3(0.24, 0.06, 0.14), ActorPrims.at(Vector3(0.0, 1.015, -0.12)), L)
	ActorPrims.strut(mb, Vector3(0.44, 0.58, 0.0), WARDEN_HAND, 0.14, G)
	ActorPrims.strut(mb, Vector3(-0.44, 0.58, 0.0), WARDEN_HAND + Vector3(-0.12, 0.0, -0.06), 0.14, G)
	mb.box(Vector3(0.1, 0.1, 0.1), ActorPrims.at(WARDEN_HAND + Vector3(0.0, 0.0, 0.02)), C)
	mb.box(Vector3(0.1, 0.1, 0.1), ActorPrims.at(WARDEN_HAND + Vector3(-0.12, 0.0, -0.04)), C)
	return mb.build()


## Service pistol: slide, barrel, grip, cyan sight dot.
static func pistol() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(0.1, 0.12, 0.36), ActorPrims.at(Vector3(0.0, 0.05, -0.15)), G)
	mb.box(Vector3(0.055, 0.055, 0.12), ActorPrims.at(Vector3(0.0, 0.04, -0.38)), G)
	mb.box(Vector3(0.075, 0.18, 0.08), ActorPrims.xf(Vector3(0.0, -0.08, 0.03), Vector3(0.2, 0.0, 0.0)), D)
	mb.box(Vector3(0.05, 0.03, 0.2), ActorPrims.at(Vector3(0.0, 0.12, -0.16)), L)
	return mb.build()


## SMG: longer body with a magazine, stock, shroud and a sight.
static func smg() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(0.08, 0.11, 0.42), ActorPrims.at(Vector3(0.0, 0.04, -0.2)), G)
	mb.box(Vector3(0.06, 0.06, 0.2), ActorPrims.at(Vector3(0.0, 0.04, -0.52)), G)
	mb.box(Vector3(0.05, 0.22, 0.08), ActorPrims.at(Vector3(0.0, -0.12, -0.22)), D)
	mb.box(Vector3(0.05, 0.08, 0.2), ActorPrims.at(Vector3(0.0, 0.04, 0.12)), D)
	mb.box(Vector3(0.06, 0.14, 0.07), ActorPrims.xf(Vector3(0.0, -0.08, -0.02), Vector3(0.2, 0.0, 0.0)), D)
	mb.box(Vector3(0.03, 0.03, 0.1), ActorPrims.at(Vector3(0.0, 0.11, -0.2)), L)
	return mb.build()


## Static tripod base of the turret.
static func turret_base() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_turret_base_into(mb)
	return mb.build()


## Yawing head: squat cylinder, gun block, twin barrels, cyan light. Origin = the yaw pivot.
static func turret_head() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_turret_head_into(mb, Transform3D.IDENTITY)
	return mb.build()


## Whole turret in one mesh (base plus head at rest).
static func turret() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_turret_base_into(mb)
	_turret_head_into(mb, ActorPrims.at(Vector3(0.0, TURRET_HEAD_Y, 0.0)))
	return mb.build()


static func _turret_base_into(mb: MeshBuilder) -> void:
	var apex: Vector3 = Vector3(0.0, 0.58, 0.0)
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0 + PI * 0.5
		var foot: Vector3 = Vector3(cos(a) * 0.55, 0.04, sin(a) * 0.55)
		ActorPrims.strut(mb, apex, foot, 0.1, G)
		mb.box(Vector3(0.18, 0.06, 0.18), ActorPrims.at(Vector3(foot.x, 0.03, foot.z)), G)
	mb.cylinder(0.17, 0.2, 0.14, 6, ActorPrims.at(Vector3(0.0, 0.54, 0.0)), G)


static func _turret_head_into(mb: MeshBuilder, frame: Transform3D) -> void:
	mb.cylinder(0.27, 0.27, 0.26, 8, frame * ActorPrims.at(Vector3(0.0, 0.12, 0.0)), C)
	ActorPrims.box_in(mb, Vector3(0.34, 0.2, 0.3), Vector3(0.0, 0.2, -0.12), G, frame)
	for side: float in [-1.0, 1.0]:
		ActorPrims.box_in(mb, Vector3(0.07, 0.07, 0.56), Vector3(side * 0.1, 0.22, -0.5), G, frame)
	ActorPrims.box_in(mb, Vector3(0.14, 0.05, 0.14), Vector3(0.0, 0.27, 0.13), L, frame)
