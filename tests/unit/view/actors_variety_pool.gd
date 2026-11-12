extends GdUnitTestSuite
## V2-F: data-driven enemy pools (`EnemyDef.alive_cap`), the MiniSwarm (one draw call per mini type, no node per mini, nothing
## allocated after setup), the handshake `ActorLayer.supports_enemy_type`, elites and the burster's swelling tank.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)  # a test that switched the look must not leak it


func test_pool_sizes_follow_the_alive_cap_of_every_bodied_type() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var pool: EnemyPool = layer.enemy_pool()
	var total: int = 0
	for k: int in w.content.enemies.size():
		var def: EnemyDef = w.content.enemies[k]
		var want: int = 0 if def.is_mini() else def.alive_cap
		assert_int(pool.capacity(k)).is_equal(want)
		assert_int(EnemyPool.size_for(def, k)).is_equal(want)
		total += want
	print("POOL total views=%d for %d types" % [total, w.content.enemies.size()])
	assert_int(pool.total_capacity()).is_equal(total)
	assert_int(pool.capacity(Ids.EN_SKITTER)).is_equal(50)  # the legacy four keep their sizes through the data
	assert_int(pool.capacity(Ids.EN_HOLLOW)).is_equal(24)
	assert_int(pool.capacity(Ids.EN_RUSHER)).is_equal(32)
	assert_int(pool.capacity(Ids.EN_HULK)).is_equal(2)
	assert_int(pool.capacity(Ids.EN_BURSTER)).is_equal(20)
	assert_int(pool.capacity(Ids.EN_MOTE)).is_equal(0)  # minis have no pooled view
	assert_int(pool.capacity(Ids.EN_SHARD)).is_equal(0)


func test_the_legacy_content_keeps_its_four_pools_of_the_old_sizes() -> void:
	var c: ContentSet = TestContent.baseline()
	for k: int in c.enemies.size():
		assert_int(EnemyPool.size_for(c.enemies[k], k)).is_equal(EnemyPool.SIZES[k])  # alive_cap is 0 there
	assert_int(EnemyPool.size_for(c.enemies[Ids.EN_SKITTER], 9)).is_equal(0)  # a type beyond the legacy four with no cap has no views


func test_the_handshake_answers_true_for_motes_and_bursters_only_when_the_layer_can_draw_them() -> void:
	var layer: ActorLayer = VarietyFKit.bound_layer(self, VarietyFKit.world())
	assert_bool(layer.supports_enemy_type(Ids.EN_MOTE)).is_true()
	assert_bool(layer.supports_enemy_type(Ids.EN_BURSTER)).is_true()
	assert_bool(layer.supports_enemy_type(Ids.EN_SKITTER)).is_true()
	assert_bool(layer.supports_enemy_type(-1)).is_false()
	assert_bool(layer.supports_enemy_type(99)).is_false()
	var legacy: ActorLayer = ActorsTestKit.actor_layer(self, ActorsTestKit.world())
	auto_free(legacy)
	assert_bool(legacy.supports_enemy_type(Ids.EN_SKITTER)).is_true()
	assert_bool(legacy.supports_enemy_type(Ids.EN_MOTE)).is_false()  # the legacy content has no such type
	assert_bool(legacy.supports_enemy_type(Ids.EN_BURSTER)).is_false()
	var bare: ActorLayer = ActorLayer.new()
	auto_free(bare)
	assert_bool(bare.supports_enemy_type(Ids.EN_MOTE)).is_false()  # not set up


func test_the_sandbox_puppet_gets_real_bodies_once_the_layer_answers() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, TestContent.variety())
	assert_bool(VarietySandboxProbe.draws_variety(view)).is_true()
	var legacy: BattleView = ViewIntegrationKit.battle_view(self, TestContent.baseline())
	assert_bool(VarietySandboxProbe.draws_variety(legacy)).is_false()


func test_a_burster_gets_a_pooled_view_and_a_mote_gets_none() -> void:
	var w: SimWorld = VarietyFKit.world()
	var burster: int = w.spawn_enemy(Ids.EN_BURSTER, 2.0, 0.0)
	var mote: int = w.spawn_enemy(Ids.EN_MOTE, 3.0, 0.0)
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	layer.render(0.5, 0.016)
	assert_bool(layer.enemy_pool().by_id.has(w.enemies.id[burster])).is_true()
	assert_bool(layer.enemy_pool().by_id.has(w.enemies.id[mote])).is_false()
	assert_int(layer.visible_enemy_count()).is_equal(1)
	assert_int(layer.minis_drawn()).is_equal(1)
	assert_bool(layer.enemy_world_position(w.enemies.id[mote]).is_finite()).is_true()  # known through the store
	assert_bool(layer.enemy_hit_position(w.enemies.id[mote]).y > 0.0).is_true()
	var actor: EnemyActor = layer.enemy_pool().by_id[w.enemies.id[burster]]
	assert_int(actor.mesh.mesh.get_surface_count()).is_less_equal(ActorMeshes.MAX_SURFACES)
	assert_float(actor.hit_height).is_equal_approx(w.content.enemies[Ids.EN_BURSTER].visual_height_m * 0.55, 0.0001)


func test_forty_minis_are_one_draw_call_with_no_node_per_mini() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var nodes_before: int = ActorsTestKit.count_nodes(layer)
	var _ids: Array[int] = VarietyFKit.spawn(w, Ids.EN_MOTE, 40)
	layer.render(0.5, 0.016)
	assert_int(layer.minis_drawn()).is_equal(40)
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(nodes_before)  # nothing was added to the tree
	var swarm: MiniSwarm = layer.mini_swarm(Ids.EN_MOTE)
	assert_object(swarm).is_not_null()
	assert_int(swarm.node.multimesh.visible_instance_count).is_equal(40)
	assert_int(swarm.node.multimesh.instance_count).is_equal(w.content.enemies[Ids.EN_MOTE].alive_cap)
	assert_int(swarm.node.multimesh.transform_format).is_equal(MultiMesh.TRANSFORM_3D)
	assert_bool(swarm.node.multimesh.use_colors).is_false()  # transform only (ARCH 8: per-instance data is unreliable on PowerVR)
	assert_bool(swarm.node.multimesh.use_custom_data).is_false()
	assert_int(ActorMeshes.triangle_count(swarm.mesh())).is_less_equal(ActorMeshes.TRI_BUDGET[&"mote"])
	var draws: int = 0
	for mi: Node in ViewIntegrationKit.nodes_of(layer, "MultiMeshInstance3D"):
		if String(mi.name).begins_with("Minis_"):
			draws += 1
	assert_int(draws).is_equal(2)  # one MultiMesh per mini type of the content (mote, shard)
	var d: ActorDecals = layer.decals()
	assert_int(d.shadow_count()).is_equal(41)  # the 40 minis and the Warden


func test_more_minis_than_the_cap_are_not_drawn_and_never_raid_a_pool() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var swarm: MiniSwarm = layer.mini_swarm(Ids.EN_MOTE)
	swarm.begin_frame()
	for n: int in swarm.capacity + 7:
		var drawn: bool = swarm.add(float(n), 0.0, 0.0, 0.0, 0)
		assert_bool(drawn).is_equal(n < swarm.capacity)
	swarm.end_frame()
	assert_int(swarm.drawn_count()).is_equal(swarm.capacity)
	assert_int(swarm.node.multimesh.visible_instance_count).is_equal(swarm.capacity)


func test_minis_are_interpolated_face_their_walk_hop_and_die_with_the_store() -> void:
	var w: SimWorld = VarietyFKit.world()
	var i: int = w.spawn_enemy(Ids.EN_MOTE, 2.0, 4.0)
	w.enemies.prev_x[i] = 2.0
	w.enemies.prev_z[i] = 4.0
	w.enemies.x[i] = 2.04
	w.enemies.z[i] = 4.08
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var swarm: MiniSwarm = layer.mini_swarm(Ids.EN_MOTE)
	layer.render(0.5, 0.016)
	assert_float(swarm.instance_origin(0).x).is_equal_approx(2.02, 0.0001)
	assert_float(swarm.instance_origin(0).z).is_equal_approx(4.04, 0.0001)
	layer.render(1.0, 0.016)
	assert_float(swarm.instance_origin(0).x).is_equal_approx(2.04, 0.0001)
	layer.render(7.0, 0.016)  # never extrapolated
	assert_float(swarm.instance_origin(0).x).is_equal_approx(2.04, 0.0001)
	var hops: Array[float] = []
	for _f: int in 20:
		layer.render(1.0, 0.03)
		hops.append(swarm.instance_origin(0).y)
	assert_float(hops.max()).is_between(0.02, MiniSwarm.HOP_HEIGHT + 0.0001)  # a |sin| bounce above the ground
	assert_float(hops.min()).is_greater_equal(0.0)
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	Events.enemy_killed.emit(w.enemies.id[i], DamageSource.Id.WARDEN)
	layer.render(1.0, 0.016)
	assert_int(layer.minis_drawn()).is_equal(0)
	assert_int(swarm.node.multimesh.visible_instance_count).is_equal(0)


func test_a_hit_pops_a_mini_for_exactly_three_frames() -> void:
	var w: SimWorld = VarietyFKit.world()
	var i: int = w.spawn_enemy(Ids.EN_MOTE, 2.0, 4.0)
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var swarm: MiniSwarm = layer.mini_swarm(Ids.EN_MOTE)
	layer.render(1.0, 0.016)
	assert_float(swarm.instance_scale(0)).is_equal_approx(1.0, 0.0001)
	Events.enemy_damaged.emit(w.enemies.id[i], 5.0, DamageSource.Id.WARDEN)
	var sizes: Array[float] = []
	for _f: int in 5:
		layer.render(1.0, 0.016)
		sizes.append(swarm.instance_scale(0))
	assert_float(sizes[0]).is_equal_approx(1.0 + MiniSwarm.POP_SCALE, 0.0001)
	assert_float(sizes[0]).is_greater(sizes[1])
	assert_float(sizes[1]).is_greater(sizes[2])
	assert_float(sizes[2]).is_greater(1.0)
	assert_float(sizes[3]).is_equal_approx(1.0, 0.0001)
	assert_float(sizes[4]).is_equal_approx(1.0, 0.0001)


func test_a_steady_state_of_spawns_and_kills_allocates_nothing() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var ids: Array[int] = VarietyFKit.spawn(w, Ids.EN_MOTE, 30)
	var _b: Array[int] = VarietyFKit.spawn(w, Ids.EN_BURSTER, 10, -3.0)
	for _warm: int in 5:
		layer.render(0.5, 0.016)
	var nodes: int = ActorsTestKit.count_nodes(layer)
	var objects_before: int = 0
	for n: int in 450:
		if n == 150:  # the first 150 frames warm everything up; the next 300 are measured
			var _spawn_events: Array[SimEvent] = w.events.drain()
			_spawn_events = []
			objects_before = VarietyFKit.objects()
		var k: int = n % ids.size()
		var index: int = w.enemies.index_of(ids[k])
		Events.enemy_damaged.emit(ids[k], 1.0, DamageSource.Id.WARDEN)
		var _drained: Array[SimEvent] = w.events.drain()  # the sim's own event buffer is not the view's business
		if n % 7 == 0 and index >= 0:
			w.kill_enemy(index, DamageSource.Id.WARDEN)
			Events.enemy_killed.emit(ids[k], DamageSource.Id.WARDEN)
			var fresh: int = w.spawn_enemy(Ids.EN_MOTE, 1.0 + float(k % 9), 2.0)
			ids[k] = w.enemies.id[fresh]
		layer.render(0.5, 0.016)
	var _tail: Array[SimEvent] = w.events.drain()
	_tail = []
	var grown: int = VarietyFKit.objects() - objects_before  # measured before the first assert: an assertion is an object too
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(nodes)
	assert_int(grown).is_less_equal(2)  # the counter test: 300 frames of spawns, hits and kills, nothing allocated
	assert_int(layer.minis_drawn()).is_equal(30)


func test_the_swarm_wears_the_look_and_the_tier_without_making_materials() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var swarm: MiniSwarm = layer.mini_swarm(Ids.EN_MOTE)
	layer.set_look(LookDevStyle.Look.CURRENT)
	var flat_mesh: ArrayMesh = swarm.mesh()
	layer.set_look(LookDevStyle.Look.STYLISED)
	var styled_mesh: ArrayMesh = swarm.mesh()
	assert_object(styled_mesh).is_not_same(flat_mesh)
	assert_int(styled_mesh.get_surface_count()).is_equal(ActorMeshes.mini_look(&"mote", LookDevStyle.Look.STYLISED).get_surface_count())
	for s: int in styled_mesh.get_surface_count():
		var m: Material = styled_mesh.surface_get_material(s)
		assert_object(m).is_not_null()
		assert_bool(m is ShaderMaterial).is_false()  # small kinds always take the baked material (LookActorsStyle.shaded)
	var before: int = LookActorsMat.cached_count()
	for _n: int in 20:
		layer.set_look(LookDevStyle.Look.CURRENT)
		layer.set_look(LookDevStyle.Look.STYLISED)
		layer.set_quality(VisualQuality.Tier.LOW)
		layer.set_quality(VisualQuality.Tier.HIGH)
		layer.set_high_contrast(true)
		layer.set_high_contrast(false)
	assert_int(LookActorsMat.cached_count()).is_equal(before)
	assert_object(swarm.mesh()).is_same(styled_mesh)  # the private copies are reused, never rebuilt
	assert_object(ActorMeshes.mini_look(&"mote", LookDevStyle.Look.STYLISED)).is_not_same(styled_mesh)  # and the shared mesh is never mutated
	var shared: ArrayMesh = ActorMeshes.mini_look(&"mote", LookDevStyle.Look.STYLISED)
	for r: StringName in VarietyFKit.roles(shared):
		assert_bool([&"ceramic", &"emit_red"].has(r)).is_true()


func test_an_elite_is_larger_has_a_ring_and_a_bar_and_a_mini_never_has_a_bar() -> void:
	var w: SimWorld = VarietyFKit.world()
	var skitter: int = w.spawn_enemy(Ids.EN_SKITTER, 2.0, 0.0)
	var mote: int = w.spawn_enemy(Ids.EN_MOTE, 4.0, 0.0)
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var id: int = w.enemies.id[skitter]
	w.enemies.hp[mote] = 1.0
	layer.render(0.5, 0.016)
	assert_int(layer.decals().ring_count()).is_equal(0)
	assert_int(layer.decals().bar_count()).is_equal(0)  # a damaged mini and a healthy skitter show no bar
	Events.elite_spawned.emit(id, &"skitter", 1)
	layer.render(0.5, 0.016)
	var actor: EnemyActor = layer.enemy_pool().by_id[id]
	assert_bool(actor.elite).is_true()
	assert_float(actor.elite_scale).is_equal_approx(w.content.run.elite_scale, 0.0001)
	assert_float(actor.mesh.transform.basis.get_scale().x).is_greater(1.2)
	assert_int(layer.decals().ring_count()).is_equal(1)
	assert_int(layer.decals().bar_count()).is_equal(1)
	Events.elite_spawned.emit(424242, &"skitter", 1)  # an unknown id is ignored
	w.kill_enemy(skitter, DamageSource.Id.WARDEN)
	Events.enemy_killed.emit(id, DamageSource.Id.WARDEN)
	layer.render(0.5, 0.016)
	assert_int(layer.decals().ring_count()).is_equal(0)
	var again: int = w.spawn_enemy(Ids.EN_SKITTER, 2.0, 0.0)
	Events.enemy_spawned.emit(w.enemies.id[again], &"skitter")
	layer.render(0.5, 0.016)
	var recycled: EnemyActor = layer.enemy_pool().by_id[w.enemies.id[again]]
	assert_bool(recycled.elite).is_false()  # a recycled view carries nothing over


func test_an_armed_burster_swells_and_the_other_gaits_keep_their_poses() -> void:
	var walking: Transform3D = ActorMotion.pose(Ids.EN_BURSTER, 1.0, ActorMotion.Mode.MOVE)
	assert_float(walking.basis.get_scale().x).is_equal_approx(1.0, 0.0001)
	var start: float = ActorMotion.pose(Ids.EN_BURSTER, 1.0, ActorMotion.Mode.ATTACK, 0.0).basis.get_scale().x
	var late: float = ActorMotion.pose(Ids.EN_BURSTER, 1.0, ActorMotion.Mode.ATTACK, ActorMotion.BURSTER_FUSE_S).basis.get_scale().x
	assert_float(start).is_equal_approx(1.0, 0.0001)
	assert_float(late).is_greater(1.1)  # the tank swells while it arms
	assert_float(ActorMotion.pose(Ids.EN_BURSTER, 1.0, ActorMotion.Mode.ATTACK, 9.0).basis.get_scale().x).is_less(1.25)
	# the legacy archetypes ignore the phase and are never scaled
	for kind: int in [Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_RUSHER, Ids.EN_HULK]:
		var a: Transform3D = ActorMotion.pose(kind, 0.7, ActorMotion.Mode.ATTACK)
		var b: Transform3D = ActorMotion.pose(kind, 0.7, ActorMotion.Mode.ATTACK, 5.0)
		assert_bool(a.is_equal_approx(b)).is_true()
		assert_float(a.basis.get_scale().x).is_equal_approx(1.0, 0.0001)
	var w: SimWorld = VarietyFKit.world()
	var i: int = w.spawn_enemy(Ids.EN_BURSTER, 2.0, 0.0)
	w.enemies.state[i] = EnemyStore.ST_ATTACKING
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	for _f: int in 90:
		layer.render(1.0, 1.0 / 60.0)
	var actor: EnemyActor = layer.enemy_pool().by_id[w.enemies.id[i]]
	assert_float(actor.mesh.transform.basis.get_scale().x).is_greater(1.1)  # 1.5 s armed: the fuse is out
