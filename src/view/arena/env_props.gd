class_name EnvProps
extends RefCounted
## The in-play props of the gritty yard (W3-E): the styled twins of PropKit (jersey barrier, crate stack, drum cluster). Same obstacle
## data, same placement and the same footprint as PropKit (the sim and arena.json decide where they stand and how big they are; this only
## changes how they look), built with the hard-surface kit (bevelled forms, baked colour and wear) into ONE mesh. Nothing is added in the
## walk lanes: every vertex stays inside the obstacle's footprint plus the blob shadow's lean.

const PAINT: StringName = EnvShapes.PAINT


## Adds the styled visual of one obstacle (unknown visuals fall back to PropKit's grey primitive).
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
			PropKit.add_obstacle(mb, ob)


## A jersey barrier: the real sloped profile (a wide foot, a long slope, a narrow top), dirty at the foot, with red hazard stripes
## on both slopes and two lifting pockets. The footprint is the obstacle's size_x by size_z.
static func _barrier(mb: MeshBuilder, base: Transform3D, ob: ObstacleDef) -> void:
	var k: float = ob.size_z / 0.8
	var len: float = ob.size_x
	var profile: PackedVector2Array = PackedVector2Array([
		Vector2(-0.4 * k, 0.0), Vector2(0.4 * k, 0.0), Vector2(0.4 * k, 0.13), Vector2(0.26 * k, 0.42),
		Vector2(0.17 * k, 0.95), Vector2(-0.17 * k, 0.95), Vector2(-0.26 * k, 0.42), Vector2(-0.4 * k, 0.13),
	])
	EnvShapes.extrude(mb, PAINT, base, profile, len, EnvShapes.paint(&"concrete_light", 0.42), EnvShapes.paint(&"concrete_light", 1.12))
	var red: Color = EnvShapes.paint(&"steel_red", 1.15)
	var stripes: int = maxi(3, floori((len - 0.5) / 0.55))
	var pitch: float = (len - 0.5) / float(stripes)
	for i: int in stripes:
		if i % 2 != 0:
			continue
		var x0: float = -len * 0.5 + 0.25 + pitch * float(i)
		for s: float in [1.0, -1.0]:
			var nrm: Vector3 = Vector3(0.0, 0.09 * k, s * 0.53).normalized()
			var lift: Vector3 = nrm * 0.012
			var a: Vector3 = Vector3(x0, 0.45, s * 0.255 * k) + lift
			var b: Vector3 = Vector3(x0 + pitch * 0.55, 0.45, s * 0.255 * k) + lift
			var c: Vector3 = Vector3(x0 + pitch * 0.55 + 0.3, 0.93, s * 0.172 * k) + lift
			var d: Vector3 = Vector3(x0 + 0.3, 0.93, s * 0.172 * k) + lift
			EnvShapes.flat(mb, PAINT, base, a, b, c, d, nrm, red)
	var dark: Color = EnvShapes.paint(&"rubber", 0.9)
	for px: float in [-0.36, 0.36]:
		_box(mb, base, Vector3(px * len, 0.95, 0.0), Vector3(0.2, 0.03, 0.12 * k), dark, 0.008)
	PropKit.blob_shadow_box(mb, base, Vector2(len + 0.2, ob.size_z + 0.3))


## Three crates and one on top, on PropKit's plan: bevelled dark crates with a lid, corner posts, a strap and a lit handle.
static func _crates(mb: MeshBuilder, base: Transform3D, ob: ObstacleDef) -> void:
	var s: float = ob.radius / 1.3
	var plan: Array[Vector4] = [
		Vector4(-0.45, 0.2, 1.0, 10.0), Vector4(0.55, 0.25, 1.0, -6.0), Vector4(0.1, -0.75, 0.8, 25.0),
	]
	var i: int = 0
	for c: Vector4 in plan:
		crate(mb, _at(base, Vector3(c.x * s, 0.0, c.y * s), c.w), c.z * s, i)
		i += 1
	crate(mb, _at(base, Vector3(-0.4 * s, 1.0 * s, 0.2 * s), 14.0), 0.9 * s, 3)
	PropKit.blob_shadow(mb, base.origin, ob.radius * 0.95)


static func crate(mb: MeshBuilder, t: Transform3D, size: float, index: int) -> void:
	var h: float = size
	var body: Color = EnvShapes.paint(&"dark_frame", 0.8 + 0.08 * float(index % 3))
	var steel: Color = EnvShapes.paint(&"gunmetal", 0.62)
	_box(mb, t, Vector3(0.0, h * 0.5, 0.0), Vector3(size, h, size), body, 0.04)
	_box(mb, t, Vector3(0.0, h + 0.02, 0.0), Vector3(size * 0.94, 0.05, size * 0.94), steel, 0.015)
	var post: float = 0.12 * size
	for ix: int in 2:
		for iz: int in 2:
			var px: float = (float(ix) - 0.5) * (size - post * 0.3)
			var pz: float = (float(iz) - 0.5) * (size - post * 0.3)
			_box(mb, t, Vector3(px, h * 0.5, pz), Vector3(post, h * 1.02, post), steel, 0.02)
	for side: float in [1.0, -1.0]:
		_box(mb, t, Vector3(0.0, h * 0.5, side * (size * 0.5 + 0.012)), Vector3(size * 0.86, 0.1 * size, 0.03), steel, 0.01)
		_box(mb, t, Vector3(side * (size * 0.5 + 0.012), h * 0.5, 0.0), Vector3(0.03, 0.1 * size, size * 0.86), steel, 0.01)
	var plate: Color = EnvShapes.paint(&"hazard", 0.85)
	_box(mb, t, Vector3(0.0, h * 0.72, size * 0.5 + 0.03), Vector3(size * 0.3, size * 0.16, 0.03), plate, 0.008)
	if index % 2 == 0:
		mb.tint = Color.WHITE
		mb.box(Vector3(size * 0.34, 0.05, 0.03), t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.28, size * 0.5 + 0.03)), EnvShapes.AMBER)


## Five drums on PropKit's plan: two-tone barrels (a rustier foot), chime rings, a lid with a bung, one with a hazard band.
static func _drums(mb: MeshBuilder, base: Transform3D, ob: ObstacleDef) -> void:
	var s: float = ob.radius
	var spots: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.64, 0.12), Vector2(-0.55, 0.42), Vector2(0.1, -0.66), Vector2(-0.4, -0.5)]
	var kinds: Array[StringName] = [&"steel_red", &"steel_grey", &"steel_red", &"dark_frame", &"steel_grey"]
	for i: int in spots.size():
		var t: Transform3D = base * Transform3D(Basis(Vector3.UP, float(i) * 1.3), Vector3(spots[i].x * s, 0.0, spots[i].y * s))
		var col: Color = EnvShapes.paint(kinds[i], 1.0)
		var foot: Color = EnvShapes.paint(kinds[i], 0.6)
		mb.tint = foot
		mb.cylinder(0.3, 0.3, 0.34, 12, t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.17, 0.0)), PAINT)
		mb.tint = col
		mb.cylinder(0.3, 0.3, 0.56, 12, t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.62, 0.0)), PAINT)
		mb.tint = EnvShapes.paint(&"gunmetal", 0.7)
		for ry: float in [0.04, 0.34, 0.9, 0.52, 0.78]:
			mb.cylinder(0.318, 0.318, 0.05, 12, t * Transform3D(Basis.IDENTITY, Vector3(0.0, ry, 0.0)), PAINT)
		mb.cylinder(0.24, 0.24, 0.03, 12, t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.915, 0.0)), PAINT)
		mb.tint = EnvShapes.paint(&"rubber", 1.0)
		mb.cylinder(0.05, 0.05, 0.05, 8, t * Transform3D(Basis.IDENTITY, Vector3(0.12, 0.94, 0.06)), PAINT)
		if i == 1:
			mb.tint = EnvShapes.paint(&"hazard", 0.9)
			mb.cylinder(0.322, 0.322, 0.14, 12, t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.62, 0.0)), PAINT)
	mb.tint = Color.WHITE
	PropKit.blob_shadow(mb, base.origin, ob.radius * 0.95)


static func _box(mb: MeshBuilder, t: Transform3D, at: Vector3, size: Vector3, col: Color, bevel: float) -> void:
	mb.tint = col
	LookDevShapes.bevel_box(mb, size, t * Transform3D(Basis.IDENTITY, at), PAINT, bevel)


static func _at(base: Transform3D, local_pos: Vector3, local_yaw_deg: float = 0.0) -> Transform3D:
	return base * Transform3D(Basis(Vector3.UP, deg_to_rad(local_yaw_deg)), local_pos)
