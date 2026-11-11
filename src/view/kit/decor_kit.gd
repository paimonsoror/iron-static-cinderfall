class_name DecorKit
extends RefCounted
## Out-of-bounds dressing (GDD 4.2, 12.3): stacked containers (dull red and grey), gantry portals, pipe bundles,
## lamp posts with amber heads, cable runs, low crates and barriers. Everything lives outside the playable rectangle and
## is turned to the arena's decor yaw (about 38 degrees) so the picture reads as the isometric yard of
## topdown_approved.png. Tall pieces stay away from the lower edge (they would hide the ground enemies walk on).
## Static meshes only; the lamp heads go to their own builder so ArenaView can flicker them.

const CONTAINER_L: float = 6.0
const CONTAINER_W: float = 2.4
const CONTAINER_H: float = 2.6
const LAMP_H: float = 5.2
const LAMP_REACH: float = 1.1


## Builds all dressing for `arena` into `body` (structure) and `heads` (emissive lamp panels).
## Returns the ground points under the lamp heads, for the light pools.
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

	# Top (behind the spawn edge): the tall backdrop.
	container(body, _xf(Vector3(lo_x + 3.0, 0.0, lo_z - 5.0), yaw), true, false)
	container(body, _xf(Vector3(lo_x + 3.0, CONTAINER_H, lo_z - 5.0), yaw + 7.0), false, true)
	container(body, _xf(Vector3(mid_x + 2.0, 0.0, lo_z - 7.4), yaw - 4.0), false, true)
	container(body, _xf(Vector3(hi_x - 1.5, 0.0, lo_z - 6.2), yaw + 3.0), true, false)
	container(body, _xf(Vector3(hi_x - 1.5, CONTAINER_H, lo_z - 6.2), yaw - 5.0), false, false)
	gantry(body, _xf(Vector3(mid_x + 1.0, 0.0, lo_z - 5.4), yaw), 6.0, 7.2)
	pipes(body, _xf(Vector3(mid_x - 5.5, 0.0, lo_z - 3.4), yaw), 5.0)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(lo_x + 1.0, 0.0, lo_z - 1.8), heart)))
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(hi_x + 0.6, 0.0, lo_z - 1.8), heart)))

	# Right (behind the right spawn edge): visible on wide screens.
	container(body, _xf(Vector3(hi_x + 5.4, 0.0, mid_z - 10.0), yaw + 2.0), true, true)
	container(body, _xf(Vector3(hi_x + 5.8, 0.0, mid_z - 1.0), yaw - 3.0), false, false)
	container(body, _xf(Vector3(hi_x + 5.4, CONTAINER_H, mid_z - 1.0), yaw + 4.0), true, false)
	container(body, _xf(Vector3(hi_x + 5.2, 0.0, mid_z + 8.0), yaw + 1.0), true, false)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(hi_x + 2.2, 0.0, mid_z - 5.8), heart)))
	drums(body, Vector3(hi_x + 2.8, 0.0, mid_z + 5.0))

	# Left (behind the core): visible on wide screens.
	container(body, _xf(Vector3(lo_x - 5.0, 0.0, mid_z - 8.0), yaw - 2.0), false, true)
	container(body, _xf(Vector3(lo_x - 5.0, CONTAINER_H, mid_z - 8.0), yaw + 5.0), true, false)
	container(body, _xf(Vector3(lo_x - 5.6, 0.0, mid_z + 7.0), yaw + 3.0), true, false)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(lo_x - 2.0, 0.0, mid_z - 5.0), heart)))

	# Bottom (in front of the arena): low pieces only.
	crate(body, _xf(Vector3(mid_x - 1.5, 0.0, hi_z + 2.4), yaw + 8.0), 1.0)
	crate(body, _xf(Vector3(mid_x - 0.2, 0.0, hi_z + 2.3), yaw - 10.0), 0.9)
	crate(body, _xf(Vector3(mid_x - 0.9, 1.0, hi_z + 2.4), yaw + 20.0), 0.8)
	pipes(body, _xf(Vector3(mid_x + 5.6, 0.0, hi_z + 2.8), yaw), 4.6)
	barrier(body, Vector3(lo_x + 6.0, 0.0, hi_z + 1.9), -yaw + 6.0, 3.2)
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(lo_x - 0.6, 0.0, hi_z + 1.0), heart)))
	pools.append(lamp_post(body, heads, _lamp_at(Vector3(hi_x - 4.0, 0.0, hi_z + 1.1), heart)))
	return pools


## 20 ft shipping container, long axis along local X, ribbed walls and roof, corner posts, door bars. `red` picks
## the dull red steel, else grey; `lit` adds an amber window slit.
static func container(mb: MeshBuilder, t: Transform3D, red: bool, lit: bool) -> void:
	var body: StringName = &"steel_red" if red else &"steel_grey"
	var hl: float = CONTAINER_L * 0.5
	var hw: float = CONTAINER_W * 0.5
	mb.box(Vector3(CONTAINER_L, CONTAINER_H, CONTAINER_W), t * Transform3D(Basis.IDENTITY, Vector3(0.0, CONTAINER_H * 0.5, 0.0)), body)
	var rib_n: int = 11
	for i: int in rib_n:
		var x: float = -hl + 0.45 + (CONTAINER_L - 0.9) * float(i) / float(rib_n - 1)
		for side: float in [1.0, -1.0]:
			mb.box(Vector3(0.12, CONTAINER_H - 0.4, 0.07), t * Transform3D(Basis.IDENTITY, Vector3(x, CONTAINER_H * 0.5, side * (hw + 0.03))), body)
		mb.box(Vector3(0.12, 0.05, CONTAINER_W - 0.3), t * Transform3D(Basis.IDENTITY, Vector3(x, CONTAINER_H + 0.025, 0.0)), body)
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			mb.box(Vector3(0.2, CONTAINER_H + 0.06, 0.2), t * Transform3D(Basis.IDENTITY, Vector3(sx * (hl - 0.04), CONTAINER_H * 0.5, sz * (hw - 0.04))), &"dark_frame")
		mb.box(Vector3(0.14, 0.14, CONTAINER_W), t * Transform3D(Basis.IDENTITY, Vector3(sx * (hl - 0.04), CONTAINER_H + 0.03, 0.0)), &"dark_frame")
	for side: float in [1.0, -1.0]:
		mb.box(Vector3(CONTAINER_L, 0.14, 0.14), t * Transform3D(Basis.IDENTITY, Vector3(0.0, CONTAINER_H + 0.03, side * (hw - 0.04))), &"dark_frame")
	for bz: float in [0.32, -0.32]:
		mb.box(Vector3(0.06, CONTAINER_H - 0.35, 0.07), t * Transform3D(Basis.IDENTITY, Vector3(hl + 0.04, CONTAINER_H * 0.5, bz)), &"gunmetal")
	if lit:
		mb.box(Vector3(0.7, 0.24, 0.05), t * Transform3D(Basis.IDENTITY, Vector3(-hl + 1.0, 1.7, hw + 0.07)), &"emit_amber")


## Two legs with hazard-banded feet, a deck beam and two braces. `span` between the legs along local X.
static func gantry(mb: MeshBuilder, t: Transform3D, span: float, height: float) -> void:
	var half: float = span * 0.5
	for sx: float in [1.0, -1.0]:
		mb.box(Vector3(0.5, height, 0.5), t * Transform3D(Basis.IDENTITY, Vector3(sx * half, height * 0.5, 0.0)), &"dark_frame")
		mb.box(Vector3(0.56, 0.9, 0.56), t * Transform3D(Basis.IDENTITY, Vector3(sx * half, 0.45, 0.0)), &"hazard")
		mb.box(Vector3(0.6, 0.4, 0.6), t * Transform3D(Basis.IDENTITY, Vector3(sx * half, 1.1, 0.0)), &"dark_frame")
		strut(mb, t, Vector3(sx * half, 1.4, 0.0), Vector3(sx * half * 0.15, height - 0.3, 0.0), 0.14, &"gunmetal")
	mb.box(Vector3(span + 1.2, 0.55, 0.7), t * Transform3D(Basis.IDENTITY, Vector3(0.0, height, 0.0)), &"dark_frame")
	mb.box(Vector3(span + 1.2, 0.08, 0.9), t * Transform3D(Basis.IDENTITY, Vector3(0.0, height + 0.32, 0.0)), &"gunmetal")


## Three pipes side by side along local X with flanges and low supports.
static func pipes(mb: MeshBuilder, t: Transform3D, length: float) -> void:
	var mats: Array[StringName] = [&"steel_red", &"steel_grey", &"dark_frame"]
	var lay: Basis = Basis(Vector3.BACK, PI * 0.5)
	for i: int in 3:
		var z: float = (float(i) - 1.0) * 0.52
		var pos: Vector3 = Vector3(0.0, 0.34, z)
		mb.cylinder(0.22, 0.22, length, 10, t * Transform3D(lay, pos), mats[i])
		for fx: float in [-0.5, 0.0, 0.5]:
			mb.cylinder(0.28, 0.28, 0.14, 10, t * Transform3D(lay, pos + Vector3(fx * length * 0.96, 0.0, 0.0)), &"gunmetal")
	for sx: float in [-0.34, 0.34]:
		mb.box(Vector3(0.28, 0.2, 1.7), t * Transform3D(Basis.IDENTITY, Vector3(sx * length, 0.1, 0.0)), &"dark_frame")


## Lamp post with an arm toward local +X. The base sits at the transform origin. Returns the ground point under the
## lamp head (for the light pool).
static func lamp_post(body: MeshBuilder, heads: MeshBuilder, t: Transform3D) -> Vector3:
	body.box(Vector3(0.5, 0.3, 0.5), t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 0.0)), &"gunmetal")
	body.cylinder(0.08, 0.12, LAMP_H, 8, t * Transform3D(Basis.IDENTITY, Vector3(0.0, LAMP_H * 0.5, 0.0)), &"dark_frame")
	body.box(Vector3(LAMP_REACH + 0.2, 0.1, 0.1), t * Transform3D(Basis.IDENTITY, Vector3(LAMP_REACH * 0.5, LAMP_H - 0.05, 0.0)), &"dark_frame")
	var head_at: Vector3 = Vector3(LAMP_REACH, LAMP_H - 0.2, 0.0)
	body.box(Vector3(0.9, 0.06, 0.56), t * Transform3D(Basis.IDENTITY, head_at + Vector3(0.0, 0.13, 0.0)), &"dark_frame")
	heads.box(Vector3(0.78, 0.22, 0.46), t * Transform3D(Basis.IDENTITY, head_at), &"emit_amber")
	var ground: Vector3 = t * Vector3(LAMP_REACH, 0.0, 0.0)
	return ground


## Ground-level cable run along a polyline (points are world positions), rubber tubes.
static func cable(mb: MeshBuilder, pts: Array[Vector3], radius: float) -> void:
	for i: int in pts.size() - 1:
		tube(mb, pts[i], pts[i + 1], radius, &"rubber")
		mb.sphere(radius, 6, Transform3D(Basis.IDENTITY, pts[i + 1]), &"rubber")


## A cylinder from `a` to `b` (world positions).
static func tube(mb: MeshBuilder, a: Vector3, b: Vector3, radius: float, mat_id: StringName) -> void:
	var d: Vector3 = b - a
	var dist: float = d.length()
	if dist < 0.001:
		return
	var basis: Basis = Basis(Quaternion(Vector3.UP, d / dist))
	mb.cylinder(radius, radius, dist, 6, Transform3D(basis, (a + b) * 0.5), mat_id)


## A box strut from `a` to `b` (positions in the frame of `t`).
static func strut(mb: MeshBuilder, t: Transform3D, a: Vector3, b: Vector3, thickness: float, mat_id: StringName) -> void:
	var d: Vector3 = b - a
	var dist: float = d.length()
	if dist < 0.001:
		return
	var basis: Basis = Basis(Quaternion(Vector3.RIGHT, d / dist))
	mb.box(Vector3(dist, thickness, thickness), t * Transform3D(basis, (a + b) * 0.5), mat_id)


static func crate(mb: MeshBuilder, t: Transform3D, size: float) -> void:
	PropKit.crate(mb, t, size)
	PropKit.blob_shadow(mb, t.origin, size * 0.9)


## Jersey barrier of `length` at `at`, turned like the decor (`rot_deg` follows ObstacleDef: local +X to (cos, sin)).
static func barrier(mb: MeshBuilder, at: Vector3, rot_deg: float, length: float) -> void:
	var ob: ObstacleDef = ObstacleDef.new()
	ob.shape = ObstacleDef.Shape.BOX
	ob.size_x = length
	ob.size_z = 0.8
	ob.rot_deg = rot_deg
	ob.x = at.x
	ob.z = at.z
	ob.visual = &"jersey_barrier"
	PropKit.add_obstacle(mb, ob)


static func drums(mb: MeshBuilder, at: Vector3) -> void:
	var ob: ObstacleDef = ObstacleDef.new()
	ob.shape = ObstacleDef.Shape.CIRCLE
	ob.radius = 1.0
	ob.x = at.x
	ob.z = at.z
	ob.visual = &"drum_cluster"
	PropKit.add_obstacle(mb, ob)


## Lamp transform at `pos` with its arm reaching toward `target`.
static func _lamp_at(pos: Vector3, target: Vector3) -> Transform3D:
	var yaw_deg: float = rad_to_deg(atan2(-(target.z - pos.z), target.x - pos.x))
	return _xf(pos, yaw_deg)


static func _xf(pos: Vector3, yaw_deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
