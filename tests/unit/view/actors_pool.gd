extends GdUnitTestSuite
## ActorLayer: the pooled enemy views follow the stores and Events (ARCH 8).


func _bound(count: int) -> Array:
	var w: SimWorld = ActorsTestKit.world()
	ActorsTestKit.spawn_mixed(w, count)
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	return [w, layer]


func test_bind_adopts_every_enemy_in_the_store_fifty_visible_actors() -> void:
	var pair: Array = _bound(50)
	var layer: ActorLayer = pair[1]
	assert_int(layer.visible_enemy_count()).is_equal(50)
	assert_int(ActorsTestKit.visible_enemy_roots(layer)).is_equal(50)


func test_killing_ten_releases_ten_views() -> void:
	var pair: Array = _bound(50)
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	var killed: int = 0
	var i: int = 0
	while killed < 10 and i < w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.type[i] == Ids.EN_SKITTER:
			var enemy_id: int = w.enemies.id[i]
			w.kill_enemy(i, DamageSource.Id.WARDEN)
			Events.enemy_killed.emit(enemy_id, DamageSource.Id.WARDEN)
			killed += 1
		i += 1
	assert_int(killed).is_equal(10)
	assert_int(layer.visible_enemy_count()).is_equal(40)
	assert_int(ActorsTestKit.visible_enemy_roots(layer)).is_equal(40)
	assert_int(layer.enemy_pool().free_count(Ids.EN_SKITTER)).is_equal(EnemyPool.SIZES[Ids.EN_SKITTER] - 29 + 10)


func test_five_hundred_spawn_and_kill_cycles_do_not_leak_nodes() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	var before: int = ActorsTestKit.count_nodes(layer)
	var types: Array[int] = [Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_RUSHER]
	for n: int in 500:
		var kind: int = types[n % types.size()]
		var i: int = w.spawn_enemy(kind, 4.0, -2.0)
		var enemy_id: int = w.enemies.id[i]
		Events.enemy_spawned.emit(enemy_id, Ids.ENEMIES[kind])
		layer.render(0.5, 0.016)
		assert_int(layer.visible_enemy_count()).is_equal(1)
		w.kill_enemy(i, DamageSource.Id.WARDEN)
		Events.enemy_killed.emit(enemy_id, DamageSource.Id.WARDEN)
		layer.render(0.5, 0.016)
	assert_int(layer.visible_enemy_count()).is_equal(0)
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(before)


func test_interpolation_gives_prev_mid_and_current_at_alpha_0_half_1() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var i: int = w.spawn_enemy(Ids.EN_RUSHER, 2.0, 4.0)
	var enemy_id: int = w.enemies.id[i]
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	# one tick of a fast walker (0.06 m); a jump of more than ActorLayer.TELEPORT_M is a forced move and is not interpolated
	w.enemies.prev_x[i] = 2.0
	w.enemies.prev_z[i] = 4.0
	w.enemies.x[i] = 2.04
	w.enemies.z[i] = 4.08
	layer.render(0.0, 0.016)
	assert_float(layer.enemy_world_position(enemy_id).x).is_equal_approx(2.0, 0.0001)
	assert_float(layer.enemy_world_position(enemy_id).z).is_equal_approx(4.0, 0.0001)
	layer.render(0.5, 0.016)
	assert_float(layer.enemy_world_position(enemy_id).x).is_equal_approx(2.02, 0.0001)
	assert_float(layer.enemy_world_position(enemy_id).z).is_equal_approx(4.04, 0.0001)
	layer.render(1.0, 0.016)
	assert_float(layer.enemy_world_position(enemy_id).x).is_equal_approx(2.04, 0.0001)
	assert_float(layer.enemy_world_position(enemy_id).z).is_equal_approx(4.08, 0.0001)
	layer.render(7.0, 0.016)  # never extrapolates
	assert_float(layer.enemy_world_position(enemy_id).x).is_equal_approx(2.04, 0.0001)


func test_unknown_id_in_enemy_killed_is_ignored() -> void:
	var pair: Array = _bound(12)
	var layer: ActorLayer = pair[1]
	Events.enemy_killed.emit(987654, DamageSource.Id.WARDEN)
	Events.enemy_damaged.emit(987654, 5.0, DamageSource.Id.WARDEN)
	assert_int(layer.visible_enemy_count()).is_equal(12)
	assert_bool(layer.enemy_world_position(987654).is_finite()).is_false()
	assert_bool(layer.is_flashing(987654)).is_false()


func test_unbind_hides_everything_and_forgets_ids() -> void:
	var pair: Array = _bound(50)
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	var some_id: int = w.enemies.id[3]
	layer.render(0.5, 0.016)
	assert_int(layer.decals().shadow_count()).is_greater(50)
	layer.unbind()
	assert_int(layer.visible_enemy_count()).is_equal(0)
	assert_int(ActorsTestKit.visible_enemy_roots(layer)).is_equal(0)
	assert_int(layer.decals().shadow_count()).is_equal(0)
	assert_bool(layer.warden.visible).is_false()
	assert_bool(layer.enemy_world_position(some_id).is_finite()).is_false()
	Events.enemy_spawned.emit(some_id, &"skitter")  # no longer connected
	assert_int(layer.visible_enemy_count()).is_equal(0)


func test_spawn_event_acquires_a_view_for_a_new_enemy() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	var i: int = w.spawn_enemy(Ids.EN_HOLLOW, -2.0, 1.0)
	Events.enemy_spawned.emit(w.enemies.id[i], &"hollow_warden")
	assert_int(layer.visible_enemy_count()).is_equal(1)
	var pos: Vector3 = layer.enemy_world_position(w.enemies.id[i])
	assert_float(pos.x).is_equal_approx(-2.0, 0.0001)
	assert_float(pos.z).is_equal_approx(1.0, 0.0001)
	assert_bool(layer.enemy_hit_position(w.enemies.id[i]).y > 0.5).is_true()


func test_hit_flash_swaps_the_material_for_exactly_three_frames() -> void:
	var pair: Array = _bound(5)
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	var enemy_id: int = w.enemies.id[1]
	assert_bool(layer.is_flashing(enemy_id)).is_false()
	Events.enemy_damaged.emit(enemy_id, 12.0, DamageSource.Id.WARDEN)
	for frame: int in 3:
		layer.render(0.5, 0.016)
		assert_bool(layer.is_flashing(enemy_id)).is_true()
	layer.render(0.5, 0.016)
	assert_bool(layer.is_flashing(enemy_id)).is_false()


func test_each_view_is_one_node_with_one_mesh_instance() -> void:
	var pair: Array = _bound(3)
	var layer: ActorLayer = pair[1]
	var total: int = 0
	for k: int in Ids.ENEMIES.size():
		total += layer.enemy_pool().capacity(k)
	assert_int(total).is_equal(108)
	for c: Node in layer.get_children():
		if c is Node3D and String(c.name).contains("_") and c.get_child_count() == 1:
			var mi: MeshInstance3D = c.get_child(0) as MeshInstance3D
			assert_object(mi).is_not_null()
			assert_int(mi.mesh.get_surface_count()).is_less_equal(3)


func test_pool_sizes_follow_the_architecture() -> void:
	var pair: Array = _bound(1)
	var layer: ActorLayer = pair[1]
	assert_int(layer.enemy_pool().capacity(Ids.EN_SKITTER)).is_equal(50)
	assert_int(layer.enemy_pool().capacity(Ids.EN_HOLLOW)).is_equal(24)
	assert_int(layer.enemy_pool().capacity(Ids.EN_RUSHER)).is_equal(32)
	assert_int(layer.enemy_pool().capacity(Ids.EN_HULK)).is_equal(2)


func test_an_exhausted_pool_recycles_the_oldest_view_and_never_thrashes() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var ids: Array[int] = []
	for n: int in 52:
		var i: int = w.spawn_enemy(Ids.EN_SKITTER, float(n % 10), -float(floori(float(n) / 10.0)))
		ids.append(w.enemies.id[i])
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	assert_int(layer.visible_enemy_count()).is_equal(50)
	assert_bool(layer.enemy_world_position(ids[0]).is_finite()).is_false()
	assert_bool(layer.enemy_world_position(ids[51]).is_finite()).is_true()
	layer.render(0.5, 0.016)
	layer.render(0.5, 0.016)
	assert_int(layer.visible_enemy_count()).is_equal(50)
	assert_bool(layer.enemy_world_position(ids[0]).is_finite()).is_false()


func test_siege_hulk_collapses_then_is_released() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var i: int = w.spawn_enemy(Ids.EN_HULK, -3.0, 2.0)
	var hulk_id: int = w.enemies.id[i]
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	Events.enemy_killed.emit(hulk_id, DamageSource.Id.WARDEN)
	assert_int(layer.visible_enemy_count()).is_equal(1)  # still collapsing
	assert_bool(layer.enemy_world_position(hulk_id).is_finite()).is_false()
	layer.render(0.5, 0.5)
	assert_int(layer.visible_enemy_count()).is_equal(1)
	layer.render(0.5, ActorMotion.HULK_COLLAPSE_S)
	assert_int(layer.visible_enemy_count()).is_equal(0)


func test_facing_follows_the_store_and_each_enemy_gets_a_shadow() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 0.0, 0.0)
	w.enemies.face_x[i] = 1.0
	w.enemies.face_z[i] = 0.0
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	layer.render(0.5, 0.016)
	var actor: EnemyActor = layer.enemy_pool().by_id[w.enemies.id[i]]
	assert_float(actor.root.rotation.y).is_equal_approx(-PI * 0.5, 0.001)  # forward -Z turned toward +X
	assert_int(layer.decals().shadow_count()).is_equal(2)  # the enemy and the Warden


func test_only_damaged_hollow_wardens_show_a_world_health_bar() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var h: int = w.spawn_enemy(Ids.EN_HOLLOW, 0.0, 0.0)
	var h2: int = w.spawn_enemy(Ids.EN_HOLLOW, 2.0, 0.0)
	var s: int = w.spawn_enemy(Ids.EN_SKITTER, 4.0, 0.0)
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	layer.render(0.5, 0.016)
	assert_int(layer.decals().bar_count()).is_equal(0)
	w.enemies.hp[h] = w.enemies.max_hp[h] * 0.5
	w.enemies.hp[s] = 1.0
	layer.render(0.5, 0.016)
	assert_int(layer.decals().bar_count()).is_equal(1)
	w.enemies.hp[h2] = 10.0
	layer.render(0.5, 0.016)
	assert_int(layer.decals().bar_count()).is_equal(2)


func test_low_quality_is_stored_clamped_and_still_moves_every_frame() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 0.0, 0.0)
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	layer.set_quality(99)
	assert_int(layer.quality()).is_equal(VisualQuality.Tier.HIGH)
	layer.set_quality(VisualQuality.Tier.LOW)
	assert_int(layer.quality()).is_equal(VisualQuality.Tier.LOW)
	w.enemies.prev_x[i] = 0.0
	w.enemies.x[i] = 1.0
	layer.render(0.25, 0.016)
	assert_float(layer.enemy_world_position(w.enemies.id[i]).x).is_equal_approx(0.25, 0.0001)
	layer.render(0.75, 0.016)
	assert_float(layer.enemy_world_position(w.enemies.id[i]).x).is_equal_approx(0.75, 0.0001)


func test_motion_poses_differ_per_archetype_and_hulk_steps_are_counted() -> void:
	var skitter: Transform3D = ActorMotion.pose(Ids.EN_SKITTER, 0.17, ActorMotion.Mode.MOVE)
	var hulk: Transform3D = ActorMotion.pose(Ids.EN_HULK, 0.17, ActorMotion.Mode.MOVE)
	assert_bool(skitter.is_equal_approx(hulk)).is_false()
	assert_int(ActorMotion.step_index(Ids.EN_SKITTER, 5.0)).is_equal(-1)
	assert_int(ActorMotion.step_index(Ids.EN_HULK, 0.1)).is_equal(0)
	assert_int(ActorMotion.step_index(Ids.EN_HULK, PI / ActorMotion.HULK_STEP_RATE + 0.01)).is_equal(1)
	var stunned: Transform3D = ActorMotion.pose(Ids.EN_HULK, 1.0, ActorMotion.Mode.STUN)
	assert_float(stunned.basis.get_euler().x).is_greater(0.1)  # staggers back
