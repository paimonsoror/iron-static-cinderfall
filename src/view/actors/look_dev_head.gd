class_name LookDevHead
extends RefCounted
## Helmet and pauldrons of the Warden v4 (W3-C round 4), in torso space like LookDevWarden. The helmet is about a fifth of the
## figure: one smooth ellipsoid shell, a cyan visor band that wraps around the front and the sides of the shell and ends in
## angled corners (a band, not a slot: it must not read as an eye, and there is no mouth under it), a smooth vent jaw guard
## with small slits on its sides, a sensor pod on the right side only and a dorsal fin with a cyan stripe that the top-down
## camera sees. The pauldrons are two stacked smooth domes each, the right one bigger than the left (an asymmetric
## silhouette), with a cyan inlay on the top layer.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const L: StringName = &"emit_cyan"
## Centre of the helmet shell, its radii and its size (width, height, depth).
const HC: Vector3 = Vector3(0.0, 0.78, -0.005)
const HR: Vector3 = Vector3(0.19, 0.19, 0.21)
const HS: Vector3 = Vector3(0.38, 0.38, 0.42)
## Visor band: half angle around the front (radians), latitude of its middle, half height in latitude, columns.
const VISOR_PHI: float = 1.3
const VISOR_LAT: float = 0.12
const VISOR_H: float = 0.25
const VISOR_COLS: int = 10
const JAW_C: Vector3 = Vector3(0.0, -0.14, -0.13)  ## relative to HC
const JAW_R: Vector3 = Vector3(0.115, 0.065, 0.09)


static func helmet(mb: MeshBuilder) -> void:
	mb.tint = LookDevWarden._steel(0.85)
	LookDevShapes.ellipsoid(mb, HR, 12, 3, Transform3D(Basis.IDENTITY, HC), G)
	_visor(mb)
	# jaw guard: a smooth ellipsoid under the visor band with two small slits on each side
	mb.tint = LookDevWarden._steel(0.65)
	LookDevShapes.ellipsoid(mb, JAW_R, 8, 2, Transform3D(Basis.IDENTITY, HC + JAW_C), G)
	mb.tint = LookDevWarden._suit(0.5)
	var _slits: int = mb.begin_part()
	for side: float in [-1.0, 1.0]:
		for lat: float in [-0.15, 0.3]:
			_slit(mb, HC + JAW_C, JAW_R, side * 1.15, lat)
	# sensor pod on the right side only
	mb.tint = LookDevWarden._steel(0.55)
	LookDevShapes.limb(mb, Vector3(0.17, HC.y + 0.03, -0.05), Vector3(0.245, HC.y + 0.03, -0.05), 0.045, 0.043, 8, G, Transform3D.IDENTITY, 0, false, true)
	# dorsal fin
	mb.tint = LookDevWarden._steel(0.85)
	LookDevShapes.bevel_box(mb, Vector3(0.07, 0.05, 0.26), _at(0.0, HC.y + 0.188, 0.03), G, 0.02, Vector2.ONE, 0.0, true, true)
	mb.tint = Color.WHITE
	var _lights: int = mb.begin_part()
	mb.box(Vector3(0.04, 0.012, 0.2), _at(0.0, HC.y + 0.216, 0.04), L)
	mb.box(Vector3(0.01, 0.05, 0.05), _at(0.249, HC.y + 0.03, -0.05), L)


## The visor: a cyan band that follows the shell (offset 4.5 mm) around the front, over a dark bezel (offset 2 mm, a little
## bigger). Its height falls off toward the ends, so the corners are angled.
static func _visor(mb: MeshBuilder) -> void:
	mb.tint = LookDevWarden._suit(0.6)
	var _bezel: int = mb.begin_part()
	_band(mb, G, VISOR_PHI * 1.05, VISOR_H * 1.3, 0.002)
	mb.tint = Color.WHITE
	var _glass: int = mb.begin_part()
	_band(mb, L, VISOR_PHI, VISOR_H, 0.0045)


static func _band(mb: MeshBuilder, mat_id: StringName, phi_max: float, half_h: float, lift: float) -> void:
	var top: PackedVector3Array = PackedVector3Array()
	var bot: PackedVector3Array = PackedVector3Array()
	var nt: PackedVector3Array = PackedVector3Array()
	var nb: PackedVector3Array = PackedVector3Array()
	for k: int in VISOR_COLS + 1:
		var u: float = 2.0 * float(k) / float(VISOR_COLS) - 1.0
		var shrink: float = 1.0
		if absf(u) > 0.6:
			shrink = lerpf(1.0, 0.38, (absf(u) - 0.6) / 0.4)
		var phi: float = phi_max * u
		var p_top: Vector3 = _shell(phi, VISOR_LAT + half_h * shrink)
		var p_bot: Vector3 = _shell(phi, VISOR_LAT - half_h * shrink * 0.85)
		nt.append(_shell_normal(p_top))
		nb.append(_shell_normal(p_bot))
		top.append(HC + p_top + nt[k] * lift)
		bot.append(HC + p_bot + nb[k] * lift)
	for k: int in VISOR_COLS:
		mb.add_tri(mat_id, Transform3D.IDENTITY, bot[k], bot[k + 1], top[k + 1], nb[k], nb[k + 1], nt[k + 1])
		mb.add_tri(mat_id, Transform3D.IDENTITY, bot[k], top[k + 1], top[k], nb[k], nt[k + 1], nt[k])


## A point of the helmet shell (relative to HC) at azimuth `phi` from the front (-Z) and latitude `lat`.
static func _shell(phi: float, lat: float) -> Vector3:
	return Vector3(HR.x * cos(lat) * sin(phi), HR.y * sin(lat), -HR.z * cos(lat) * cos(phi))


static func _shell_normal(p: Vector3) -> Vector3:
	return Vector3(p.x / (HR.x * HR.x), p.y / (HR.y * HR.y), p.z / (HR.z * HR.z)).normalized()


## A thin dark slit lying on an ellipsoid (centre `c`, radii `r`) at azimuth `phi` and latitude `lat`.
static func _slit(mb: MeshBuilder, c: Vector3, r: Vector3, phi: float, lat: float) -> void:
	var rel: Vector3 = Vector3(r.x * cos(lat) * sin(phi), r.y * sin(lat), -r.z * cos(lat) * cos(phi))
	var n: Vector3 = Vector3(rel.x / (r.x * r.x), rel.y / (r.y * r.y), rel.z / (r.z * r.z)).normalized()
	var along: Vector3 = (Vector3.UP - n * n.y).normalized() * 0.02
	var across: Vector3 = n.cross(along.normalized()).normalized() * 0.004
	var p: Vector3 = c + rel + n * 0.002
	mb.add_tri(G, Transform3D.IDENTITY, p - along - across, p - along + across, p + along + across, n, n, n)
	mb.add_tri(G, Transform3D.IDENTITY, p - along - across, p + along + across, p + along - across, n, n, n)


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
