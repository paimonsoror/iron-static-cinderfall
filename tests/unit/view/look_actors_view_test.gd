extends GdUnitTestSuite
## W3-D hard-surface actors in the view: the pooled enemies share one mesh per kind and the look's shared materials, the hit flash
## still works over them, High Contrast builds twins of the look materials, tier gating, warm-up, the turret view, and switching
## the look 50 times neither grows the node tree nor the materials.

const STYLED: int = LookDevStyle.Look.STYLISED
const PLUS: int = LookDevStyle.Look.STYLISED_PLUS
const CURRENT: int = LookDevStyle.Look.CURRENT
const LOW: int = VisualQuality.Tier.LOW
const MID: int = VisualQuality.Tier.MID
const HIGH: int = VisualQuality.Tier.HIGH
const TIERS: Array[int] = [LOW, MID, HIGH]
const LOOKS: Array[int] = [STYLED, PLUS, CURRENT]


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)
	LookActorsStyle.rollout_override = -1
	LookDevStyle.glow_override = -1


func after_test() -> void:
	LookDevStyle.set_current(CURRENT)
	LookActorsStyle.rollout_override = -1
	LookDevStyle.glow_override = -1


func _layer(look: int, count: int = 30) -> ActorLayer:
	LookDevStyle.set_current(look)
	var w: SimWorld = ActorsTestKit.world()
	ActorsTestKit.spawn_mixed(w, count)
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	return layer


func _actors(layer: ActorLayer) -> Array[EnemyActor]:
	var out: Array[EnemyActor] = []
	for k: int in EnemyPool.SIZES.size():
		var pool: EnemyPool = layer.enemy_pool()
		for id: int in pool.by_id:
			var a: EnemyActor = pool.by_id[id]
			if a.kind == k:
				out.append(a)
	return out


func test_pooled_enemies_share_one_mesh_per_kind_and_the_shared_look_materials() -> void:
	var layer: ActorLayer = _layer(STYLED)
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	for a: EnemyActor in _actors(layer):
		assert_object(a.mesh.mesh).is_same(ActorMeshes.enemy_look(Ids.ENEMIES[a.kind], STYLED))
		meshes[a.kind] = a.mesh.mesh
		var m: ArrayMesh = a.mesh.mesh as ArrayMesh
		for s: int in m.get_surface_count():
			var o: Material = a.mesh.get_surface_override_material(s)
			assert_object(o).is_not_null()
			var key: String = "%d_%d" % [a.kind, s]
			if materials.has(key):
				assert_object(o).is_same(materials[key])  # one material per (kind, surface), never one per instance
			materials[key] = o
	assert_int(meshes.size()).is_equal(4)


func test_the_hit_flash_still_wins_over_the_look_materials_and_leaves_them_in_place() -> void:
	var layer: ActorLayer = _layer(STYLED)
	var a: EnemyActor = _actors(layer)[0]
	var before: Array[Material] = []
	for s: int in a.mesh.mesh.get_surface_count():
		before.append(a.mesh.get_surface_override_material(s))
	a.flash()
	a.update(0.016, 1.0, 1.0, 1.0, 0.0, ActorMotion.Mode.MOVE)
	assert_bool(a.is_flashing()).is_true()
	assert_object(a.mesh.material_override).is_same(MatLib.mat(&"flash_white"))
	for s: int in before.size():
		assert_object(a.mesh.get_surface_override_material(s)).is_same(before[s])
	for _f: int in EnemyActor.FLASH_FRAMES + 1:
		a.update(0.016, 1.0, 1.0, 1.0, 0.0, ActorMotion.Mode.MOVE)
	assert_bool(a.is_flashing()).is_false()


func test_switching_the_look_swaps_meshes_and_overrides_and_current_restores_the_old_ones() -> void:
	var layer: ActorLayer = _layer(CURRENT)
	for a: EnemyActor in _actors(layer):
		assert_object(a.mesh.mesh).is_same(ActorMeshes.enemy(Ids.ENEMIES[a.kind]))
		assert_object(a.mesh.get_surface_override_material(0)).is_null()
	layer.set_look(STYLED)
	for a: EnemyActor in _actors(layer):
		assert_object(a.mesh.mesh).is_same(ActorMeshes.enemy_look(Ids.ENEMIES[a.kind], STYLED))
		assert_object(a.mesh.get_surface_override_material(0)).is_not_null()
	layer.set_look(CURRENT)
	for a: EnemyActor in _actors(layer):
		assert_object(a.mesh.mesh).is_same(ActorMeshes.enemy(Ids.ENEMIES[a.kind]))
		for s: int in a.mesh.mesh.get_surface_count():
			assert_object(a.mesh.get_surface_override_material(s)).is_null()


func test_switching_the_look_fifty_times_grows_neither_nodes_nor_materials() -> void:
	var layer: ActorLayer = _layer(CURRENT)
	for look: int in LOOKS:  # one full cycle builds every cached mesh and material
		for tier: int in TIERS:
			layer.set_quality(tier)
			layer.set_look(look)
	var nodes: int = ActorsTestKit.count_nodes(layer)
	var mats: int = LookActorsMat.cached_count() + LookDevMat.cached_count()
	var resources: float = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for n: int in 50:
		layer.set_quality(TIERS[n % 3])
		layer.set_look(LOOKS[n % 3])
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(nodes)
	assert_int(LookActorsMat.cached_count() + LookDevMat.cached_count()).is_equal(mats)
	assert_float(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)).is_equal(resources)


func test_high_contrast_builds_twins_of_the_look_materials_and_off_restores_them() -> void:
	var layer: ActorLayer = _layer(STYLED)
	var a: EnemyActor = _actors(layer)[0]
	var optic: int = LookActorsTestKit.surface_of(a.mesh.mesh as ArrayMesh, &"emit_red")
	var plates: int = LookActorsTestKit.surface_of(a.mesh.mesh as ArrayMesh, &"ceramic")
	var base_optic: Material = a.mesh.get_surface_override_material(optic)
	var base_plates: Material = a.mesh.get_surface_override_material(plates)
	layer.set_high_contrast(true)
	var hc_optic: StandardMaterial3D = a.mesh.get_surface_override_material(optic) as StandardMaterial3D
	var hc_plates: ShaderMaterial = a.mesh.get_surface_override_material(plates) as ShaderMaterial
	assert_object(hc_optic).is_not_null()
	assert_object(hc_plates).is_not_same(base_plates)
	assert_object(hc_optic).is_not_same(base_optic)
	var plain: ShaderMaterial = base_plates as ShaderMaterial
	for param: StringName in [&"rim_strength", &"fill_strength", &"value_gain"]:
		var hc_value: float = hc_plates.get_shader_parameter(param)
		var base_value: float = plain.get_shader_parameter(param)
		assert_float(hc_value).is_greater(base_value)
	var base_red: Color = (base_optic as StandardMaterial3D).albedo_color
	assert_float(hc_optic.albedo_color.r).is_greater(base_red.r)
	assert_bool(hc_optic.albedo_color.h > 0.9 or hc_optic.albedo_color.h < 0.04).is_true()  # still red
	layer.set_high_contrast(false)
	assert_object(a.mesh.get_surface_override_material(optic)).is_same(base_optic)
	assert_object(a.mesh.get_surface_override_material(plates)).is_same(base_plates)


func test_high_contrast_on_low_gets_baked_twins_and_current_keeps_the_old_variants() -> void:
	var layer: ActorLayer = _layer(STYLED)
	layer.set_quality(LOW)
	layer.set_high_contrast(true)
	var a: EnemyActor = _actors(layer)[0]
	for s: int in a.mesh.mesh.get_surface_count():
		var m: Material = a.mesh.get_surface_override_material(s)
		assert_bool(m is StandardMaterial3D).is_true()
		assert_bool(String(m.resource_name).ends_with("_hc")).is_true()
	layer.set_look(CURRENT)
	for s: int in a.mesh.mesh.get_surface_count():
		var old: Material = a.mesh.get_surface_override_material(s)
		assert_object(old).is_same(ActorContrast.variant_of(a.mesh.mesh.surface_get_material(s)))


func test_tier_gating_of_the_enemy_materials() -> void:
	for tier: int in [MID, HIGH]:
		for role: StringName in [&"ceramic", &"gunmetal"]:
			var sm: ShaderMaterial = LookActorsMat.surface(role, STYLED, tier) as ShaderMaterial
			assert_object(sm).is_not_null()
			assert_float(sm.get_shader_parameter(&"grit_strength")).is_greater(0.0)
			assert_float(sm.get_shader_parameter(&"rim_strength")).is_greater(0.0)
	for role: StringName in [&"ceramic", &"gunmetal"]:
		var std: StandardMaterial3D = LookActorsMat.surface(role, STYLED, LOW) as StandardMaterial3D
		assert_object(std).is_not_null()  # LOW: geometry and baked vertex colours only, no shader
		assert_bool(std.vertex_color_use_as_albedo).is_true()
		assert_bool(LookActorsMat.surface(role, CURRENT, HIGH) == MatLib.mat(role)).is_true()
	assert_bool(LookActorsStyle.grit_enabled(STYLED, LOW)).is_false()
	assert_bool(LookActorsStyle.grit_enabled(STYLED, MID)).is_true()
	assert_bool(LookActorsStyle.grit_enabled(CURRENT, HIGH)).is_false()
	assert_float(LookActorsStyle.warm_rim_strength(STYLED, LOW)).is_equal(0.0)
	assert_float(LookActorsStyle.warm_rim_strength(CURRENT, HIGH)).is_equal(0.0)


func test_the_optic_is_hdr_only_where_glow_is_enabled_and_only_in_the_red_channel() -> void:
	var plain: StandardMaterial3D = LookActorsMat.surface(&"emit_red", STYLED, HIGH) as StandardMaterial3D
	assert_float(plain.albedo_color.r).is_less_equal(1.0)
	assert_bool(plain.vertex_color_use_as_albedo).is_true()
	assert_float(plain.albedo_color.r).is_greater(plain.albedo_color.g * 3.0)  # red, never pink or white
	LookDevStyle.glow_override = 1
	var glow: StandardMaterial3D = LookActorsMat.surface(&"emit_red", STYLED, HIGH) as StandardMaterial3D
	assert_float(glow.albedo_color.r).is_greater(1.0)  # bloom picks it up
	assert_float(maxf(glow.albedo_color.g, glow.albedo_color.b)).is_less(0.6)  # the halo is red, not white
	LookDevStyle.glow_override = 0
	assert_float((LookActorsMat.surface(&"emit_red", STYLED, HIGH) as StandardMaterial3D).albedo_color.r).is_less_equal(1.0)
	assert_object(LookActorsMat.surface(&"emit_red", CURRENT, HIGH)).is_same(MatLib.mat(&"emit_red"))


func test_the_new_materials_are_in_the_boot_warm_up_with_the_flash_over_a_coloured_mesh() -> void:
	assert_bool(LookDevMat.warm_materials(CURRENT).is_empty()).is_true()
	var warm: Array[Material] = LookDevMat.warm_materials(STYLED)
	assert_bool(warm.has(MatLib.mat(&"flash_white"))).is_true()
	assert_bool(warm.has(LookActorsMat.surface(&"emit_red", STYLED, MID))).is_true()
	assert_bool(warm.has(LookActorsMat.surface(&"ceramic", STYLED, MID))).is_true()
	assert_bool(warm.has(LookActorsMat.surface(&"gunmetal", STYLED, LOW))).is_true()
	var mesh: ArrayMesh = ShaderWarmup.build_mesh([], warm)
	var last: Array = mesh.surface_get_arrays(mesh.get_surface_count() - 1)
	assert_bool(last[Mesh.ARRAY_COLOR] != null).is_true()  # the vertex format of the styled meshes


func test_the_turret_view_wears_the_warden_materials_and_current_restores_the_old_meshes() -> void:
	var t: TurretView = auto_free(TurretView.new())
	t.setup(0)
	var base_node: MeshInstance3D = t.get_node("Rise/Base") as MeshInstance3D
	var head_node: MeshInstance3D = t.get_node("Rise/Head/HeadMesh") as MeshInstance3D
	assert_object(base_node.mesh).is_same(ActorMeshes.turret_base())
	t.apply_look(STYLED, HIGH)
	assert_object(base_node.mesh).is_same(ActorMeshes.turret_part(&"base", STYLED))
	assert_object(head_node.mesh).is_same(ActorMeshes.turret_part(&"head", STYLED))
	for node: MeshInstance3D in [base_node, head_node]:
		for s: int in node.mesh.get_surface_count():
			var role: StringName = StringName(node.mesh.surface_get_material(s).resource_name)
			assert_object(node.get_surface_override_material(s)).is_same(LookDevMat.surface(role, STYLED, HIGH))
	t.apply_look(CURRENT, HIGH)
	assert_object(head_node.mesh).is_same(ActorMeshes.turret_head())
	assert_object(head_node.get_surface_override_material(0)).is_null()


func test_pooled_enemies_still_face_their_movement_direction() -> void:
	var layer: ActorLayer = _layer(STYLED)
	var a: EnemyActor = _actors(layer)[0]
	for _i: int in 200:
		a.update(0.016, 0.0, 0.0, 0.0, -1.0, ActorMotion.Mode.MOVE)
	assert_float(absf(a.root.rotation.y)).is_less(0.05)  # facing -Z
	for _j: int in 200:
		a.update(0.016, 0.0, 0.0, 1.0, 0.0, ActorMotion.Mode.MOVE)
	assert_float(a.root.rotation.y).is_equal_approx(atan2(-1.0, 0.0), 0.05)  # turned to face +X
