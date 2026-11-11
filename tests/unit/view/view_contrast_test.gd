extends GdUnitTestSuite
## W2-E: High Contrast for the enemies (GDD 10.3): brighter optics and rim lit plates, hue unchanged, undone cleanly.

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()
	MatLib.configure(_content.tokens)


func _layer_with_skitter() -> Array:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 2.0, 0.0)
	layer.bind(w)
	return [layer, w.enemies.id[i]]


func _actor_mesh(layer: ActorLayer, enemy_id: int) -> MeshInstance3D:
	var actor: EnemyActor = layer.enemy_pool().by_id[enemy_id]
	return actor.mesh


## The surface index whose base material is `mat_id`, or -1.
func _surface_of(mi: MeshInstance3D, mat_id: StringName) -> int:
	var m: ArrayMesh = mi.mesh as ArrayMesh
	for s: int in m.get_surface_count():
		if m.surface_get_material(s) == MatLib.mat(mat_id):
			return s
	return -1


func test_high_contrast_brightens_the_optic_and_keeps_it_red() -> void:
	var pair: Array = _layer_with_skitter()
	var layer: ActorLayer = pair[0]
	var enemy_id: int = pair[1]
	var mi: MeshInstance3D = _actor_mesh(layer, enemy_id)
	var optic: int = _surface_of(mi, &"emit_red")
	assert_int(optic).is_greater_equal(0)
	assert_object(mi.get_surface_override_material(optic)).is_null()
	layer.set_high_contrast(true)
	var hc: StandardMaterial3D = mi.get_surface_override_material(optic) as StandardMaterial3D
	assert_object(hc).is_not_null()
	var base: StandardMaterial3D = MatLib.mat(&"emit_red")
	# brighter: more glow, full value, more saturated; the hue (the enemy red of the palette) does not move
	assert_float(hc.emission_energy_multiplier).is_greater(base.emission_energy_multiplier * 1.5)
	assert_float(hc.albedo_color.v).is_equal_approx(1.0, 0.001)
	assert_float(hc.albedo_color.v).is_greater_equal(base.albedo_color.v)
	assert_float(hc.albedo_color.s).is_greater(base.albedo_color.s + 0.1)
	assert_float(absf(hc.albedo_color.h - base.albedo_color.h)).is_less(0.02)
	assert_bool(hc.albedo_color.r > hc.albedo_color.g and hc.albedo_color.r > hc.albedo_color.b).is_true()
	assert_bool(hc.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED).is_true()


func test_high_contrast_rim_lights_the_plates_and_the_frame() -> void:
	var pair: Array = _layer_with_skitter()
	var layer: ActorLayer = pair[0]
	var enemy_id: int = pair[1]
	var mi: MeshInstance3D = _actor_mesh(layer, enemy_id)
	layer.set_high_contrast(true)
	for mat_id: StringName in [&"ceramic", &"gunmetal"]:
		var s: int = _surface_of(mi, mat_id)
		assert_int(s).is_greater_equal(0)
		var hc: StandardMaterial3D = mi.get_surface_override_material(s) as StandardMaterial3D
		assert_object(hc).is_not_null()
		assert_bool(hc.rim_enabled).is_true()
		assert_bool(MatLib.mat(mat_id).rim_enabled).is_false()  # the shared material is untouched
		assert_float(ActorContrast.brightness(hc)).is_greater(ActorContrast.brightness(MatLib.mat(mat_id)))


func test_turning_it_off_clears_every_override_and_the_flash_still_wins() -> void:
	var pair: Array = _layer_with_skitter()
	var layer: ActorLayer = pair[0]
	var enemy_id: int = pair[1]
	var mi: MeshInstance3D = _actor_mesh(layer, enemy_id)
	layer.set_high_contrast(true)
	assert_bool(layer.is_high_contrast()).is_true()
	layer.render(1.0, 0.016)
	Events.enemy_damaged.emit(enemy_id, 10.0, DamageSource.Id.WARDEN)
	layer.render(1.0, 0.016)
	assert_object(mi.material_override).is_same(MatLib.mat(&"flash_white"))  # surface overrides never hide the hit flash
	layer.set_high_contrast(false)
	for s: int in mi.mesh.get_surface_count():
		assert_object(mi.get_surface_override_material(s)).is_null()
	assert_bool(layer.is_high_contrast()).is_false()


func test_every_pooled_view_carries_it_including_free_ones_and_new_arrivals() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.set_high_contrast(true)
	layer.bind(w)
	var pool: EnemyPool = layer.enemy_pool()
	var late: int = w.spawn_enemy(Ids.EN_RUSHER, 3.0, 1.0)
	Events.enemy_spawned.emit(w.enemies.id[late], Ids.ENEMIES[Ids.EN_RUSHER])
	var mi: MeshInstance3D = _actor_mesh(layer, w.enemies.id[late])
	var optic: int = _surface_of(mi, &"emit_red")
	assert_object(mi.get_surface_override_material(optic)).is_not_null()
	assert_int(pool.visible_count()).is_equal(1)
	# a pooled view that is not on screen has it too
	var hidden_count: int = 0
	for c: Node in layer.get_children():
		var root: Node3D = c as Node3D
		if root != null and not root.visible and root.get_child_count() == 1 and root.get_child(0) is MeshInstance3D:
			var m: MeshInstance3D = root.get_child(0) as MeshInstance3D
			var s: int = _surface_of(m, &"emit_red")
			assert_object(m.get_surface_override_material(s)).is_not_null()
			hidden_count += 1
	assert_int(hidden_count).is_equal(108 - 1)


func test_battle_view_forwards_the_setting_and_the_hue_roles_hold() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	view.set_high_contrast(true)
	assert_bool(view.actor_layer.is_high_contrast()).is_true()
	# the friendly machines are not touched: no rim material on the Warden's torso
	var torso: MeshInstance3D = view.actor_layer.warden.get_node("Upper/Body/Torso") as MeshInstance3D
	for s: int in torso.mesh.get_surface_count():
		assert_object(torso.get_surface_override_material(s)).is_null()
	# cyan stays cyan, red stays red: the optic variant has no blue-dominant channel
	var optic: StandardMaterial3D = ActorContrast.variant_of(MatLib.mat(&"emit_red")) as StandardMaterial3D
	assert_float(optic.albedo_color.r).is_greater(optic.albedo_color.b)
	assert_object(ActorContrast.variant_of(MatLib.mat(&"emit_cyan"))).is_null()
	view.set_high_contrast(false)
	assert_bool(view.actor_layer.is_high_contrast()).is_false()


func test_the_setting_made_before_setup_is_applied_when_the_pools_exist() -> void:
	MatLib.configure(_content.tokens)
	var layer: ActorLayer = ActorLayer.new()
	auto_free(layer)
	add_child(layer)
	layer.set_high_contrast(true)  # Game may apply the profile setting before the view is built
	layer.setup(_content)
	var w: SimWorld = ActorsTestKit.world()
	var i: int = w.spawn_enemy(Ids.EN_HOLLOW, 1.0, 1.0)
	layer.bind(w)
	var mi: MeshInstance3D = _actor_mesh(layer, w.enemies.id[i])
	assert_object(mi.get_surface_override_material(_surface_of(mi, &"emit_red"))).is_not_null()
