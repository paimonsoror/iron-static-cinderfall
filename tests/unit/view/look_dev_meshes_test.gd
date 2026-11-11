extends GdUnitTestSuite
## W3-C hard-surface Warden meshes: the 2500 triangle budget (v3), at most 3 surfaces per mesh, CURRENT byte-identical to the
## pre-change meshes, baked vertex colours in range, palette roles, the new kit shapes.

const STYLISED_LOOKS: Array[int] = [LookDevStyle.Look.STYLISED, LookDevStyle.Look.STYLISED_PLUS]
## Pre-change CURRENT meshes: triangles, vertices, surfaces and an FNV-1a hash of material names, vertices, normals and indices.
const BASELINE: Dictionary[String, Array] = {
	"warden_legs": [120, 360, 3, 6815680896501409233],
	"warden_torso": [192, 576, 3, 2569698867509568039],
	"pistol": [48, 144, 3, 291998507563273517],
	"smg": [72, 216, 3, 610505221726740717],
	"turret": [176, 528, 3, 308404756728313382],
	"turret_base": [96, 288, 1, 3425167843006112341],
	"turret_head": [80, 240, 3, 8593690147155910097],
	"skitter": [240, 720, 3, 1912435234558808253],
	"hollow_warden": [264, 792, 3, 3461412639251264139],
	"rusher": [284, 852, 3, 2606849488968514826],
	"siege_hulk": [496, 1488, 3, 2354974199534980569],
}


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)


func _mesh_of(key: String) -> ArrayMesh:
	match key:
		"warden_legs":
			return ActorMeshes.warden_legs()
		"warden_torso":
			return ActorMeshes.warden_torso()
		"pistol":
			return ActorMeshes.pistol()
		"smg":
			return ActorMeshes.smg()
		"turret":
			return ActorMeshes.turret()
		"turret_base":
			return ActorMeshes.turret_base()
		"turret_head":
			return ActorMeshes.turret_head()
	return ActorMeshes.enemy(StringName(key))


func _roles(mesh: ArrayMesh) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: int in mesh.get_surface_count():
		out.append(StringName(mesh.surface_get_material(s).resource_name))
	return out


func _all_parts(look: int) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	for part: StringName in ActorMeshes.WARDEN_BODY_PARTS + ActorMeshes.WARDEN_WEAPONS:
		out.append(ActorMeshes.warden_part(part, look))
	return out


func test_current_look_meshes_are_byte_identical_to_the_pre_change_ones() -> void:
	for key: String in BASELINE:
		var m: ArrayMesh = _mesh_of(key)
		var want: Array = BASELINE[key]
		assert_int(ActorMeshes.triangle_count(m)).is_equal(want[0])
		assert_int(LookDevTestKit.vertex_count(m)).is_equal(want[1])
		assert_int(m.get_surface_count()).is_equal(want[2])
		assert_int(LookDevTestKit.mesh_hash(m)).is_equal(want[3])
		for s: int in m.get_surface_count():
			var arrays: Array = m.surface_get_arrays(s)
			assert_bool(arrays[Mesh.ARRAY_COLOR] == null).is_true()  # CURRENT carries no vertex colors


func test_current_parts_resolve_to_the_old_meshes_and_have_no_extras() -> void:
	var c: int = LookDevStyle.Look.CURRENT
	assert_object(ActorMeshes.warden_part(&"legs", c)).is_same(ActorMeshes.warden_legs())
	assert_object(ActorMeshes.warden_part(&"torso", c)).is_same(ActorMeshes.warden_torso())
	assert_object(ActorMeshes.warden_part(&"pistol", c)).is_same(ActorMeshes.pistol())
	assert_object(ActorMeshes.warden_part(&"smg", c)).is_same(ActorMeshes.smg())
	for part: StringName in [&"arm_ru", &"arm_rf", &"arm_lu", &"arm_lf", &"pack", &"antenna", &"cable"]:
		assert_object(ActorMeshes.warden_part(part, c)).is_null()
	assert_int(ActorMeshes.warden_triangles(c, 0)).is_equal(120 + 192 + 48)


func test_the_warden_budget_is_twenty_five_hundred_and_every_styled_loadout_fits() -> void:
	assert_int(ActorMeshes.TRI_BUDGET[&"warden"]).is_equal(2500)
	for part: StringName in ActorMeshes.WARDEN_BODY_PARTS + ActorMeshes.WARDEN_WEAPONS:
		print("WARDEN_PART %s tris=%d" % [part, ActorMeshes.triangle_count(ActorMeshes.warden_part(part, LookDevStyle.Look.STYLISED))])
	for look: int in STYLISED_LOOKS:
		for weapon: int in 2:
			var n: int = ActorMeshes.warden_triangles(look, weapon)
			print("WARDEN_TRIS look=%s weapon=%d tris=%d" % [LookDevStyle.name_of(look), weapon, n])
			assert_int(n).is_between(1500, ActorMeshes.TRI_BUDGET[&"warden"])
	# the other actors keep their budgets
	assert_int(ActorMeshes.TRI_BUDGET[&"skitter"]).is_equal(300)
	assert_int(ActorMeshes.TRI_BUDGET[&"siege_hulk"]).is_equal(900)
	assert_int(ActorMeshes.TRI_BUDGET[&"turret"]).is_equal(300)


func test_every_styled_part_has_at_most_three_surfaces_and_the_palette_roles() -> void:
	for look: int in STYLISED_LOOKS:
		for m: ArrayMesh in _all_parts(look):
			assert_int(m.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
			for role: StringName in _roles(m):
				assert_bool([&"ceramic", &"gunmetal", &"emit_cyan"].has(role)).is_true()


func test_the_styled_warden_is_cyan_and_never_red() -> void:
	for look: int in STYLISED_LOOKS:
		var cyan_parts: int = 0
		for m: ArrayMesh in _all_parts(look):
			var roles: Array[StringName] = _roles(m)
			assert_bool(roles.has(&"emit_red")).is_false()
			assert_bool(roles.has(&"steel_red")).is_false()
			if roles.has(&"emit_cyan"):
				cyan_parts += 1
		# visor and chest bar (torso), shoulder lights, belt (legs), pack bars, antenna tip, weapon strips
		assert_int(cyan_parts).is_greater_equal(5)
		assert_bool(_roles(ActorMeshes.warden_part(&"torso", look)).has(&"emit_cyan")).is_true()


func test_styled_warden_is_about_one_point_nine_meters_tall_and_stands_on_the_ground() -> void:
	var top: float = ActorMeshes.warden_part(&"torso", LookDevStyle.Look.STYLISED).get_aabb().end.y + HeroMeshes.WARDEN_WAIST_Y
	var antenna_top: float = ActorMeshes.warden_part(&"antenna", LookDevStyle.Look.STYLISED).get_aabb().end.y
	assert_float(top).is_between(1.8, 1.95)
	assert_float(antenna_top + LookDevWarden.ANTENNA_PIVOT.y + HeroMeshes.WARDEN_WAIST_Y).is_less(2.06)
	var low: float = ActorMeshes.warden_part(&"legs", LookDevStyle.Look.STYLISED).get_aabb().position.y
	assert_float(low).is_between(-0.02, 0.02)
	var width: float = ActorMeshes.warden_part(&"torso", LookDevStyle.Look.STYLISED).get_aabb().size.x
	assert_float(width).is_greater_equal(1.0)  # strong shoulders


func test_baked_vertex_colours_are_present_in_range_and_darken_the_creases() -> void:
	for look: int in STYLISED_LOOKS:
		for m: ArrayMesh in _all_parts(look):
			for s: int in m.get_surface_count():
				var arrays: Array = m.surface_get_arrays(s)
				var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				assert_int(cols.size()).is_equal(verts.size())
				var role: StringName = StringName(m.surface_get_material(s).resource_name)
				for c: Color in cols:
					assert_float(c.r).is_between(0.0, 1.0)
					assert_float(c.g).is_between(0.0, 1.0)
					assert_float(c.b).is_between(0.0, 1.0)
					assert_float(c.a).is_between(0.0, 1.0)
					if role == &"emit_cyan":
						assert_that(Vector3(c.r, c.g, c.b)).is_equal(Vector3.ONE)  # accents are not occluded
	var gun: Array = ActorMeshes.warden_part(&"torso", LookDevStyle.Look.STYLISED).surface_get_arrays(0)
	var gun_cols: PackedColorArray = gun[Mesh.ARRAY_COLOR]
	var lo: float = 1.0
	var hi: float = 0.0
	for c2: Color in gun_cols:
		lo = minf(lo, c2.r)
		hi = maxf(hi, c2.r)
	assert_float(hi - lo).is_greater(0.12)  # not flat: there is occlusion and tint variation


func test_wear_alpha_marks_the_chamfers_only() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	LookDevShapes.bevel_box(mb, Vector3(0.4, 0.3, 0.2), Transform3D.IDENTITY, &"ceramic", 0.03)
	LookDevBake.ao(mb)
	var s: MeshBuilder.Surf = mb.surface_of(&"ceramic")
	var worn: int = 0
	var clean: int = 0
	for c: Color in s.cols:
		if c.a > 0.5:
			worn += 1
		else:
			clean += 1
	assert_int(worn).is_equal(96)  # 12 strips (24 triangles) and 8 corners (8) = 32 triangles
	assert_int(clean).is_equal(36)  # the six face quads


func test_bake_is_deterministic() -> void:
	var a: ArrayMesh = LookDevWarden.torso()
	var b: ArrayMesh = LookDevWarden.torso()
	assert_int(LookDevTestKit.mesh_hash(a)).is_equal(LookDevTestKit.mesh_hash(b))
	var ca: PackedColorArray = a.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var cb: PackedColorArray = b.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_bool(ca == cb).is_true()


func test_bevel_box_counts_normals_and_outward_winding() -> void:
	var closed: MeshBuilder = MeshKit.begin()
	LookDevShapes.bevel_box(closed, Vector3(1.0, 2.0, 3.0), Transform3D.IDENTITY, &"ceramic", 0.1)
	assert_int(closed.triangle_count()).is_equal(44)
	var open: MeshBuilder = MeshKit.begin()
	LookDevShapes.bevel_box(open, Vector3.ONE, Transform3D.IDENTITY, &"ceramic", 0.1, Vector2(0.5, 0.5), 0.5, false)
	assert_int(open.triangle_count()).is_equal(36)
	var arrays: Array = closed.build().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t: int in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[t]]
		var b: Vector3 = verts[idx[t + 1]]
		var c: Vector3 = verts[idx[t + 2]]
		var face: Vector3 = (b - a).cross(c - a).normalized()
		var centre: Vector3 = (a + b + c) / 3.0
		assert_float(face.dot(centre.normalized())).is_less(0.0)  # Godot front faces are clockwise: the normal points inward
	for n: Vector3 in norms:
		assert_float(n.length()).is_equal_approx(1.0, 0.001)


func test_limb_ellipsoid_and_plate_triangle_counts() -> void:
	var flat: MeshBuilder = MeshKit.begin()
	LookDevShapes.limb(flat, Vector3.ZERO, Vector3(0.0, 1.0, 0.0), 0.2, 0.1, 8, &"gunmetal")
	assert_int(flat.triangle_count()).is_equal(16 + 16)  # body and two caps
	var open: MeshBuilder = MeshKit.begin()
	LookDevShapes.limb(open, Vector3.ZERO, Vector3(0.0, 1.0, 0.0), 0.2, 0.1, 8, &"gunmetal", Transform3D.IDENTITY, 0, false, false)
	assert_int(open.triangle_count()).is_equal(16)
	var round: MeshBuilder = MeshKit.begin()
	LookDevShapes.limb(round, Vector3.ZERO, Vector3(0.0, 1.0, 0.0), 0.2, 0.1, 8, &"gunmetal", Transform3D.IDENTITY, 1)
	assert_int(round.triangle_count()).is_equal(8 * 8)  # per facet: body 2, a band 2 and a fan 1 at each end
	var dome: MeshBuilder = MeshKit.begin()
	LookDevShapes.ellipsoid(dome, Vector3(0.2, 0.1, 0.2), 10, 2, Transform3D.IDENTITY, &"ceramic", true)
	assert_int(dome.triangle_count()).is_equal(10 + 20)
	var ball: MeshBuilder = MeshKit.begin()
	LookDevShapes.ellipsoid(ball, Vector3(0.2, 0.1, 0.2), 10, 2, Transform3D.IDENTITY, &"ceramic", false)
	assert_int(ball.triangle_count()).is_equal(60)
	var plate: MeshBuilder = MeshKit.begin()
	LookDevShapes.curved_plate(plate, 0.4, 0.2, 0.04, 1.0, 5, Transform3D.IDENTITY, &"ceramic")
	assert_int(plate.triangle_count()).is_equal(6 * 5 + 4)


func test_limb_normals_are_smooth_and_point_outward() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	LookDevShapes.limb(mb, Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 0.2, 0.1, 12, &"gunmetal", Transform3D.IDENTITY, 1)
	var arrays: Array = mb.build().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i: int in verts.size():
		var radial: Vector3 = Vector3(0.0, verts[i].y, verts[i].z)
		if radial.length() > 0.05:
			assert_float(norms[i].dot(radial.normalized())).is_greater(0.0)


func test_gradient_stays_in_range_and_follows_height() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	LookDevShapes.bevel_box(mb, Vector3(0.2, 1.0, 0.2), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0)), &"ceramic", 0.02)
	LookDevBake.gradient_y(mb, 0.0, 1.0, 0.4, 1.0)
	var s: MeshBuilder.Surf = mb.surface_of(&"ceramic")
	for i: int in s.verts.size():
		var want: float = lerpf(0.4, 1.0, clampf(s.verts[i].y, 0.0, 1.0))
		assert_float(s.cols[i].r).is_equal_approx(want, 0.001)
		assert_float(s.cols[i].r).is_between(0.0, 1.0)


func test_bevel_plate_is_a_thirty_triangle_shell_without_a_bottom() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	LookDevShapes.bevel_box(mb, Vector3(0.3, 0.05, 0.2), Transform3D.IDENTITY, &"ceramic", 0.015, Vector2.ONE, 0.55, true, true)
	assert_int(mb.triangle_count()).is_equal(30)
	var s: MeshBuilder.Surf = mb.surface_of(&"ceramic")
	for i: int in s.verts.size():
		assert_float(s.norms[i].y).is_greater(-0.01)  # nothing faces down: the plate sits on the body
		assert_float(s.norms[i].length()).is_equal_approx(1.0, 0.001)


func test_round_parts_have_smooth_normals_and_plates_keep_hard_ones() -> void:
	var round: MeshBuilder = MeshKit.begin()
	LookDevShapes.ellipsoid(round, Vector3(0.15, 0.16, 0.18), 12, 3, Transform3D.IDENTITY, &"gunmetal")
	LookDevShapes.limb(round, Vector3.ZERO, Vector3(0.0, 0.4, 0.0), 0.1, 0.08, 10, &"gunmetal")
	var seen: Dictionary[Vector3i, Vector3] = {}
	var s: MeshBuilder.Surf = round.surface_of(&"gunmetal")
	var smooth: int = 0
	for i: int in s.verts.size():
		var key: Vector3i = Vector3i(roundi(s.verts[i].x * 1000.0), roundi(s.verts[i].y * 1000.0), roundi(s.verts[i].z * 1000.0))
		if seen.has(key):
			var other: Vector3 = seen[key]
			if absf(s.verts[i].y) < 0.1499 and absf(absf(s.verts[i].y) - 0.0) > 0.0 and s.norms[i].dot(other) > 0.999:
				smooth += 1
		else:
			seen[key] = s.norms[i]
	assert_int(smooth).is_greater(100)  # shared vertices carry one normal: no facets
	var plate: MeshBuilder = MeshKit.begin()
	LookDevShapes.bevel_box(plate, Vector3(0.3, 0.05, 0.2), Transform3D.IDENTITY, &"ceramic", 0.015, Vector2.ONE, 0.55, true, true)
	var ps: MeshBuilder.Surf = plate.surface_of(&"ceramic")
	var flat_up: int = 0
	for n: Vector3 in ps.norms:
		if n.is_equal_approx(Vector3.UP):
			flat_up += 1
	assert_int(flat_up).is_equal(6)  # the top face is one flat quad


func test_the_suit_is_dark_and_bone_is_limited_to_a_few_plates() -> void:
	var total: int = 0
	var bone: int = 0
	var dark_sum: float = 0.0
	var dark_n: int = 0
	for look: int in STYLISED_LOOKS:
		for part: StringName in ActorMeshes.WARDEN_BODY_PARTS:
			var m: ArrayMesh = ActorMeshes.warden_part(part, look)
			for s: int in m.get_surface_count():
				var arrays: Array = m.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var tris: int = floori(float(idx.size()) / 3.0)
				var role: StringName = StringName(m.surface_get_material(s).resource_name)
				total += tris
				if role == &"ceramic":
					bone += tris
				elif role == &"gunmetal":
					for c: Color in cols:
						dark_sum += (c.r + c.g + c.b) / 3.0
						dark_n += 1
	assert_float(float(bone) / float(total)).is_less(0.15)  # bone only on the chest, one pauldron, the shins, the pack top, the crest
	assert_float(dark_sum / float(dark_n)).is_less(0.8)  # the metal is a dark suit and mid steel, nothing near white
