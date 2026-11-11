extends GdUnitTestSuite
## W3-C round 3: the hard-surface Warden has no hard edges where the camera can see them. Numeric bounds on the rounded box
## (the kit shape of the big plates), on the bevel box (zero shading crease since round 3) and on the finished meshes:
## the facet angle between neighbouring triangles on smooth-shaded edges, the shading crease, and the share of hard edges.

const STYLISED: int = LookDevStyle.Look.STYLISED
## Largest angle between the face normals of two triangles that share a smooth-shaded edge: a 6 sided tube has 60 degrees (the
## antenna and the cable), a 10 sided tube 36, the two facets of a rounded edge 45 and the corner of a rounded box about 55.
## (v4: the V chest plates are tilted 19 degrees on top of their chamfer facets, which is where the 66 comes from.)
const MAX_FACET_DEG: float = 68.0
## The same for an untapered rounded box (only its corner triangles reach 55).
const MAX_FACET_UNTAPERED_DEG: float = 56.0
## A taper adds its slope to the facet angles of the sides.
const MAX_FACET_TAPERED_DEG: float = 70.0
## A shading crease above this is a hard edge.
const CREASE_DEG: float = 20.0
## Share of the edges of the figure that may be hard: the flat caps of tubes, the hinge pins, the antenna and the cable, and in
## v4 the small boxes of the back-panel frame, the harness straps and the panel line (13 percent measured).
const MAX_HARD_SHARE: float = 0.15


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)


func _box(size: Vector3, radius: float, taper: Vector2 = Vector2.ONE, cuts: int = 0) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	LookDevRound.rounded_box(mb, size, Transform3D.IDENTITY, &"ceramic", radius, taper, cuts)
	return mb.build()


func test_rounded_box_triangle_counts_and_smooth_normals() -> void:
	for cuts: int in 2:
		var mb: MeshBuilder = MeshKit.begin()
		LookDevRound.rounded_box(mb, Vector3(0.6, 0.3, 0.4), Transform3D.IDENTITY, &"ceramic", 0.08, Vector2.ONE, cuts)
		assert_int(mb.triangle_count()).is_equal(LookDevRound.triangle_count(cuts))
	assert_int(LookDevRound.triangle_count(0)).is_equal(108)
	var m: ArrayMesh = _box(Vector3(0.6, 0.3, 0.4), 0.08)
	var arrays: Array = m.surface_get_arrays(0)
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for n: Vector3 in norms:
		assert_float(n.length()).is_equal_approx(1.0, 0.001)


func test_rounded_box_has_no_sharp_corner_and_no_shading_crease() -> void:
	var size: Vector3 = Vector3(0.6, 0.3, 0.4)
	for taper: Vector2 in [Vector2.ONE, Vector2(1.3, 1.1), Vector2(0.85, 0.8)]:
		var m: ArrayMesh = _box(size, 0.07, taper)
		var arrays: Array = m.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			var at_corner: bool = (
				absf(v.x) > size.x * 0.5 * maxf(taper.x, 1.0) - 0.001 and absf(v.y) > size.y * 0.5 - 0.001
				and absf(v.z) > size.z * 0.5 * maxf(taper.y, 1.0) - 0.001
			)
			assert_bool(at_corner).is_false()  # no vertex sits on a bare 90 degree corner
		var stats: Dictionary = LookDevTestKit.edge_stats(m, CREASE_DEG)
		assert_int(stats["hard"]).is_equal(0)
		assert_float(stats["max_crease"]).is_less(1.0)
		var limit: float = MAX_FACET_UNTAPERED_DEG if taper == Vector2.ONE else MAX_FACET_TAPERED_DEG
		assert_float(stats["max_facet_smooth"]).is_less(limit)
		assert_int(stats["edges"]).is_greater(100)


func test_bevel_box_has_a_chamfer_on_every_corner_and_no_crease_by_default() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	var size: Vector3 = Vector3(0.4, 0.2, 0.3)
	LookDevShapes.bevel_box(mb, size, Transform3D.IDENTITY, &"gunmetal", 0.03)
	var m: ArrayMesh = mb.build()
	var arrays: Array = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		var corner: bool = absf(v.x) > size.x * 0.5 - 0.001 and absf(v.y) > size.y * 0.5 - 0.001 and absf(v.z) > size.z * 0.5 - 0.001
		assert_bool(corner).is_false()
	var stats: Dictionary = LookDevTestKit.edge_stats(m, CREASE_DEG)
	assert_float(stats["max_crease"]).is_less(1.0)
	assert_float(stats["max_facet_smooth"]).is_less(MAX_FACET_DEG)


func test_the_styled_warden_has_few_hard_edges_and_none_sharper_than_the_bound_on_smooth_ones() -> void:
	var edges: int = 0
	var hard: int = 0
	for part: StringName in ActorMeshes.WARDEN_BODY_PARTS + ActorMeshes.WARDEN_WEAPONS:
		var m: ArrayMesh = ActorMeshes.warden_part(part, STYLISED)
		var stats: Dictionary = LookDevTestKit.edge_stats(m, CREASE_DEG)
		print("EDGES %s edges=%d hard=%d facet_smooth=%.1f crease=%.1f" % [part, stats["edges"], stats["hard"], stats["max_facet_smooth"], stats["max_crease"]])
		assert_float(stats["max_facet_smooth"]).is_less(MAX_FACET_DEG)
		var part_edges: int = stats["edges"]
		var part_hard: int = stats["hard"]
		edges += part_edges
		hard += part_hard
	var share: float = float(hard) / float(maxi(edges, 1))
	print("EDGES total edges=%d hard=%d share=%.3f" % [edges, hard, share])
	assert_float(share).is_less(MAX_HARD_SHARE)
