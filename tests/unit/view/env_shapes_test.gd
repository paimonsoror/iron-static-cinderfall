extends GdUnitTestSuite
## EnvShapes, EnvDecor and EnvProps geometry (W3-E): triangle counts of the new shapes, unit normals, vertex colours in range, the
## styled meshes are deterministic (two builds hash equal) and stay inside their triangle budgets.

const PAINT: StringName = EnvShapes.PAINT
const CONTAINER_BUDGET: int = 2200


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)


func _tris(mesh: ArrayMesh) -> int:
	var n: int = 0
	for s: int in mesh.get_surface_count():
		var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += floori(float(idx.size()) / 3.0)
	return n


func _container(kind: int, lit: bool) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	EnvDecor.container(mb, Transform3D.IDENTITY, kind, lit, 3)
	return EnvShapes.finish(mb)


func test_corrugated_wall_triangle_count_and_normals() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	var rows: Array[Color] = [Color(0.2, 0.1, 0.1, 0.0), Color(0.3, 0.2, 0.2, 0.0), Color(0.4, 0.3, 0.3, 0.0)]
	EnvShapes.corrugated(mb, PAINT, Transform3D.IDENTITY, 6.0, 2.0, 0.07, 10, PackedFloat32Array([0.0, 0.5, 2.0]), rows)
	assert_int(mb.triangle_count()).is_equal(10 * 4 * 2 * 2)
	var mesh: ArrayMesh = EnvShapes.finish(mb)
	var norms: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for n: Vector3 in norms:
		assert_float(n.length()).is_equal_approx(1.0, 0.001)
		assert_float(n.z).is_greater(0.0)  # every rib face looks out of the wall


func test_extrude_closes_the_profile() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	var profile: PackedVector2Array = PackedVector2Array([Vector2(-0.4, 0.0), Vector2(0.4, 0.0), Vector2(0.2, 0.9), Vector2(-0.2, 0.9)])
	EnvShapes.extrude(mb, PAINT, Transform3D.IDENTITY, profile, 3.0, Color(0.1, 0.1, 0.1, 0.0), Color(0.5, 0.5, 0.5, 0.0))
	assert_int(mb.triangle_count()).is_equal(4 * 2 + 4 * 2)  # 4 side quads and two fans of 4 triangles


func test_vertex_colours_stay_in_range_and_the_alpha_is_the_wear() -> void:
	for mesh: ArrayMesh in [_container(0, true), _container(2, false)]:
		for s: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			assert_int(cols.size()).is_equal((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			for c: Color in cols:
				assert_float(c.r).is_between(0.0, 1.0)
				assert_float(c.g).is_between(0.0, 1.0)
				assert_float(c.b).is_between(0.0, 1.0)
				assert_float(c.a).is_between(0.0, 1.0)


func test_a_container_is_deterministic_and_inside_its_budget() -> void:
	for kind: int in 4:
		var a: ArrayMesh = _container(kind, kind % 2 == 0)
		var b: ArrayMesh = _container(kind, kind % 2 == 0)
		assert_int(LookDevTestKit.mesh_hash(a)).is_equal(LookDevTestKit.mesh_hash(b))
		assert_int(_tris(a)).is_between(600, CONTAINER_BUDGET)


func test_container_variants_differ_in_colour_not_in_shape() -> void:
	var red: ArrayMesh = _container(0, false)
	var grey: ArrayMesh = _container(1, false)
	assert_int(_tris(red)).is_equal(_tris(grey))
	var rc: PackedColorArray = red.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var gc: PackedColorArray = grey.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_float(rc[0].r - rc[0].b).is_not_equal(gc[0].r - gc[0].b)


func test_the_container_keeps_the_old_footprint() -> void:
	var mesh: ArrayMesh = _container(0, true)
	var lo: Vector3 = Vector3(INF, INF, INF)
	var hi: Vector3 = Vector3(-INF, -INF, -INF)
	for s: int in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			if v.y > 0.05:  # the blob shadow lies on the ground and leans out of the box
				lo = lo.min(v)
				hi = hi.max(v)
	assert_float(hi.x - lo.x).is_between(DecorKit.CONTAINER_L - 0.1, DecorKit.CONTAINER_L + 0.3)
	assert_float(hi.z - lo.z).is_between(DecorKit.CONTAINER_W - 0.1, DecorKit.CONTAINER_W + 0.3)
	assert_float(hi.y).is_between(DecorKit.CONTAINER_H, DecorKit.CONTAINER_H + 0.2)


func test_the_styled_barrier_has_the_old_footprint_and_height() -> void:
	var ob: ObstacleDef = ObstacleDef.new()
	ob.shape = ObstacleDef.Shape.BOX
	ob.size_x = 3.2
	ob.size_z = 0.8
	ob.visual = &"jersey_barrier"
	var mb: MeshBuilder = MeshKit.begin()
	EnvProps.add_obstacle(mb, ob)
	var mesh: ArrayMesh = EnvShapes.finish(mb)
	var hi: Vector3 = Vector3(-INF, -INF, -INF)
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_name(s) == "shadow_blob":
			continue
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			hi = hi.max(v)
	assert_float(hi.x).is_less_equal(1.6 + 0.01)
	assert_float(hi.z).is_less_equal(0.4 + 0.01)
	assert_float(hi.y).is_between(0.9, 1.0)
