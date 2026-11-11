class_name LookDevHead
extends RefCounted
## Helmet and pauldrons of the Warden v3 (W3-C round 3), in torso space like LookDevWarden. The helmet is about a fifth of
## the figure: a big rounded block (flat front, no forehead dome) with a horizontal visor slot with angled corners, a
## vent jaw guard, cheek plates, a sensor pod on the right side only and a dorsal fin with a cyan stripe that the top-down
## camera sees. The pauldrons are two stacked smooth domes each, the right one bigger than the left (an asymmetric
## silhouette), with a cyan inlay on the top layer.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
## Centre of the helmet block and its size (width, height, depth).
const HC: Vector3 = Vector3(0.0, 0.785, -0.005)
const HS: Vector3 = Vector3(0.38, 0.36, 0.4)
const H_TAPER: Vector2 = Vector2(0.84, 0.72)


static func helmet(mb: MeshBuilder) -> void:
	mb.tint = LookDevWarden._steel(0.78)
	LookDevRound.rounded_box(mb, HS, Transform3D(Basis.IDENTITY, HC), G, 0.085, H_TAPER)
	_visor(mb)
	# jaw guard with a vent slot
	mb.tint = LookDevWarden._steel(0.7)
	var jaw_y: float = HC.y - 0.12
	LookDevShapes.bevel_box(mb, Vector3(0.25, 0.1, 0.11), _at(0.0, jaw_y, -0.175), G, 0.035, Vector2.ONE, 0.0)
	mb.tint = LookDevWarden._suit(0.7)
	for k: int in 1:
		var slot: Vector3 = Vector3(0.0, jaw_y + 0.0 * float(k), -0.236)
		mb.box(Vector3(0.15, 0.012, 0.012), Transform3D(Basis.IDENTITY, slot), G)
	# cheek plates; the right one carries the sensor pod
	mb.tint = LookDevWarden._steel(0.9)
	for side: float in [-1.0, 1.0]:
		LookDevShapes.bevel_box(mb, Vector3(0.05, 0.14, 0.22), _at(side * 0.205, HC.y - 0.035, 0.0), G, 0.025, Vector2.ONE, 0.0)
	mb.tint = LookDevWarden._steel(0.55)
	LookDevShapes.limb(mb, Vector3(0.225, HC.y + 0.035, -0.04), Vector3(0.28, HC.y + 0.035, -0.04), 0.048, 0.046, 10, G, Transform3D.IDENTITY, 0, false, true)
	# dorsal fin
	mb.tint = LookDevWarden._steel(0.8)
	LookDevShapes.bevel_box(mb, Vector3(0.07, 0.05, 0.3), _at(0.0, HC.y + 0.188, 0.02), G, 0.02, Vector2.ONE, 0.0)
	mb.tint = Color.WHITE
	var _lights: int = mb.begin_part()
	mb.box(Vector3(0.04, 0.012, 0.22), _at(0.0, HC.y + 0.217, 0.03), L)
	mb.box(Vector3(0.01, 0.05, 0.05), _at(0.281, HC.y + 0.035, -0.04), L)


## The visor: a flat hexagonal slot (wide, with angled corners) in emissive cyan over a darker bezel, lying on the front
## face of the helmet (the front leans back a little because the block tapers toward the top).
static func _visor(mb: MeshBuilder) -> void:
	var y: float = 0.03
	var u: float = (y / (HS.y * 0.5) + 1.0) * 0.5
	var front: float = HC.z - HS.z * 0.5 * lerpf(1.0, H_TAPER.y, u)
	var lean: float = atan((1.0 - H_TAPER.y) * HS.z * 0.5 / HS.y)
	var basis: Basis = Basis(Vector3.RIGHT, lean)
	var n: Vector3 = basis * Vector3.FORWARD
	var pts: Array[Vector2] = [
		Vector2(-0.12, 0.0), Vector2(-0.095, 0.034), Vector2(0.095, 0.034), Vector2(0.12, 0.0), Vector2(0.095, -0.03),
		Vector2(-0.095, -0.03),
	]
	var bezel_xf: Transform3D = Transform3D(basis, Vector3(0.0, HC.y + y, front - 0.001))
	var visor_xf: Transform3D = Transform3D(basis, Vector3(0.0, HC.y + y, front - 0.004))
	mb.tint = LookDevWarden._suit(0.6)
	var _bezel: int = mb.begin_part()
	for k: int in pts.size():
		var a: Vector2 = pts[k] * Vector2(1.16, 1.5)
		var b: Vector2 = pts[(k + 1) % pts.size()] * Vector2(1.16, 1.5)
		mb.add_tri(G, bezel_xf, Vector3.ZERO, Vector3(a.x, a.y, 0.0), Vector3(b.x, b.y, 0.0), n, n, n)
	mb.tint = Color.WHITE
	var _glass: int = mb.begin_part()
	for k: int in pts.size():
		var a2: Vector2 = pts[k]
		var b2: Vector2 = pts[(k + 1) % pts.size()]
		mb.add_tri(L, visor_xf, Vector3.ZERO, Vector3(a2.x, a2.y, 0.0), Vector3(b2.x, b2.y, 0.0), n, n, n)


## Two pauldrons: a big smooth dome with a smaller dome stacked on it (the same number of sides, so the seam where the top
## layer comes out of the lower one is a clean ring and not a zigzag), and a cyan inlay on the back half of the top layer.
static func pauldrons(mb: MeshBuilder) -> void:
	var specs: Array[Array] = [
		[1.0, Vector3(0.44, 0.57, 0.0), Vector3(0.2, 0.13, 0.24), Vector3(0.16, 0.09, 0.19), 0.07, 0.25],
		[-1.0, Vector3(-0.43, 0.57, 0.0), Vector3(0.18, 0.11, 0.21), Vector3(0.14, 0.075, 0.165), 0.06, 0.25],
	]
	for spec: Array in specs:
		var side: float = spec[0]
		var centre: Vector3 = spec[1]
		var r_low: Vector3 = spec[2]
		var r_top: Vector3 = spec[3]
		var rise: float = spec[4]
		var lean: float = spec[5]
		var tilt: Basis = Basis(Vector3.FORWARD, side * lean)
		mb.tint = LookDevWarden._steel(0.75)
		LookDevShapes.ellipsoid(mb, r_low, 10, 3, Transform3D(tilt, centre), G, true)
		if side > 0.0:
			mb.tint = LookDevWarden._bone(1.0)
		else:
			mb.tint = LookDevWarden._steel(1.05)
		var top_c: Vector3 = centre + tilt * Vector3(0.0, rise, 0.0)
		LookDevShapes.ellipsoid(mb, r_top, 10, 2, Transform3D(tilt, top_c), C if side > 0.0 else G, true)
	mb.tint = Color.WHITE
	var _inlay: int = mb.begin_part()
	for spec2: Array in specs:
		var s2: float = spec2[0]
		var c2: Vector3 = spec2[1]
		var rt: Vector3 = spec2[3]
		var rise2: float = spec2[4]
		var lean2: float = spec2[5]
		var tilt2: Basis = Basis(Vector3.FORWARD, s2 * lean2)
		var inlay_c: Vector3 = c2 + tilt2 * Vector3(0.0, rise2 + rt.y * 0.95, rt.z * 0.34)
		mb.box(Vector3(rt.x * 0.95, 0.014, rt.z * 0.4), Transform3D(tilt2, inlay_c), L)


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))
