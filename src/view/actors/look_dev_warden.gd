class_name LookDevWarden
extends RefCounted
## The hard-surface Warden (W3-C, looks STYLISED and STYLISED_PLUS): legs and hips, and torso with head and shoulders.
## Arms, pack, antenna, cable and weapons are in LookDevGear. Same frames and the same hand mount as HeroMeshes: feet at
## y = 0, forward -Z, the torso is built around the waist (place it at HeroMeshes.WARDEN_WAIST_Y). Three surfaces per
## mesh: gunmetal (the dark undersuit and joints, tinted down in the vertex colour), ceramic (armour plates, the light
## values) and emit_cyan (accents). The tint and the baked ambient occlusion live in the vertex colours, so one material
## per role is enough. The game camera looks from behind and above (pitch 60, the Warden faces the swarm), so the pack,
## the shoulders, the helmet top and the boots carry the read at 1x: dark suit, light plates, glowing cyan.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"

## Joints and pivots in torso space (waist = origin); LookDevGear and WardenParts use the same numbers.
const SHOULDER_R: Vector3 = Vector3(0.35, 0.57, 0.02)
const SHOULDER_L: Vector3 = Vector3(-0.35, 0.57, 0.02)
const ELBOW_R: Vector3 = Vector3(0.41, 0.4, -0.14)
const ELBOW_L: Vector3 = Vector3(-0.38, 0.38, -0.15)
const HAND_L_REST: Vector3 = Vector3(-0.02, 0.36, -0.4)
const PACK_PIVOT: Vector3 = Vector3(0.0, 0.3, 0.22)
const ANTENNA_PIVOT: Vector3 = Vector3(0.11, 0.88, 0.1)
const CABLE_PIVOT: Vector3 = Vector3(-0.26, 0.3, 0.34)

const AO_STRENGTH: float = 0.85
const AO_REACH: float = 0.15
## Value of the dark undersuit and of the armour plates (multiplies the material albedo).
const SUIT: float = 0.4
const PLATE: float = 0.86
## Armour plates are a warm bone, a little darker than the palette ceramic, so they read against the cyan light.
const BONE: Color = Color(0.93, 0.85, 0.72, 1.0)
const SKIP: Array[StringName] = [L]
const ID: Transform3D = Transform3D.IDENTITY


## Pelvis, belt, hip guards, thighs with guards, knee guards, shins and boots (wide planted stance).
static func legs() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = _grey(SUIT * 1.1)
	LookDevShapes.bevel_box(mb, Vector3(0.5, 0.18, 0.32), _at(0.0, 0.85, 0.0), G, 0.028)
	mb.tint = Color.WHITE
	var _belt: int = mb.begin_part()
	mb.box(Vector3(0.508, 0.016, 0.328), _at(0.0, 0.928, 0.0), L)
	for side: float in [-1.0, 1.0]:
		mb.tint = _bone(1.0 * 0.95)
		var guard: Transform3D = Transform3D(Basis(Vector3.FORWARD, side * 0.14), Vector3(side * 0.3, 0.83, 0.0))
		LookDevShapes.bevel_box(mb, Vector3(0.11, 0.2, 0.29), guard, C, 0.022, Vector2.ONE, 0.55, false)
		var hip: Vector3 = Vector3(side * 0.2, 0.8, 0.0)
		var knee: Vector3 = Vector3(side * 0.3, 0.49, -0.1)
		var ankle: Vector3 = Vector3(side * 0.36, 0.15, 0.0)
		mb.tint = _grey(SUIT)
		LookDevShapes.limb(mb, hip, knee, 0.118, 0.09, 8, G, ID, 0, false, false)
		LookDevShapes.limb(mb, knee, ankle, 0.09, 0.066, 8, G, ID, 0, false, true)
		mb.tint = _bone(1.0)
		var thigh_guard: Transform3D = LookDevShapes.frame_along(hip, knee, 0.42, Vector3(side * 0.04, 0.085, 0.0))
		LookDevShapes.bevel_box(mb, Vector3(0.15, 0.055, 0.26), thigh_guard, C, 0.02, Vector2.ONE, 0.55, false)
		var cap: Transform3D = Transform3D(
			LookDevShapes.facing(Vector3(0.0, 0.2, -1.0)), knee + Vector3(0.0, 0.0, -0.06)
		)
		mb.tint = _bone(1.0 * 0.92)
		LookDevShapes.bevel_box(mb, Vector3(0.15, 0.06, 0.16), cap, C, 0.026, Vector2(0.8, 0.8), 0.6, false)
		var shin_guard: Transform3D = LookDevShapes.frame_along(knee, ankle, 0.55, Vector3(0.0, 0.08, 0.0))
		LookDevShapes.bevel_box(mb, Vector3(0.11, 0.05, 0.25), shin_guard, C, 0.018, Vector2.ONE, 0.55, false)
		mb.tint = _grey(SUIT * 0.7)
		LookDevShapes.bevel_box(mb, Vector3(0.19, 0.13, 0.19), _at(ankle.x + side * 0.01, 0.07, 0.04), G, 0.022, Vector2.ONE, 0.55, false)
		mb.tint = _bone(1.0 * 0.85)
		LookDevShapes.bevel_box(mb, Vector3(0.17, 0.09, 0.18), _at(ankle.x + side * 0.015, 0.05, -0.14), C, 0.022, Vector2.ONE, 0.55, false)
	LookDevBake.ao(mb, AO_STRENGTH, AO_REACH, 0.25, 0.0, 0.4, 0.28, SKIP)
	return mb.build()


## Chest, back plate, collar, neck, helmet with visor, shoulders. Origin = the waist.
static func torso() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_ghosts(mb)
	# abdomen and chest block (undersuit)
	mb.tint = _grey(SUIT)
	var belly: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3(1.15, 1.0, 0.88)), Vector3.ZERO)
	LookDevShapes.limb(mb, Vector3(0.0, -0.03, 0.0), Vector3(0.0, 0.25, 0.0), 0.15, 0.17, 8, G, belly, 0, false, false)
	mb.tint = _grey(SUIT * 1.15)
	LookDevShapes.bevel_box(mb, Vector3(0.44, 0.4, 0.3), _at(0.0, 0.41, 0.0), G, 0.03, Vector2(1.3, 1.08))
	# armour: front plate, yoke over the shoulders, back carapace with a dark spine channel, collar
	mb.tint = _bone(1.0)
	LookDevShapes.curved_plate(mb, 0.46, 0.3, 0.05, 0.9, 5, _at(0.0, 0.43, -0.168), C)
	LookDevShapes.bevel_box(mb, Vector3(0.58, 0.065, 0.33), _at(0.0, 0.605, 0.0), C, 0.024, Vector2.ONE, 0.55, false)
	mb.tint = _bone(1.0 * 0.92)
	for side: float in [-1.0, 1.0]:
		LookDevShapes.bevel_box(mb, Vector3(0.22, 0.34, 0.06), _at(side * 0.125, 0.42, 0.18), C, 0.022, Vector2(1.1, 1.0), 0.55, false)
	mb.tint = _grey(SUIT * 0.6)
	var _spine: int = mb.begin_part()
	mb.box(Vector3(0.05, 0.33, 0.05), _at(0.0, 0.42, 0.185), G)
	mb.tint = _grey(SUIT)
	LookDevShapes.limb(mb, Vector3(0.0, 0.58, 0.0), Vector3(0.0, 0.74, -0.01), 0.08, 0.065, 6, G, ID, 0, false, false)
	_helmet(mb)
	_shoulders(mb)
	# cyan chest status bar
	mb.tint = Color.WHITE
	var _bar: int = mb.begin_part()
	mb.box(Vector3(0.16, 0.024, 0.012), _at(0.0, 0.52, -0.222), L)
	LookDevBake.ao(mb, AO_STRENGTH, AO_REACH, 0.2, HeroMeshes.WARDEN_WAIST_Y, 1.0, 0.1, SKIP)
	return mb.build()


static func _helmet(mb: MeshBuilder) -> void:
	mb.tint = _bone(1.0)
	LookDevShapes.ellipsoid(mb, Vector3(0.17, 0.17, 0.19), 10, 2, _at(0.0, 0.815, -0.01), C)
	mb.tint = _grey(SUIT * 0.8)
	var _crest: int = mb.begin_part()
	mb.prism(Vector3(0.055, 0.05, 0.26), _at(0.0, 0.975, 0.0), G)
	mb.tint = Color.WHITE
	LookDevShapes.curved_plate(mb, 0.23, 0.05, 0.016, 1.3, 4, _at(0.0, 0.83, -0.196), L)
	mb.tint = _grey(SUIT * 0.9)
	for side: float in [-1.0, 1.0]:
		LookDevShapes.limb(mb, Vector3(side * 0.15, 0.8, 0.0), Vector3(side * 0.215, 0.8, 0.0), 0.045, 0.045, 6, G, ID, 0, false, true)


static func _shoulders(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		# layered pauldron: a broad top shell over a darker lower lame (the left one has a third), tilted outward
		mb.tint = _bone(1.0)
		var top: Transform3D = Transform3D(Basis(Vector3.FORWARD, side * 0.3), Vector3(side * 0.45, 0.63, 0.0))
		LookDevShapes.bevel_box(mb, Vector3(0.3, 0.07, 0.34), top, C, 0.028, Vector2(0.78, 0.86), 0.6, false)
		mb.tint = _grey(SUIT * 1.2)
		var low: Transform3D = Transform3D(Basis(Vector3.FORWARD, side * 0.42), Vector3(side * 0.5, 0.57, 0.0))
		LookDevShapes.bevel_box(mb, Vector3(0.23, 0.055, 0.29), low, G, 0.022, Vector2(0.85, 0.9), 0.55, false)
		if side < 0.0:
			mb.tint = _bone(1.0 * 0.9)
			var third: Transform3D = Transform3D(Basis(Vector3.FORWARD, side * 0.55), Vector3(side * 0.535, 0.515, 0.0))
			LookDevShapes.bevel_box(mb, Vector3(0.19, 0.05, 0.25), third, C, 0.02, Vector2(0.85, 0.9), 0.55, false)
	# shoulder lights: a cyan bar on the back edge of each pauldron (the left one is longer)
	mb.tint = Color.WHITE
	var _light: int = mb.begin_part()
	for side2: float in [-1.0, 1.0]:
		var len_x: float = 0.18 if side2 < 0.0 else 0.12
		var bar: Transform3D = Transform3D(Basis(Vector3.FORWARD, side2 * 0.3), Vector3(side2 * 0.47, 0.67, 0.13))
		mb.box(Vector3(len_x, 0.02, 0.05), bar, L)


## Spheres of the neighbours that are separate meshes (arms, pack): they darken the torso where they meet it.
static func _ghosts(mb: MeshBuilder) -> void:
	var _g: int = mb.begin_part()
	for side: float in [-1.0, 1.0]:
		mb.add_occluder(Vector3(side * 0.4, 0.5, 0.0), 0.09)
		mb.add_occluder(Vector3(side * 0.38, 0.42, -0.08), 0.07)
	mb.add_occluder(Vector3(0.0, 0.44, 0.36), 0.18)
	mb.add_occluder(Vector3(0.0, 0.3, 0.36), 0.16)


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func _grey(k: float) -> Color:
	return Color(k, k, k, 1.0)


## A tint of the armour bone: `k` is the value (1 = the full plate color).
static func _bone(k: float) -> Color:
	return Color(BONE.r * k, BONE.g * k, BONE.b * k, 1.0)
