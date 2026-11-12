extends GdUnitTestSuite
## ActorMeshes: triangle budgets, surface counts, the single red optic and the silhouette differences (WORK_PLAN 6).


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)


func _tris(mesh: Mesh) -> int:
	return ActorMeshes.triangle_count(mesh)


func _has_material(mesh: Mesh, mat_id: StringName) -> bool:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) == MatLib.mat(mat_id):
			return true
	return false


func test_enemy_meshes_fit_their_triangle_budgets() -> void:
	for enemy_id: StringName in Ids.ENEMIES.slice(0, Ids.LEGACY_ENEMY_COUNT):
		var mesh: ArrayMesh = ActorMeshes.enemy(enemy_id)
		var budget: int = ActorMeshes.TRI_BUDGET[enemy_id]
		assert_int(_tris(mesh)).is_greater(40)
		assert_int(_tris(mesh)).is_less_equal(budget)


func test_hero_meshes_fit_their_triangle_budgets() -> void:
	var warden: int = _tris(ActorMeshes.warden_legs()) + _tris(ActorMeshes.warden_torso())
	assert_int(warden).is_less_equal(ActorMeshes.TRI_BUDGET[&"warden"])
	assert_int(_tris(ActorMeshes.turret())).is_less_equal(ActorMeshes.TRI_BUDGET[&"turret"])
	var split: int = _tris(ActorMeshes.turret_base()) + _tris(ActorMeshes.turret_head())
	assert_int(split).is_equal(_tris(ActorMeshes.turret()))
	assert_int(_tris(ActorMeshes.pistol())).is_less_equal(120)
	assert_int(_tris(ActorMeshes.smg())).is_less_equal(120)


func test_every_actor_mesh_has_at_most_three_surfaces() -> void:
	var meshes: Array[ArrayMesh] = [
		ActorMeshes.warden_legs(), ActorMeshes.warden_torso(), ActorMeshes.pistol(), ActorMeshes.smg(),
		ActorMeshes.turret_base(), ActorMeshes.turret_head(), ActorMeshes.turret(),
	]
	for enemy_id: StringName in Ids.ENEMIES.slice(0, Ids.LEGACY_ENEMY_COUNT):
		meshes.append(ActorMeshes.enemy(enemy_id))
	for m: ArrayMesh in meshes:
		assert_int(m.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)


func test_every_enemy_has_one_emissive_red_optic_surface_and_no_cyan() -> void:
	for enemy_id: StringName in Ids.ENEMIES.slice(0, Ids.LEGACY_ENEMY_COUNT):
		var mesh: ArrayMesh = ActorMeshes.enemy(enemy_id)
		assert_bool(_has_material(mesh, &"emit_red")).is_true()
		assert_bool(_has_material(mesh, &"emit_cyan")).is_false()
		assert_bool(_has_material(mesh, &"gunmetal")).is_true()


func test_friendly_machines_carry_cyan_lights_and_no_red() -> void:
	assert_bool(_has_material(ActorMeshes.warden_torso(), &"emit_cyan")).is_true()
	assert_bool(_has_material(ActorMeshes.turret(), &"emit_cyan")).is_true()
	assert_bool(_has_material(ActorMeshes.warden_torso(), &"emit_red")).is_false()
	assert_bool(_has_material(ActorMeshes.turret(), &"emit_red")).is_false()


func test_silhouette_hollow_warden_is_much_taller_than_skitter() -> void:
	var hollow: AABB = ActorMeshes.bounds(ActorMeshes.enemy(&"hollow_warden"))
	var skitter: AABB = ActorMeshes.bounds(ActorMeshes.enemy(&"skitter"))
	assert_float(hollow.size.y / skitter.size.y).is_greater_equal(1.6)


func test_silhouette_hulk_footprint_is_at_least_four_times_hollow_warden() -> void:
	var hulk: AABB = ActorMeshes.bounds(ActorMeshes.enemy(&"siege_hulk"))
	var hollow: AABB = ActorMeshes.bounds(ActorMeshes.enemy(&"hollow_warden"))
	var hulk_area: float = hulk.size.x * hulk.size.z
	var hollow_area: float = hollow.size.x * hollow.size.z
	assert_float(hulk_area / hollow_area).is_greater_equal(4.0)


func test_enemy_heights_match_the_content_visual_heights() -> void:
	var content: ContentSet = TestContent.baseline()
	for def: EnemyDef in content.enemies:
		var bb: AABB = ActorMeshes.bounds(ActorMeshes.enemy(def.visual_id))
		assert_float(bb.size.y).is_between(def.visual_height_m * 0.8, def.visual_height_m * 1.2)
		assert_float(bb.position.y).is_greater_equal(-0.15)


func test_warden_stands_about_one_point_nine_meters() -> void:
	var top: float = ActorMeshes.bounds(ActorMeshes.warden_torso()).end.y + HeroMeshes.WARDEN_WAIST_Y
	var low: float = ActorMeshes.bounds(ActorMeshes.warden_legs()).position.y
	assert_float(top).is_between(1.75, 2.05)
	assert_float(low).is_greater_equal(-0.05)


func test_meshes_are_cached_and_unknown_ids_fall_back_to_the_skitter() -> void:
	assert_object(ActorMeshes.enemy(&"rusher")).is_same(ActorMeshes.enemy(&"rusher"))
	assert_object(ActorMeshes.enemy(&"nope")).is_same(ActorMeshes.enemy(&"skitter"))
	assert_object(ActorMeshes.turret_head()).is_same(ActorMeshes.turret_head())


func test_shadow_disc_uses_the_shadow_material_and_few_triangles() -> void:
	var disc: ArrayMesh = ActorMeshes.shadow_disc()
	assert_int(disc.get_surface_count()).is_equal(1)
	assert_bool(_has_material(disc, &"shadow_blob")).is_true()
	assert_int(_tris(disc)).is_less_equal(20)
