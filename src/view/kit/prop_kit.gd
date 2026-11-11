class_name PropKit
extends RefCounted
## In-play props, built into one MeshBuilder and keyed by `obstacle.visual` from arena.json (GDD 4.2):
## jersey_barrier (extruded concrete profile with red chevrons), crate_stack, drum_cluster. Unknown ids fall back to a
## plain grey primitive of the obstacle's footprint so a data change never leaves a hole. Each prop also gets a stack of
## flat dark blob shadows (contact shadow that works on every quality tier). Palette materials only.

const SHADOW_LIFT: float = 0.014


## Adds the visual of one obstacle. `ob.rot_deg` follows ObstacleDef.contains: local +X maps to world
## (cos a, sin a) in (x, z), which is a rotation of -a about +Y.
static func add_obstacle(mb: MeshBuilder, ob: ObstacleDef) -> void:
	var base: Transform3D = Transform3D(Basis(Vector3.UP, -deg_to_rad(ob.rot_deg)), Vector3(ob.x, 0.0, ob.z))
	match ob.visual:
		&"jersey_barrier":
			_barrier(mb, base, ob)
		&"crate_stack":
			_crates(mb, base, ob)
		&"drum_cluster":
			_drums(mb, base, ob)
		_:
			_fallback(mb, base, ob)


## Soft-looking contact shadow: two stacked discs. Offset (dx, dz) leans it away from the key light.
static func blob_shadow(mb: MeshBuilder, center: Vector3, radius: float, offset: Vector2 = Vector2(0.12, -0.08)) -> void:
	var at: Vector3 = Vector3(center.x + offset.x, SHADOW_LIFT, center.z + offset.y)
	mb.disc(radius * 1.15, 16, Transform3D(Basis.IDENTITY, at), &"shadow_blob")
	mb.disc(radius * 0.8, 16, Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.002, 0.0)), &"shadow_blob")


static func _at(base: Transform3D, local_pos: Vector3, local_yaw_deg: float = 0.0) -> Transform3D:
	return base * Transform3D(Basis(Vector3.UP, deg_to_rad(local_yaw_deg)), local_pos)


static func _barrier(mb: MeshBuilder, base: Transform3D, ob: ObstacleDef) -> void:
	var length: float = ob.size_x
	var depth: float = ob.size_z
	var k: float = depth / 0.8
	mb.box(Vector3(length, 0.3, depth * 0.96), _at(base, Vector3(0.0, 0.15, 0.0)), &"concrete_light")
	mb.box(Vector3(length - 0.1, 0.34, 0.66 * k), _at(base, Vector3(0.0, 0.47, 0.0)), &"concrete_light")
	mb.box(Vector3(length - 0.22, 0.3, 0.42 * k), _at(base, Vector3(0.0, 0.79, 0.0)), &"concrete_light")
	var stripes: int = maxi(3, floori((length - 0.4) / 0.5))
	var pitch: float = (length - 0.4) / float(stripes)
	for i: int in stripes:
		var lx: float = -length * 0.5 + 0.2 + pitch * (float(i) + 0.5)
		if i % 2 == 0:
			mb.box(Vector3(0.2, 0.02, 0.46 * k), _at(base, Vector3(lx, 0.951, 0.0), 40.0), &"steel_red")
	# Red band along the lower slab, interrupted by the chevron rhythm.
	mb.box(Vector3(length * 0.98, 0.07, depth * 0.97), _at(base, Vector3(0.0, 0.08, 0.0)), &"steel_red")
	blob_shadow_box(mb, base, Vector2(length + 0.2, depth + 0.3))


static func _crates(mb: MeshBuilder, base: Transform3D, ob: ObstacleDef) -> void:
	var s: float = ob.radius / 1.3
	# (local x, local z, size, yaw degrees)
	var plan: Array[Vector4] = [
		Vector4(-0.45, 0.2, 1.0, 10.0),
		Vector4(0.55, 0.25, 1.0, -6.0),
		Vector4(0.1, -0.75, 0.8, 25.0),
	]
	for c: Vector4 in plan:
		crate(mb, _at(base, Vector3(c.x * s, 0.0, c.y * s), c.w), c.z * s)
	crate(mb, _at(base, Vector3(-0.4 * s, 1.0 * s, 0.2 * s), 14.0), 0.9 * s)
	blob_shadow(mb, base.origin, ob.radius * 0.95)


## One crate (dark frame box, steel lid, gunmetal corner posts, amber label plate) standing on the origin of `t`.
static func crate(mb: MeshBuilder, t: Transform3D, size: float) -> void:
	var h: float = size
	mb.box(Vector3(size, h, size), t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)), &"dark_frame")
	mb.box(Vector3(size * 0.82, 0.04, size * 0.82), t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.02, 0.0)), &"steel_grey")
	var post: float = 0.1 * size
	for ix: int in 2:
		for iz: int in 2:
			var px: float = (float(ix) - 0.5) * (size - post * 0.4)
			var pz: float = (float(iz) - 0.5) * (size - post * 0.4)
			mb.box(Vector3(post, h * 1.01, post), t * Transform3D(Basis.IDENTITY, Vector3(px, h * 0.5, pz)), &"gunmetal")
	mb.box(Vector3(size * 0.3, size * 0.2, 0.03), t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.55, size * 0.5 + 0.012)), &"hazard")


static func _drums(mb: MeshBuilder, base: Transform3D, ob: ObstacleDef) -> void:
	var s: float = ob.radius / 1.0
	var spots: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(0.64, 0.12), Vector2(-0.55, 0.42), Vector2(0.1, -0.66), Vector2(-0.4, -0.5)
	]
	var mats: Array[StringName] = [&"steel_red", &"steel_grey", &"steel_red", &"dark_frame", &"steel_grey"]
	for i: int in spots.size():
		var at: Vector3 = Vector3(spots[i].x * s, 0.45, spots[i].y * s)
		var t: Transform3D = base * Transform3D(Basis.IDENTITY, at)
		mb.cylinder(0.3, 0.3, 0.9, 10, t, mats[i])
		var band_mat: StringName = &"hazard" if i == 1 else &"gunmetal"
		mb.cylinder(0.315, 0.315, 0.07, 10, t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.22, 0.0)), band_mat)
		mb.cylinder(0.315, 0.315, 0.07, 10, t * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.22, 0.0)), &"gunmetal")
	blob_shadow(mb, base.origin, ob.radius * 0.95)


static func _fallback(mb: MeshBuilder, base: Transform3D, ob: ObstacleDef) -> void:
	if ob.shape == ObstacleDef.Shape.CIRCLE:
		mb.cylinder(ob.radius, ob.radius, 0.9, 12, base * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.45, 0.0)), &"steel_grey")
		blob_shadow(mb, base.origin, ob.radius)
	else:
		mb.box(Vector3(ob.size_x, 0.9, ob.size_z), base * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.45, 0.0)), &"steel_grey")
		blob_shadow_box(mb, base, Vector2(ob.size_x + 0.2, ob.size_z + 0.3))


## A flat dark quad (two stacked) under a box-shaped prop, leaning away from the key light.
static func blob_shadow_box(mb: MeshBuilder, base: Transform3D, size: Vector2) -> void:
	var lean: Transform3D = Transform3D(base.basis, base.origin + Vector3(0.14, SHADOW_LIFT, -0.1))
	mb.quad(size * 1.08, lean, &"shadow_blob")
	mb.quad(size * 0.84, Transform3D(lean.basis, lean.origin + Vector3(0.0, 0.002, 0.0)), &"shadow_blob")
