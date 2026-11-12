class_name EnvDecor
extends RefCounted
## The out-of-bounds dressing of the gritty yard (W3-E): the styled twin of DecorKit with the SAME layout (every container, gantry,
## pipe bundle, lamp post, crate and barrier at the same place and yaw, outside the playable rectangle and clear of the spawn
## edges), built with real detail: corrugated container walls with rust at the foot and per-rib dirt, door bars and handles, corner
## castings, roof ribs, hazard-banded gantry legs, flanged pipes, lamp posts with a lit lens, plus a railing and cable runs along the
## bottom edge. Baked vertex colours, one mesh (`body`) and one lamp-lens mesh (`heads`, driven by ArenaView's flicker).

const PAINT: StringName = EnvShapes.PAINT
const L: float = DecorKit.CONTAINER_L
const W: float = DecorKit.CONTAINER_W
const H: float = DecorKit.CONTAINER_H
const LAMP_H: float = DecorKit.LAMP_H
const LAMP_REACH: float = DecorKit.LAMP_REACH


## Builds all dressing for `arena` into `body` and `heads`. Returns the ground points under the lamp heads (DecorKit's contract).
static func build(arena: ArenaDef, body: MeshBuilder, heads: MeshBuilder) -> Array[Vector3]:
	var yaw: float = arena.decor_yaw_deg
	var lo_x: float = arena.min_x
	var hi_x: float = arena.max_x
	var lo_z: float = arena.min_z
	var hi_z: float = arena.max_z
	var mid_x: float = (lo_x + hi_x) * 0.5
	var mid_z: float = (lo_z + hi_z) * 0.5
	var pools: Array[Vector3] = []
	var heart: Vector3 = Vector3(mid_x, 0.0, mid_z)

	container(body, _xf(Vector3(lo_x + 3.0, 0.0, lo_z - 5.0), yaw), 0, false, 1)
	container(body, _xf(Vector3(lo_x + 3.0, H, lo_z - 5.0), yaw + 7.0), 1, true, 2)
	container(body, _xf(Vector3(mid_x + 2.0, 0.0, lo_z - 7.4), yaw - 4.0), 1, true, 3)
	container(body, _xf(Vector3(hi_x - 1.5, 0.0, lo_z - 6.2), yaw + 3.0), 0, false, 4)
	container(body, _xf(Vector3(hi_x - 1.5, H, lo_z - 6.2), yaw - 5.0), 2, false, 5)
	gantry(body, _xf(Vector3(mid_x + 1.0, 0.0, lo_z - 5.4), yaw), 6.0, 7.2)
	pipes(body, _xf(Vector3(mid_x - 5.5, 0.0, lo_z - 3.4), yaw), 5.0)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(lo_x + 1.0, 0.0, lo_z - 1.8), heart)))
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(hi_x + 0.6, 0.0, lo_z - 1.8), heart)))

	container(body, _xf(Vector3(hi_x + 5.4, 0.0, mid_z - 10.0), yaw + 2.0), 0, true, 6)
	container(body, _xf(Vector3(hi_x + 5.8, 0.0, mid_z - 1.0), yaw - 3.0), 3, false, 7)
	container(body, _xf(Vector3(hi_x + 5.4, H, mid_z - 1.0), yaw + 4.0), 0, false, 8)
	container(body, _xf(Vector3(hi_x + 5.2, 0.0, mid_z + 8.0), yaw + 1.0), 1, false, 9)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(hi_x + 2.2, 0.0, mid_z - 5.8), heart)))
	drums(body, Vector3(hi_x + 2.8, 0.0, mid_z + 5.0))

	container(body, _xf(Vector3(lo_x - 5.0, 0.0, mid_z - 8.0), yaw - 2.0), 2, true, 10)
	container(body, _xf(Vector3(lo_x - 5.0, H, mid_z - 8.0), yaw + 5.0), 0, false, 11)
	container(body, _xf(Vector3(lo_x - 5.6, 0.0, mid_z + 7.0), yaw + 3.0), 1, false, 12)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(lo_x - 2.0, 0.0, mid_z - 5.0), heart)))

	crate(body, _xf(Vector3(mid_x - 1.5, 0.0, hi_z + 2.4), yaw + 8.0), 1.0, 0)
	crate(body, _xf(Vector3(mid_x - 0.2, 0.0, hi_z + 2.3), yaw - 10.0), 0.9, 1)
	crate(body, _xf(Vector3(mid_x - 0.9, 1.0, hi_z + 2.4), yaw + 20.0), 0.8, 2)
	pipes(body, _xf(Vector3(mid_x + 5.6, 0.0, hi_z + 2.8), yaw), 4.6)
	barrier(body, Vector3(lo_x + 6.0, 0.0, hi_z + 1.9), -yaw + 6.0, 3.2)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(lo_x - 0.6, 0.0, hi_z + 1.0), heart)))
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(hi_x - 4.0, 0.0, hi_z + 1.1), heart)))
	railing(body, Vector3(mid_x + 2.2, 0.0, hi_z + 1.5), 4.4)
	cable_run(body, [Vector3(lo_x - 1.4, 0.05, hi_z + 1.2), Vector3(lo_x + 1.2, 0.05, hi_z + 2.6), Vector3(lo_x + 3.6, 0.05, hi_z + 2.4)])
	return pools


## A 20 ft shipping container, long axis along local X: corrugated walls, roof ribs, corner castings, door bars. `kind` 0 red, 1 grey,
## 2 teal, 3 black; `lit` adds an amber window; `salt` varies the dirt of every rib.
static func container(mb: MeshBuilder, t: Transform3D, kind: int, lit: bool, salt: int) -> void:
	var hl: float = L * 0.5
	var hw: float = W * 0.5
	var col: Color = _kind_color(kind)
	var dark: Color = EnvShapes.paint(&"dark_frame", 0.7)
	var foot: Color = col.lerp(EnvShapes.RUST.srgb_to_linear(), 0.38)
	var ys: PackedFloat32Array = PackedFloat32Array([0.0, 0.55, 1.9, H - 0.3])
	var rows: Array[Color] = [_k(foot, 0.62), _k(col, 0.88), _k(col, 1.0), _k(col, 1.12)]
	_bx(mb, t, Vector3(0.0, H * 0.5, 0.0), Vector3(L - 0.1, H - 0.14, W - 0.34), _k(col, 0.7), 0.0)
	_bx(mb, t, Vector3(0.0, H - 0.07, 0.0), Vector3(L - 0.1, 0.08, W - 0.08), _k(col, 1.2), 0.03)
	for side: float in [1.0, -1.0]:
		var wall: Transform3D = t * Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0.0, 0.14, side * (hw - 0.03)))
		EnvShapes.corrugated(mb, PAINT, wall, L - 0.4, H - 0.42, 0.07, 16, ys, rows, 0.7, 0.2, salt * 3 + int(side + 1.0))
		_bx(mb, t, Vector3(0.0, H - 0.1, side * (hw - 0.04)), Vector3(L, 0.14, 0.12), dark, 0.0)
		_bx(mb, t, Vector3(0.0, 0.08, side * (hw - 0.04)), Vector3(L, 0.14, 0.12), dark, 0.0)
	for i: int in 5:
		_bx(mb, t, Vector3(-hl + 0.8 + float(i) * 1.1, H + 0.02, 0.0), Vector3(0.16, 0.07, W - 0.4), _k(col, 1.05), 0.0)
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			_bx(mb, t, Vector3(sx * (hl - 0.1), H * 0.5, sz * (hw - 0.1)), Vector3(0.2, H + 0.04, 0.2), dark, 0.02)
			_bx(mb, t, Vector3(sx * (hl - 0.1), H + 0.08, sz * (hw - 0.1)), Vector3(0.28, 0.1, 0.28), _k(dark, 0.7), 0.0)
		_bx(mb, t, Vector3(sx * (hl - 0.06), H - 0.06, 0.0), Vector3(0.12, 0.12, W), dark, 0.0)
		_bx(mb, t, Vector3(sx * (hl - 0.06), 0.07, 0.0), Vector3(0.12, 0.12, W), dark, 0.0)
	var steel: Color = EnvShapes.paint(&"gunmetal", 0.6)
	for sz2: float in [1.0, -1.0]:
		_bx(mb, t, Vector3(hl - 0.03, H * 0.5, sz2 * (hw * 0.5 - 0.05)), Vector3(0.07, H - 0.34, hw - 0.14), _k(col, 0.95), 0.03)
		for bz: float in [0.2, 0.62]:
			mb.tint = steel
			mb.cylinder(0.026, 0.026, H - 0.34, 6, t * Transform3D(Basis.IDENTITY, Vector3(hl + 0.04, H * 0.5, sz2 * bz)), PAINT)
			_bx(mb, t, Vector3(hl + 0.07, H * 0.5 - 0.1, sz2 * bz), Vector3(0.05, 0.12, 0.07), steel, 0.01)
	for ry: float in [0.5, 1.3, 2.0]:
		_bx(mb, t, Vector3(-hl + 0.04, ry, 0.0), Vector3(0.06, 0.1, W - 0.5), _k(col, 0.85), 0.0)
	_bx(mb, t, Vector3(hl + 0.07, 1.7, 0.0), Vector3(0.04, 0.16, 0.46), EnvShapes.paint(&"ceramic", 0.55), 0.0)
	if lit:
		for wx: float in [-hl + 1.0, -hl + 2.4, -hl + 3.6]:
			_bx(mb, t, Vector3(wx, 1.7, hw + 0.07), Vector3(0.88 if wx < -1.0 else 0.5, 0.32, 0.05), dark, 0.0)
			mb.tint = Color.WHITE
			mb.box(Vector3(0.74 if wx < -1.0 else 0.36, 0.2, 0.05), t * Transform3D(Basis.IDENTITY, Vector3(wx, 1.7, hw + 0.1)), EnvShapes.AMBER)
	PropKit.blob_shadow_box(mb, t, Vector2(L + 0.3, W + 0.4))


## Two legs with hazard-banded feet, a deck beam, two braces and a walkway rail. `span` between the legs along local X.
static func gantry(mb: MeshBuilder, t: Transform3D, span: float, height: float) -> void:
	var half: float = span * 0.5
	var dark: Color = EnvShapes.paint(&"dark_frame", 0.75)
	var steel: Color = EnvShapes.paint(&"gunmetal", 0.62)
	for sx: float in [1.0, -1.0]:
		_bx(mb, t, Vector3(sx * half, height * 0.5, 0.0), Vector3(0.5, height, 0.5), dark, 0.03)
		for i: int in 6:
			var band: Color = EnvShapes.paint(&"hazard", 0.88) if i % 2 == 0 else _k(dark, 0.5)
			_bx(mb, t, Vector3(sx * half, 0.075 + float(i) * 0.15, 0.0), Vector3(0.56, 0.15, 0.56), band, 0.01)
		_bx(mb, t, Vector3(sx * half, 1.3, 0.0), Vector3(0.62, 0.4, 0.62), steel, 0.04)
		strut(mb, t, Vector3(sx * half, 1.4, 0.0), Vector3(sx * half * 0.15, height - 0.3, 0.0), 0.14, steel)
	_bx(mb, t, Vector3(0.0, height, 0.0), Vector3(span + 1.2, 0.55, 0.7), dark, 0.04)
	_bx(mb, t, Vector3(0.0, height + 0.32, 0.0), Vector3(span + 1.2, 0.08, 0.9), steel, 0.02)
	for rx: int in 7:
		_bx(mb, t, Vector3((float(rx) / 6.0 - 0.5) * (span + 1.0), height + 0.7, 0.4), Vector3(0.05, 0.7, 0.05), steel, 0.0)
	_bx(mb, t, Vector3(0.0, height + 1.02, 0.4), Vector3(span + 1.1, 0.05, 0.05), steel, 0.0)


## Three flanged pipes side by side along local X, with clamps and low supports.
static func pipes(mb: MeshBuilder, t: Transform3D, length: float) -> void:
	var kinds: Array[StringName] = [&"steel_red", &"steel_grey", &"dark_frame"]
	var lay: Basis = Basis(Vector3.BACK, PI * 0.5)
	for i: int in 3:
		var z: float = (float(i) - 1.0) * 0.52
		var pos: Vector3 = Vector3(0.0, 0.34, z)
		mb.tint = EnvShapes.paint(kinds[i], 0.95)
		mb.cylinder(0.22, 0.22, length, 12, t * Transform3D(lay, pos), PAINT)
		mb.tint = EnvShapes.paint(&"gunmetal", 0.62)
		for fx: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			mb.cylinder(0.28, 0.28, 0.14, 12, t * Transform3D(lay, pos + Vector3(fx * length * 0.96, 0.0, 0.0)), PAINT)
	for sx: float in [-0.34, 0.34]:
		_bx(mb, t, Vector3(sx * length, 0.1, 0.0), Vector3(0.28, 0.2, 1.7), EnvShapes.paint(&"dark_frame", 0.7), 0.02)


## A lamp post with an arm toward local +X: a base plate with bolts, a tapered pole, a trussed arm, a housing, and (in `heads`) the lit lens.
## Returns the ground point under the lamp head (for the light pools).
static func lamp_post(body: MeshBuilder, heads: MeshBuilder, t: Transform3D) -> Vector3:
	var dark: Color = EnvShapes.paint(&"dark_frame", 0.62)
	var steel: Color = EnvShapes.paint(&"gunmetal", 0.55)
	_bx(body, t, Vector3(0.0, 0.08, 0.0), Vector3(0.62, 0.16, 0.62), steel, 0.03)
	for bx: float in [-0.22, 0.22]:
		for bz: float in [-0.22, 0.22]:
			body.tint = _k(steel, 1.3)
			body.cylinder(0.035, 0.035, 0.07, 6, t * Transform3D(Basis.IDENTITY, Vector3(bx, 0.19, bz)), PAINT)
	body.tint = dark
	body.cylinder(0.08, 0.13, LAMP_H, 10, t * Transform3D(Basis.IDENTITY, Vector3(0.0, LAMP_H * 0.5, 0.0)), PAINT)
	body.cylinder(0.17, 0.17, 0.5, 10, t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0)), PAINT)
	_bx(body, t, Vector3(LAMP_REACH * 0.5, LAMP_H - 0.05, 0.0), Vector3(LAMP_REACH + 0.2, 0.1, 0.1), dark, 0.0)
	strut(body, t, Vector3(0.05, LAMP_H - 0.9, 0.0), Vector3(LAMP_REACH * 0.8, LAMP_H - 0.1, 0.0), 0.05, dark)
	var head_at: Vector3 = Vector3(LAMP_REACH, LAMP_H - 0.2, 0.0)
	_bx(body, t, head_at + Vector3(0.0, 0.13, 0.0), Vector3(0.96, 0.1, 0.62), dark, 0.03)
	_bx(body, t, head_at + Vector3(0.0, -0.08, 0.0), Vector3(0.9, 0.06, 0.56), steel, 0.02)
	heads.tint = Color.WHITE
	heads.box(Vector3(0.8, 0.1, 0.48), t * Transform3D(Basis.IDENTITY, head_at + Vector3(0.0, 0.0, 0.0)), EnvShapes.AMBER)
	return t * Vector3(LAMP_REACH, 0.0, 0.0)


## A railing: posts with two rails, standing at `at`, `length` long along local X of the decor yaw (world X here).
static func railing(mb: MeshBuilder, at: Vector3, length: float) -> void:
	var steel: Color = EnvShapes.paint(&"gunmetal", 0.58)
	var posts: int = floori(length / 1.1) + 1
	for i: int in posts:
		var x: float = at.x + float(i) * length / float(posts - 1) - length * 0.5
		_bx(mb, Transform3D.IDENTITY, Vector3(x, 0.55, at.z), Vector3(0.08, 1.1, 0.08), steel, 0.01)
	for ry: float in [0.5, 0.95]:
		mb.tint = EnvShapes.paint(&"hazard", 0.8) if ry > 0.9 else steel
		mb.cylinder(0.035, 0.035, length, 6, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(at.x, ry, at.z)), PAINT)


## A ground cable run along a polyline (rubber tubes with round joints).
static func cable_run(mb: MeshBuilder, pts: Array[Vector3]) -> void:
	mb.tint = EnvShapes.paint(&"rubber", 0.9)
	for i: int in pts.size() - 1:
		var d: Vector3 = pts[i + 1] - pts[i]
		var dist: float = d.length()
		mb.cylinder(0.055, 0.055, dist, 6, Transform3D(Basis(Quaternion(Vector3.UP, d / dist)), (pts[i] + pts[i + 1]) * 0.5), PAINT)
		mb.sphere(0.055, 6, Transform3D(Basis.IDENTITY, pts[i + 1]), PAINT)


static func strut(mb: MeshBuilder, t: Transform3D, a: Vector3, b: Vector3, thickness: float, col: Color) -> void:
	var d: Vector3 = b - a
	var dist: float = d.length()
	if dist < 0.001:
		return
	var basis: Basis = Basis(Quaternion(Vector3.RIGHT, d / dist))
	mb.tint = col
	mb.box(Vector3(dist, thickness, thickness), t * Transform3D(basis, (a + b) * 0.5), PAINT)


static func crate(mb: MeshBuilder, t: Transform3D, size: float, index: int) -> void:
	EnvProps.crate(mb, t, size, index)
	PropKit.blob_shadow(mb, t.origin, size * 0.9)


static func barrier(mb: MeshBuilder, at: Vector3, rot_deg: float, length: float) -> void:
	var ob: ObstacleDef = ObstacleDef.new()
	ob.shape = ObstacleDef.Shape.BOX
	ob.size_x = length
	ob.size_z = 0.8
	ob.rot_deg = rot_deg
	ob.x = at.x
	ob.z = at.z
	ob.visual = &"jersey_barrier"
	EnvProps.add_obstacle(mb, ob)


static func drums(mb: MeshBuilder, at: Vector3) -> void:
	var ob: ObstacleDef = ObstacleDef.new()
	ob.shape = ObstacleDef.Shape.CIRCLE
	ob.radius = 1.0
	ob.x = at.x
	ob.z = at.z
	ob.visual = &"drum_cluster"
	EnvProps.add_obstacle(mb, ob)


static func _kind_color(kind: int) -> Color:
	match kind:
		0:
			return EnvShapes.paint(&"steel_red", 1.4)
		1:
			return EnvShapes.paint(&"steel_grey", 1.3)
		2:
			return EnvShapes.teal(1.35)
	return EnvShapes.paint(&"dark_frame", 1.0)


static func _k(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## A box with a baked colour (bevelled when `bevel` > 0).
static func _bx(mb: MeshBuilder, t: Transform3D, at: Vector3, size: Vector3, col: Color, bevel: float) -> void:
	mb.tint = col
	if bevel > 0.0:
		LookDevShapes.bevel_box(mb, size, t * Transform3D(Basis.IDENTITY, at), PAINT, bevel)
	else:
		mb.box(size, t * Transform3D(Basis.IDENTITY, at), PAINT)


static func _lamp_at(pos: Vector3, target: Vector3) -> Transform3D:
	var yaw_deg: float = rad_to_deg(atan2(-(target.z - pos.z), target.x - pos.x))
	return _xf(pos, yaw_deg)


static func _xf(pos: Vector3, yaw_deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
