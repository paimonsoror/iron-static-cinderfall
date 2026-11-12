extends GdUnitTestSuite
## The gritty yard on the real ArenaView (W3-E): CURRENT stays today's yard (the meshes are pinned by hash, the originals come back
## after a styled round trip), the styled yard swaps the floor, the props and the extras by tier, nothing grows when the look is switched
## 50 times, every prop keeps its footprint from arena.json, the decor keeps its layout, and the boot warm-up covers the new materials.

const CUR: int = LookDevStyle.Look.CURRENT
const STY: int = LookDevStyle.Look.STYLISED
const PLUS: int = LookDevStyle.Look.STYLISED_PLUS
const LOW: int = VisualQuality.Tier.LOW
const MID: int = VisualQuality.Tier.MID
const HIGH: int = VisualQuality.Tier.HIGH

## CURRENT meshes (frozen test data): [triangles, vertices, surfaces, hash]. Captured before the yard was touched.
const BASELINE: Dictionary = {
	"Props": [1176, 3528, 7, 379269399334091268],
	"Decor": [8988, 26964, 8, 4477944753274186995],
	"LampHeads": [72, 216, 1, 1323165105703961554],
}

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()
	MatLib.configure(_content.tokens)
	LookDevStyle.set_current(CUR)
	EnvStyle.set_override("")


func after_test() -> void:
	LookDevStyle.set_current(CUR)
	EnvStyle.set_override("")


func _view(look: int, tier: int = MID) -> ArenaView:
	LookDevStyle.set_current(look)
	var v: ArenaView = auto_free(ArenaView.new())
	v.setup(_content.arena, _content.tokens)
	v.set_quality(tier)
	return v


func _mesh_of(v: ArenaView, node_name: String) -> ArrayMesh:
	var mi: MeshInstance3D = v.get_node(node_name)
	var m: ArrayMesh = mi.mesh as ArrayMesh
	return m


func _tris(mesh: ArrayMesh) -> int:
	var n: int = 0
	for s: int in mesh.get_surface_count():
		var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += floori(float(idx.size()) / 3.0)
	return n


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for s: int in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		out.append_array(verts)
	return out


func _visible3d(v: ArenaView, node_name: String) -> bool:
	var n: Node3D = v.get_node_or_null(node_name) as Node3D
	return n != null and n.visible


func _visible_layer(v: ArenaView, node_name: String) -> bool:
	var n: CanvasLayer = v.get_node_or_null(node_name) as CanvasLayer
	return n != null and n.visible


func _ground_param(v: ArenaView, key: StringName) -> Variant:
	var m: ShaderMaterial = (v.get_node("Ground") as MeshInstance3D).material_override as ShaderMaterial
	return m.get_shader_parameter(key)


func test_current_yard_meshes_are_pinned() -> void:
	var v: ArenaView = _view(CUR)
	for node_name: String in BASELINE.keys():
		var mesh: ArrayMesh = _mesh_of(v, node_name)
		var want: Array = BASELINE[node_name]
		var got: Array = [_tris(mesh), LookDevTestKit.vertex_count(mesh), mesh.get_surface_count(), LookDevTestKit.mesh_hash(mesh)]
		assert_array(got).override_failure_message("%s is %s" % [node_name, str(got)]).is_equal(want)
		assert_bool(mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR != 0).is_false()


func test_current_has_no_styled_extras() -> void:
	var v: ArenaView = _view(CUR, HIGH)
	assert_object((v.get_node("Ground") as MeshInstance3D).material_override).is_same(v._ground_mat)
	assert_bool(_visible3d(v, "EnvSpill")).is_false()
	var env: Environment = v.environment_node.environment
	assert_int(env.tonemap_mode).is_equal(Environment.TONE_MAPPER_LINEAR)
	assert_bool(env.adjustment_enabled).is_false()
	assert_bool(env.glow_enabled).is_false()
	assert_float(v.lamp_gain).is_equal(1.0)
	assert_float(v.core.gain).is_equal(1.0)


func test_a_styled_round_trip_restores_the_original_references() -> void:
	var v: ArenaView = _view(CUR)
	var before: Array[Mesh] = [(v.get_node("Props") as MeshInstance3D).mesh, (v.get_node("Decor") as MeshInstance3D).mesh]
	var ground: Material = (v.get_node("Ground") as MeshInstance3D).material_override
	v.set_look(STY)
	assert_object((v.get_node("Ground") as MeshInstance3D).material_override).is_not_same(ground)
	assert_object((v.get_node("Props") as MeshInstance3D).mesh).is_not_same(before[0])
	v.set_look(CUR)
	assert_object((v.get_node("Ground") as MeshInstance3D).material_override).is_same(ground)
	assert_object((v.get_node("Props") as MeshInstance3D).mesh).is_same(before[0])
	assert_object((v.get_node("Decor") as MeshInstance3D).mesh).is_same(before[1])
	assert_int(v.environment_node.environment.tonemap_mode).is_equal(Environment.TONE_MAPPER_LINEAR)
	assert_bool(_visible3d(v, "EnvSpill")).is_false()
	assert_float(v.lamp_gain).is_equal(1.0)


func test_styled_swaps_the_floor_the_props_and_the_decor() -> void:
	var v: ArenaView = _view(STY, MID)
	var ground: ShaderMaterial = (v.get_node("Ground") as MeshInstance3D).material_override as ShaderMaterial
	assert_object(ground.shader).is_same(EnvGround.shader())
	assert_object(ground.get_shader_parameter(&"floor_tex")).is_same(EnvTex.texture())
	for node_name: String in ["Props", "Decor"]:
		var mesh: ArrayMesh = _mesh_of(v, node_name)
		assert_int(mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR).is_not_equal(0)
		for s: int in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(s)
			var known: bool = m == EnvMat.prop(true) or m == EnvMat.prop(false) or m == MatLib.mat(&"shadow_blob")
			known = known or m == EnvMat.emit(&"amber", EnvStyle.WINDOW_GAIN) or m == EnvMat.emit(&"cyan", EnvStyle.WINDOW_GAIN)
			assert_bool(known).override_failure_message("%s surface %d has an unknown material" % [node_name, s]).is_true()


func test_floor_and_props_follow_the_tier() -> void:
	var v: ArenaView = _view(STY, LOW)
	assert_float(_ground_param(v, &"wet_on")).is_equal(0.0)
	assert_float(_ground_param(v, &"ripples_on")).is_equal(0.0)
	assert_object(_mesh_of(v, "Decor").surface_get_material(0)).is_same(EnvMat.prop(false))
	assert_bool(_visible_layer(v, "EnvVignette")).is_false()
	assert_bool(v.environment_node.environment.adjustment_enabled).is_false()
	assert_bool(v.glow_active()).is_false()
	v.set_quality(MID)
	assert_bool(v.environment_node.environment.adjustment_enabled).is_true()
	assert_bool(_visible_layer(v, "EnvVignette")).is_false()
	assert_float(_ground_param(v, &"wet_on")).is_equal(1.0)
	assert_float(_ground_param(v, &"ripples_on")).is_equal(0.0)
	assert_object(_mesh_of(v, "Decor").surface_get_material(0)).is_same(EnvMat.prop(false))
	assert_bool(v.glow_active()).is_false()
	v.set_quality(HIGH)
	assert_object(_mesh_of(v, "Decor").surface_get_material(0)).is_same(EnvMat.prop(true))
	assert_bool(_visible_layer(v, "EnvVignette")).is_true()
	assert_float(_ground_param(v, &"ripples_on")).is_equal(1.0)
	assert_bool(v.glow_active()).is_true()
	assert_int(v.environment_node.environment.tonemap_mode).is_equal(EnvStyle.GRADE_TONEMAP)
	assert_bool(v.environment_node.environment.adjustment_enabled).is_true()
	assert_float(v.environment_node.environment.adjustment_contrast).is_equal_approx(EnvStyle.GRADE_CONTRAST, 0.001)


func test_bloom_of_stylised_plus_is_unchanged_on_mid() -> void:
	var v: ArenaView = _view(PLUS, MID)
	assert_bool(v.glow_active()).is_true()
	var w: ArenaView = _view(STY, MID)
	assert_bool(w.glow_active()).is_false()


func test_switching_the_look_50_times_grows_nothing() -> void:
	var v: ArenaView = _view(STY, HIGH)
	var tiers: Array[int] = [LOW, MID, HIGH]
	for i: int in 12:  # every look and tier combination once, so the lazily built pieces exist before counting
		v.set_look(CUR if i % 2 == 0 else STY)
		v.set_quality(tiers[i % 3])
	var nodes: int = v.node_count()
	var env_mats: int = EnvMat.cached_count()
	var lookdev_mats: int = LookDevMat.cached_count()
	var objects: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	for i: int in 50:
		v.set_look(CUR if i % 2 == 0 else STY)
		v.set_quality(tiers[i % 3])
	var objects_after: float = Performance.get_monitor(Performance.OBJECT_COUNT)  # before any assert allocates
	assert_int(v.node_count()).is_equal(nodes)
	assert_int(EnvMat.cached_count()).is_equal(env_mats)
	assert_int(LookDevMat.cached_count()).is_equal(lookdev_mats)
	assert_float(objects_after).is_less_equal(objects)


func test_styled_node_budget() -> void:
	var cur: ArenaView = _view(CUR)
	var sty: ArenaView = _view(STY)
	assert_int(cur.node_count()).is_between(15, 60)
	assert_int(sty.node_count() - cur.node_count()).is_between(5, 14)


func test_props_keep_their_footprint() -> void:
	var cur: ArenaView = _view(CUR)
	var sty: ArenaView = _view(STY)
	var old_verts: PackedVector3Array = _vertices(_mesh_of(cur, "Props"))
	var new_verts: PackedVector3Array = _vertices(_mesh_of(sty, "Props"))
	for ob: ObstacleDef in _content.arena.obstacles:
		var old_box: Rect2 = _footprint(old_verts, ob, 0.9)
		var new_box: Rect2 = _footprint(new_verts, ob, 0.9)
		assert_float(new_box.position.x).override_failure_message("%s grew to the left" % ob.id).is_greater_equal(old_box.position.x - 0.2)
		assert_float(new_box.position.y).override_failure_message("%s grew upward" % ob.id).is_greater_equal(old_box.position.y - 0.2)
		assert_float(new_box.end.x).override_failure_message("%s grew to the right" % ob.id).is_less_equal(old_box.end.x + 0.2)
		assert_float(new_box.end.y).override_failure_message("%s grew downward" % ob.id).is_less_equal(old_box.end.y + 0.2)
		var tall: int = 0
		for p: Vector3 in new_verts:
			if p.y > 0.2 and ob.contains(p.x, p.z, 0.3):
				tall += 1
		assert_int(tall).override_failure_message("no styled geometry for %s" % ob.id).is_greater(30)
	for p: Vector3 in new_verts:
		var owned: bool = false
		for ob2: ObstacleDef in _content.arena.obstacles:
			owned = owned or ob2.contains(p.x, p.z, 0.9)
		assert_bool(owned).override_failure_message("stray styled prop vertex %s" % p).is_true()


## The XZ box of the vertices that belong to `ob` (within `inflate` of its footprint).
func _footprint(verts: PackedVector3Array, ob: ObstacleDef, inflate: float) -> Rect2:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for p: Vector3 in verts:
		if ob.contains(p.x, p.z, inflate):
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	return Rect2(lo, hi - lo)


func test_decor_keeps_the_layout_of_the_old_yard() -> void:
	var a: ArenaDef = _content.arena
	var old_spots: Array[Vector3] = DecorKit.build(a, MeshKit.begin(), MeshKit.begin())
	var new_spots: Array[Vector3] = EnvDecor.build(a, MeshKit.begin(), MeshKit.begin())
	assert_int(new_spots.size()).is_equal(old_spots.size())
	for i: int in old_spots.size():
		assert_vector(new_spots[i]).is_equal_approx(old_spots[i], Vector3(0.001, 0.001, 0.001))


func test_styled_decor_stays_outside_the_playable_rectangle_and_the_spawn_edges() -> void:
	var a: ArenaDef = _content.arena
	var verts: PackedVector3Array = _vertices(_mesh_of(_view(STY), "Decor"))
	assert_int(verts.size()).is_greater(4000)
	for p: Vector3 in verts:
		var inside: bool = p.x > a.min_x and p.x < a.max_x and p.z > a.min_z and p.z < a.max_z
		if inside and p.y < 1.0:
			fail("styled decor footprint inside the playable rectangle at %s" % p)
			return
	for r: SpawnRegionDef in a.spawn_regions:
		for p: Vector3 in verts:
			if p.y > 1.0:
				continue
			var d: float = Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(r.x0, r.z0), Vector2(r.x1, r.z1)).distance_to(Vector2(p.x, p.z))
			if d < 0.4:
				fail("styled decor blocks spawn region %s at %s" % [r.id, p])
				return


func test_styled_triangle_budget() -> void:
	var v: ArenaView = _view(STY)
	var total: int = 0
	for node_name: String in ["Props", "Decor", "LampHeads"]:
		total += _tris(_mesh_of(v, node_name))
	assert_int(total).is_between(8000, 40000)


func test_lamp_heads_are_hdr_only_in_the_styled_yard() -> void:
	var v: ArenaView = _view(STY)
	assert_float(v.lamp_gain).is_greater(1.0)
	assert_float(v.core.gain).is_equal(EnvStyle.REACTOR_GAIN)
	v.advance(0.5)
	var lamp: StandardMaterial3D = (v.get_node("LampHeads") as MeshInstance3D).material_override as StandardMaterial3D
	assert_float(lamp.albedo_color.r).is_greater(1.0)


func test_the_floor_reflects_at_most_twelve_sources_from_the_arena_data() -> void:
	var v: ArenaView = _view(STY, HIGH)
	var n: int = _ground_param(v, &"src_n")
	assert_int(n).is_between(8, EnvGround.MAX_SOURCES)
	var pos: PackedVector4Array = _ground_param(v, &"src_pos")
	assert_int(pos.size()).is_equal(EnvGround.MAX_SOURCES)
	assert_float(pos[0].x).is_equal_approx(_content.arena.core_x, 0.001)


func test_the_boot_warm_up_covers_the_new_materials() -> void:
	var v: ArenaView = _view(STY)
	var w: ShaderWarmup = v.get_node("ShaderWarmup")
	var seen: Array[Material] = []
	for s: int in w.mesh.get_surface_count():
		seen.append(w.mesh.surface_get_material(s))
	var floor_mat: Material = (v.get_node("Ground") as MeshInstance3D).material_override
	for m: Material in [floor_mat, EnvMat.prop(true), EnvMat.prop(false), EnvMat.emit(&"amber", EnvStyle.WINDOW_GAIN)]:
		assert_bool(seen.has(m)).override_failure_message("warm-up misses %s" % m.resource_name).is_true()
	var halos: int = 0
	for m2: Material in seen:
		if m2.resource_name.begins_with("env_halo"):
			halos += 1
	assert_int(halos).is_equal(3)
	assert_int(w.mesh.get_surface_count()).is_greater(MatLib.IDS.size() + 8)
	# the old look warms exactly what it always did
	var old: ShaderWarmup = _view(CUR).get_node("ShaderWarmup")
	assert_int(old.mesh.get_surface_count()).is_equal(MatLib.IDS.size() + 1)
