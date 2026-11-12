class_name LookActorsBurster
extends RefCounted
## The hard-surface Burster (V2-F; looks STYLISED and STYLISED_PLUS; VARIETY_SPEC 5.1). A hunched biped 1.5 m high that carries a
## round hazard-striped tank on its back, wider than its own body: that tank is the whole silhouette (a fat ring of amber and
## black wedges seen from above), so a player counts bursters first and reads the danger second. The head is small and low,
## sunk forward between rounded shoulder domes, and carries the single red optic (a slit on a dark bezel, tilted so the
## top-down camera sees it). Two short digitigrade legs, a pale armour dome over the back, a hose from the tank to the chest, one arm hugging
## the tank and one thin arm hanging with a claw, so the two halves do not match.
## The stripes are vertex colours on the `ceramic` surface (amber and near-black wedges that wind round the tank like a helix),
## so the mesh keeps the three palette surfaces of every enemy (gunmetal, ceramic, emit_red) and the one optic.
## About 390 triangles, weathering baked in the vertex colours, no new material and no new pipeline.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const HEAD_RADII: Vector3 = Vector3(0.115, 0.1, 0.125)
const HEAD_AT: Vector3 = Vector3(0.0, 0.98, -0.42)
const SEED: int = 37
## The tank: world centre, radius, half height and facets. Stripes alternate per facet and wind one facet per ring step.
const TANK_AT: Vector3 = Vector3(0.0, 1.04, 0.3)
const TANK_R: float = 0.34
const TANK_HALF_H: float = 0.4
const TANK_SIDES: int = 10
const TANK_TILT: float = 0.1
const STRIPE_AMBER: Color = Color(1.0, 0.66, 0.16, 1.0)
const STRIPE_DARK: Color = Color(0.06, 0.06, 0.07, 1.0)
## Profile of the tank (radius factor, height factor): a chamfered foot, a straight wall, a rounded shoulder, then the dome.
const TANK_PROFILE: Array[Vector2] = [Vector2(0.84, -1.0), Vector2(1.0, -0.72), Vector2(1.0, 0.72), Vector2(0.8, 1.0)]
const TANK_APEX: float = 1.16
const TANK_TWIST: float = 0.4


static func build() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	_legs(mb)
	var up: Transform3D = Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 0.8, 0.0))
	mb.tint = LookActorsKit.frame(0.3)
	LookDevShapes.ellipsoid(mb, Vector3(0.28, 0.36, 0.25), 8, 2, up * LookActorsKit.at(0.0, 0.3, 0.02), G)
	mb.tint = LookActorsKit.plate(0.9)  # a pale armour dome over the upper back, between the shoulders and the tank
	LookDevShapes.ellipsoid(mb, Vector3(0.25, 0.2, 0.24), 7, 2, up * LookActorsKit.at(0.0, 0.46, 0.08), C, true)
	for side: float in [-1.0, 1.0]:  # shoulder domes: the left one is bigger and bare
		mb.tint = LookActorsKit.plate(0.85 if side > 0.0 else 0.6)
		var rad: float = 0.17 if side > 0.0 else 0.21
		LookDevShapes.ellipsoid(mb, Vector3(rad, 0.13, rad + 0.03), 6, 2, up * LookActorsKit.at(side * 0.3, 0.5, -0.02), C, true)
	_head(mb, up)
	_arms(mb, up)
	_tank(mb)
	var spill: Vector3 = Vector3(0.0, 1.0, -0.4)
	return LookActorsKit.finish(mb, SEED, 1.5, spill, 0.55, 0.4)


static func _legs(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(side * 0.15, 0.8, 0.04)
		var knee: Vector3 = Vector3(side * 0.2, 0.44, -0.12)
		var ankle: Vector3 = Vector3(side * 0.2, 0.08, 0.03)
		mb.tint = LookActorsKit.frame(0.22)
		LookActorsKit.limb2(mb, hip, knee, ankle, 0.135, 0.105, 0.075, 4, G)
		mb.tint = LookActorsKit.frame(0.16)  # a foot: a low dark dome
		LookDevShapes.ellipsoid(mb, Vector3(0.12, 0.075, 0.17), 6, 1, LookActorsKit.at(side * 0.2, 0.0, -0.08), G, true)


static func _head(mb: MeshBuilder, up: Transform3D) -> void:
	var head: Transform3D = LookActorsKit.at(HEAD_AT.x, HEAD_AT.y, HEAD_AT.z)
	mb.tint = LookActorsKit.frame(0.2)
	LookDevShapes.limb(mb, up * Vector3(0.0, 0.5, -0.1), HEAD_AT + Vector3(0.0, -0.06, 0.08), 0.08, 0.07, 5, G, LookActorsKit.ID, 0, false, false)
	LookDevShapes.ellipsoid(mb, HEAD_RADII, 6, 2, head, G, true)  # a dome: the underside of the head is never seen
	mb.tint = LookActorsKit.plate(0.8)  # a pale brow over the dark head
	LookDevShapes.ellipsoid(mb, Vector3(0.06, 0.05, 0.12), 4, 1, head * LookActorsKit.at(0.0, 0.07, 0.02), C, true)
	LookActorsKit.optic(mb, head, HEAD_RADII, 72.0, -0.02, 0.05, 0.6, 4, 0.5)


static func _arms(mb: MeshBuilder, up: Transform3D) -> void:
	# right: a thick arm hugging the tank, the hand against its wall
	var sr: Vector3 = up * Vector3(0.34, 0.48, 0.0)
	var er: Vector3 = up * Vector3(0.44, 0.2, 0.08)
	var wr: Vector3 = Vector3(0.3, 0.7, 0.2)
	mb.tint = LookActorsKit.frame(0.24)
	LookActorsKit.limb2(mb, sr, er, wr, 0.09, 0.08, 0.07, 4, G)
	# left: a thin arm hanging, ending in a pale claw
	var sl: Vector3 = up * Vector3(-0.34, 0.46, 0.0)
	var el: Vector3 = up * Vector3(-0.46, 0.14, -0.06)
	var wl: Vector3 = Vector3(-0.4, 0.46, -0.28)
	mb.tint = LookActorsKit.frame(0.2)
	LookActorsKit.limb2(mb, sl, el, wl, 0.06, 0.05, 0.045, 4, G)
	mb.tint = LookActorsKit.plate(0.6)
	LookActorsKit.cone(mb, wl, wl + Vector3(0.03, -0.17, -0.07), 0.04, 4, C)


## The striped tank and the hose from its foot to the chest.
static func _tank(mb: MeshBuilder) -> void:
	_stripes(mb, TANK_AT, TANK_R, TANK_HALF_H, TANK_SIDES, TANK_TILT)
	mb.tint = LookActorsKit.frame(0.14)  # the hose from the tank foot to the chest
	LookDevShapes.limb(mb, TANK_AT + Vector3(0.0, -0.38, -0.2), Vector3(0.0, 0.8, -0.12), 0.035, 0.03, 4, G, LookActorsKit.ID, 0, false, false)


## A tank of amber and near-black wedges that wind round it: `sides` facets, rings of `TANK_PROFILE`, a dome on top.
static func _stripes(mb: MeshBuilder, centre: Vector3, radius: float, half_h: float, sides: int, tilt: float) -> void:
	var xf: Transform3D = Transform3D(Basis(Vector3.RIGHT, tilt), centre)
	var _part: int = mb.begin_part()
	var rings: int = TANK_PROFILE.size()
	var normals: Array[Vector2] = []  # (radial, vertical) outward normal of each ring: the mean of its two segments
	for k: int in rings:
		var below: Vector2 = TANK_PROFILE[maxi(k - 1, 0)]
		var here: Vector2 = TANK_PROFILE[k]
		var above: Vector2 = TANK_PROFILE[mini(k + 1, rings - 1)] if k < rings - 1 else Vector2(0.0, TANK_APEX)
		var seg_a: Vector2 = here - below if k > 0 else above - here
		var seg_b: Vector2 = above - here
		var n_a: Vector2 = Vector2(seg_a.y * half_h, -seg_a.x * radius).normalized()
		var n_b: Vector2 = Vector2(seg_b.y * half_h, -seg_b.x * radius).normalized()
		normals.append((n_a + n_b).normalized())
	for i: int in sides:
		mb.tint = STRIPE_AMBER if i % 2 == 0 else STRIPE_DARK
		for k: int in rings - 1:
			var corner: Array[Vector3] = [
				_ring_point(xf, k, i, sides, radius, half_h), _ring_point(xf, k, i + 1, sides, radius, half_h),
				_ring_point(xf, k + 1, i + 1, sides, radius, half_h), _ring_point(xf, k + 1, i, sides, radius, half_h),
			]
			var nrm: Array[Vector3] = [
				_ring_normal(xf, normals[k], k, i, sides), _ring_normal(xf, normals[k], k, i + 1, sides),
				_ring_normal(xf, normals[k + 1], k + 1, i + 1, sides), _ring_normal(xf, normals[k + 1], k + 1, i, sides),
			]
			mb.add_tri(C, Transform3D.IDENTITY, corner[0], corner[1], corner[2], nrm[0], nrm[1], nrm[2])
			mb.add_tri(C, Transform3D.IDENTITY, corner[0], corner[2], corner[3], nrm[0], nrm[2], nrm[3])
		var top: int = rings - 1
		var apex: Vector3 = xf * Vector3(0.0, TANK_APEX * half_h, 0.0)
		mb.add_tri(
			C, Transform3D.IDENTITY, _ring_point(xf, top, i, sides, radius, half_h), _ring_point(xf, top, i + 1, sides, radius, half_h),
			apex, _ring_normal(xf, normals[top], top, i, sides), _ring_normal(xf, normals[top], top, i + 1, sides), xf.basis * Vector3.UP
		)
	mb.add_occluder(centre, radius * 0.9)
	mb.add_occluder(centre + Vector3(0.0, -half_h * 0.6, 0.0), radius * 0.8)


static func _ring_angle(k: int, i: int, sides: int) -> float:
	return TAU * (float(i) + TANK_TWIST * float(k)) / float(sides)


static func _ring_point(xf: Transform3D, k: int, i: int, sides: int, radius: float, half_h: float) -> Vector3:
	var p: Vector2 = TANK_PROFILE[k]
	var a: float = _ring_angle(k, i, sides)
	return xf * Vector3(cos(a) * radius * p.x, p.y * half_h, sin(a) * radius * p.x)


static func _ring_normal(xf: Transform3D, profile_normal: Vector2, k: int, i: int, sides: int) -> Vector3:
	var a: float = _ring_angle(k, i, sides)
	return (xf.basis * Vector3(cos(a) * profile_normal.x, profile_normal.y, sin(a) * profile_normal.x)).normalized()
