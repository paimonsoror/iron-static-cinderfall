extends GdUnitTestSuite
## MeshBuilder: primitives merge into ONE ArrayMesh with one surface per distinct material, outward winding, UVs.

const ID: Transform3D = Transform3D.IDENTITY


func _at(x: float, y: float = 0.0, z: float = 0.0) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


func _arrays(mesh: ArrayMesh, surface: int) -> Array:
	return mesh.surface_get_arrays(surface)


func test_n_primitives_merge_into_one_mesh_with_one_surface_per_material() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	for i: int in 6:
		mb.box(Vector3.ONE, _at(float(i) * 2.0), &"gunmetal")
	for i: int in 3:
		mb.cylinder(0.5, 0.5, 1.0, 8, _at(float(i) * 2.0, 0.0, 4.0), &"steel_red")
	mb.prism(Vector3(1.0, 1.0, 2.0), _at(0.0, 0.0, 8.0), &"gunmetal")
	mb.sphere(0.5, 8, _at(0.0, 2.0, 0.0), &"emit_cyan")
	mb.quad(Vector2(2.0, 2.0), _at(0.0, 0.0, -4.0), &"concrete")
	mb.ring(1.0, 1.5, 12, _at(0.0, 0.1, 0.0), &"hazard")
	mb.disc(1.0, 12, _at(0.0, 0.1, 6.0), &"shadow_blob")
	var mesh: ArrayMesh = mb.build()
	# gunmetal (boxes + prism), steel_red, emit_cyan, concrete, hazard, shadow_blob.
	assert_int(mesh.get_surface_count()).is_equal(6)
	assert_object(mesh.surface_get_material(0)).is_same(MatLib.mat(&"gunmetal"))
	assert_object(mesh.surface_get_material(1)).is_same(MatLib.mat(&"steel_red"))
	assert_object(mesh.surface_get_material(2)).is_same(MatLib.mat(&"emit_cyan"))
	# Boxes: 12 triangles each; prism: 8.
	var gun_idx: PackedInt32Array = _arrays(mesh, 0)[Mesh.ARRAY_INDEX]
	assert_int(gun_idx.size()).is_equal((6 * 12 + 8) * 3)


func test_triangle_count_matches_the_built_mesh() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3.ONE, ID, &"ceramic").cylinder(1.0, 1.0, 1.0, 10, ID, &"ceramic").sphere(1.0, 8, ID, &"rubber")
	mb.quad(Vector2.ONE, ID, &"concrete")
	var expected: int = mb.triangle_count()
	var mesh: ArrayMesh = mb.build()
	var total: int = 0
	for s: int in mesh.get_surface_count():
		var idx: PackedInt32Array = _arrays(mesh, s)[Mesh.ARRAY_INDEX]
		total += floori(float(idx.size()) / 3.0)
	assert_int(total).is_equal(expected)
	assert_int(expected).is_greater(40)


func test_box_triangles_face_outward() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(2.0, 3.0, 4.0), ID, &"ceramic")
	var arr: Array = _arrays(mb.build(), 0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t: int in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[t]]
		var b: Vector3 = verts[idx[t + 1]]
		var c: Vector3 = verts[idx[t + 2]]
		# Godot front faces are clockwise: the geometric normal of (a, b, c) must point INTO the box.
		var n: Vector3 = (b - a).cross(c - a)
		var centroid: Vector3 = (a + b + c) / 3.0
		assert_float(n.dot(centroid)).is_less(0.0)


func test_flat_primitives_face_up_and_carry_uvs() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	mb.quad(Vector2(2.0, 4.0), ID, &"concrete").ring(1.0, 2.0, 8, ID, &"hazard").disc(1.5, 8, ID, &"shadow_blob")
	var mesh: ArrayMesh = mb.build()
	for s: int in mesh.get_surface_count():
		var arr: Array = _arrays(mesh, s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		assert_int(uvs.size()).is_equal(verts.size())
		for n: Vector3 in norms:
			assert_vector(n).is_equal_approx(Vector3.UP, Vector3(0.001, 0.001, 0.001))
	# quad UVs span 0..1.
	var quad_uvs: PackedVector2Array = _arrays(mesh, 0)[Mesh.ARRAY_TEX_UV]
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for uv: Vector2 in quad_uvs:
		lo = Vector2(minf(lo.x, uv.x), minf(lo.y, uv.y))
		hi = Vector2(maxf(hi.x, uv.x), maxf(hi.y, uv.y))
	assert_vector(lo).is_equal_approx(Vector2.ZERO, Vector2(0.001, 0.001))
	assert_vector(hi).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))


func test_ring_stays_between_its_radii() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	mb.ring(1.2, 1.8, 24, _at(5.0, 0.0, 5.0), &"emit_cyan")
	var verts: PackedVector3Array = _arrays(mb.build(), 0)[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		var r: float = Vector2(v.x - 5.0, v.z - 5.0).length()
		assert_float(r).is_between(1.2 - 0.0001, 1.8 + 0.0001)
