class_name LookDevWarden
extends RefCounted
## The hard-surface Warden, v4 (W3-C round 4; looks STYLISED and STYLISED_PLUS): legs and hips, and the torso with the belt,
## the chest and the shoulder harness. The helmet and the pauldrons are in LookDevHead, arms, pack, antenna, cable and
## weapons in LookDevGear. Same frames as HeroMeshes: feet at y = 0, forward -Z, the torso is built around the waist (place
## it at HeroMeshes.WARDEN_WAIST_Y).
## A heavy-armour trooper archetype drawn from scratch: a wide planted stance, steel thigh cylinders with a front plate and a
## cyan trim, small knee guards with a visible hinge cap, tapered calves with steel greaves, chunky boots, a V-shaped chest of
## layered chamfered plates with a cyan power core in an off-white housing and harness straps over the shoulders, a big helmet
## (about a fifth of the height) and shoulders about twice the width of the waist.
## Colour plan (value first: the camera only sees a 55 px figure, so the lower body carries mid values too and only the joint
## gaps are dark): neutral light steel plates, mid steel thighs and calves, a clean off-white (never cream or tan), large cyan
## lights. The material gain lifts the steel above what the 8 bit vertex colours hold. Everything round is smooth-shaded
## (LookDevRound, limbs, domes); chamfered plates have zero shading crease; nothing has a bare 90 degree corner on a plate.
## Three surfaces per mesh: gunmetal (suit and steel, tinted per vertex), ceramic (the off-white plates) and emit_cyan.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"

## Joints and pivots in torso space (waist = origin); LookDevGear, WardenParts and WardenMotion use the same numbers.
const SHOULDER_R: Vector3 = Vector3(0.41, 0.55, 0.02)
const SHOULDER_L: Vector3 = Vector3(-0.41, 0.55, 0.02)
const ARM_UPPER: float = 0.32
const ARM_FORE: float = 0.34
## The weapon hand of the hard-surface looks: closer to the chest than the old mount so the support hand can reach.
const HAND_R: Vector3 = Vector3(0.08, 0.4, -0.22)
const POLE_R: Vector3 = Vector3(0.7, -0.35, 0.45)
const POLE_L: Vector3 = Vector3(-0.7, -0.35, 0.45)
const PACK_PIVOT: Vector3 = Vector3(0.0, 0.3, 0.22)
const ANTENNA_PIVOT: Vector3 = Vector3(0.12, 0.875, 0.11)
const CABLE_PIVOT: Vector3 = Vector3(-0.3, 0.32, 0.38)
## Width of the belt, the widest part of the waist (the shoulders are about twice that).
const WAIST_WIDTH: float = 0.53

const AO_STRENGTH: float = 0.85
const AO_REACH: float = 0.15
## Vertex values (they multiply the material albedo and then LookDevStyle.value_gain): the dark joint gaps, the steel armour,
## and the mid-value parts of the lower body.
const SUIT: float = 0.12
const STEEL: float = 0.8
const THIGH: float = 0.55
const CALF: float = 0.3
const BOOT: float = 0.2
const PELVIS: float = 0.5
## The tint that turns the cream of the palette bone into a clean off-white (red and green pulled down, blue left alone).
const BONE_TINT: Color = Color(0.8, 0.86, 1.0, 1.0)
const SKIP: Array[StringName] = [L]
const ID: Transform3D = Transform3D.IDENTITY


## Pelvis, steel thigh cylinders with a plate and a cyan trim, knee guards with a hinge, tapered calves with greaves, boots.
static func legs() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _steel(PELVIS)
	LookDevShapes.bevel_box(mb, Vector3(0.58, 0.24, 0.38), _at(0.0, 0.83, 0.0), G, 0.07, Vector2.ONE, 0.0, true, true)
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(side * 0.215, 0.76, 0.0)
		var knee: Vector3 = Vector3(side * 0.3, 0.45, -0.07)
		var ankle: Vector3 = Vector3(side * 0.325, 0.16, 0.0)
		# thigh: a steel cylinder with rounded ends over the dark joint, a front plate on it
		var thigh_a: Vector3 = hip + Vector3(0.0, -0.02, 0.0)
		var thigh_b: Vector3 = knee + Vector3(0.0, 0.14, 0.0)
		mb.tint = _suit(0.9)
		LookDevShapes.limb(mb, thigh_a, knee, 0.11, 0.098, 10, G, ID, 0, false, false)
		mb.tint = _steel(THIGH)
		LookDevShapes.limb(mb, thigh_a, thigh_b, 0.145, 0.128, 10, G, ID, 1, true, true)
		mb.tint = _steel(0.95)
		var plate: Transform3D = LookDevShapes.frame_along(hip, knee, 0.46, Vector3(0.0, 0.146, 0.0), Vector3.FORWARD)
		LookDevShapes.bevel_box(mb, Vector3(0.17, 0.05, 0.25), plate, G, 0.03, Vector2(0.85, 0.9), 0.0, true, true)
		# knee: a small guard and a hinge cap on the outer side, no ball
		mb.tint = _steel(0.85)
		var guard: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.4), knee + Vector3(0.0, 0.02, -0.1))
		LookDevShapes.bevel_box(mb, Vector3(0.2, 0.13, 0.1), guard, G, 0.05, Vector2.ONE, 0.0, true, true)
		mb.tint = _steel(0.55)
		var hinge_a: Vector3 = knee + Vector3(side * 0.08, 0.0, 0.0)
		var hinge_b: Vector3 = knee + Vector3(side * 0.135, 0.0, 0.0)
		LookDevShapes.limb(mb, hinge_a, hinge_b, 0.055, 0.05, 6, G, ID, 0, false, true)
		# calf: knee to a bulge to a narrow ankle (mid steel), then a greave plate in light steel with a cyan trim
		mb.tint = _steel(CALF)
		var calf: Vector3 = knee.lerp(ankle, 0.34) + Vector3(0.0, 0.0, 0.02)
		LookDevShapes.limb(mb, knee, calf, 0.098, 0.108, 8, G, ID, 0, false, false)
		LookDevShapes.limb(mb, calf, ankle, 0.108, 0.06, 8, G, ID, 0, false, true)
		mb.tint = _steel(0.95)
		var greave: Transform3D = LookDevShapes.frame_along(knee, ankle, 0.46, Vector3(0.0, 0.112, 0.0), Vector3.FORWARD)
		LookDevShapes.bevel_box(mb, Vector3(0.18, 0.06, 0.28), greave, G, 0.035, Vector2(0.8, 0.9), 0.0, true, true)
		mb.tint = _steel(BOOT)
		LookDevRound.rounded_box(mb, Vector3(0.24, 0.17, 0.4), _at(ankle.x + side * 0.01, 0.085, -0.04), G, 0.06)
		mb.tint = Color.WHITE
		var _trim: int = mb.begin_part()
		var greave_trim: Transform3D = LookDevShapes.frame_along(knee, ankle, 0.46, Vector3(0.0, 0.146, 0.0), Vector3.FORWARD)
		mb.box(Vector3(0.036, 0.012, 0.21), greave_trim, L)
		var thigh_trim: Transform3D = LookDevShapes.frame_along(hip, knee, 0.46, Vector3(0.0, 0.174, 0.0), Vector3.FORWARD)
		mb.box(Vector3(0.03, 0.01, 0.19), thigh_trim, L)
	LookDevBake.ao(mb, AO_STRENGTH, AO_REACH, 0.25, 0.0, 0.4, 0.28, SKIP)
	return mb.build()


## Abdomen, belt, V-shaped chest of layered plates with a cyan power core, shoulder harness, yoke, neck, helmet, pauldrons.
## Origin = the waist.
static func torso() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_ghosts(mb)
	mb.tint = _suit(1.0)
	var belly: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3(1.25, 1.0, 0.9)), Vector3.ZERO)
	LookDevShapes.limb(mb, Vector3(0.0, -0.03, 0.0), Vector3(0.0, 0.26, 0.0), 0.15, 0.16, 10, G, belly, 0, false, false)
	# belt: the defined waist
	mb.tint = _steel(0.6)
	var belt: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3(1.4, 1.0, 1.0)), Vector3.ZERO)
	LookDevShapes.limb(mb, Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.1, 0.0), 0.19, 0.19, 12, G, belt, 0, false, false)
	# chest: a thick V taper under layered plates
	mb.tint = _steel(0.45)
	LookDevShapes.bevel_box(mb, Vector3(0.48, 0.46, 0.36), _at(0.0, 0.4, 0.0), G, 0.07, Vector2(1.45, 1.1), 0.0, true, true)
	_chest_plates(mb)
	mb.tint = _steel(0.9)
	LookDevShapes.bevel_box(mb, Vector3(0.66, 0.08, 0.36), _at(0.0, 0.615, 0.0), G, 0.035, Vector2.ONE, 0.0, true, true)
	mb.tint = _suit(1.0)
	LookDevShapes.limb(mb, Vector3(0.0, 0.58, 0.0), Vector3(0.0, 0.66, -0.01), 0.09, 0.08, 8, G, ID, 0, false, false)
	mb.tint = _suit(1.3)
	var _straps: int = mb.begin_part()
	for side: float in [-1.0, 1.0]:  # harness straps over the shoulders, front to back
		mb.box(Vector3(0.05, 0.012, 0.42), _at(side * 0.14, 0.658, 0.0), G)
	LookDevHead.helmet(mb)
	LookDevHead.pauldrons(mb)
	mb.tint = Color.WHITE
	var _lights: int = mb.begin_part()
	var core: Transform3D = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.05), Vector3(0.0, 0.43, -0.268))
	mb.cylinder(0.05, 0.05, 0.02, 6, core, L)
	mb.box(Vector3(0.12, 0.03, 0.012), _at(0.0, 0.06, -0.205), L)
	LookDevBake.ao(mb, AO_STRENGTH, AO_REACH, 0.2, HeroMeshes.WARDEN_WAIST_Y, 1.0, 0.1, SKIP)
	return mb.build()


## Two pectoral plates in a V over a lower plate, a core housing in off-white with a dark ring around the cyan core, a
## panel line. Every plate is a chamfered bevel box with zero shading crease.
static func _chest_plates(mb: MeshBuilder) -> void:
	# plates are built facing the front (local +Y outward, local +Z up) so they are 30 triangle shells on the chest
	var out: Basis = LookDevShapes.facing(Vector3(0.0, -0.05, -1.0))
	mb.tint = _steel(0.9)
	for side: float in [-1.0, 1.0]:
		var pec: Basis = out * Basis(Vector3.UP, side * 0.34)
		LookDevShapes.bevel_box(mb, Vector3(0.27, 0.07, 0.17), Transform3D(pec, Vector3(side * 0.14, 0.51, -0.185)), G, 0.04, Vector2.ONE, 0.0, true, true)
	mb.tint = _steel(0.7)
	LookDevShapes.bevel_box(mb, Vector3(0.36, 0.07, 0.2), Transform3D(out, Vector3(0.0, 0.31, -0.19)), G, 0.04, Vector2.ONE, 0.0, true, true)
	mb.tint = _bone(1.0)
	LookDevShapes.bevel_box(mb, Vector3(0.16, 0.05, 0.16), Transform3D(out, Vector3(0.0, 0.43, -0.228)), C, 0.04, Vector2.ONE, 0.0, true, true)
	mb.tint = _suit(1.0)
	var ring: Transform3D = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.05), Vector3(0.0, 0.43, -0.256))
	mb.cylinder(0.068, 0.068, 0.012, 6, ring, G)
	mb.tint = _suit(2.0)
	var _line: int = mb.begin_part()
	mb.box(Vector3(0.26, 0.007, 0.008), Transform3D(out, Vector3(0.0, 0.27, -0.228)), G)


## Spheres of the neighbours that are separate meshes (arms, pack): they darken the torso where they meet it.
static func _ghosts(mb: MeshBuilder) -> void:
	var _g: int = mb.begin_part()
	for side: float in [-1.0, 1.0]:
		mb.add_occluder(Vector3(side * 0.42, 0.5, 0.0), 0.09)
		mb.add_occluder(Vector3(side * 0.4, 0.42, -0.08), 0.07)
	mb.add_occluder(Vector3(0.0, 0.44, 0.38), 0.2)
	mb.add_occluder(Vector3(0.0, 0.3, 0.38), 0.18)


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func _grey(k: float) -> Color:
	return Color(k, k, k, 1.0)


## Steel armour: a neutral light grey with a hint of warmth against the cyan arena light (no copper, no teal). `k`
## multiplies STEEL.
static func _steel(k: float) -> Color:
	var v: float = STEEL * k
	return Color(v, v * 0.93, v * 0.86, 1.0)


## The dark joint gaps: near neutral charcoal. `k` multiplies SUIT.
static func _suit(k: float) -> Color:
	var v: float = SUIT * k
	return Color(v, v * 0.97, v * 0.93, 1.0)


## A tint of the off-white plates: `k` is the value (1 = the full plate).
static func _bone(k: float) -> Color:
	return Color(BONE_TINT.r * k, BONE_TINT.g * k, BONE_TINT.b * k, 1.0)
