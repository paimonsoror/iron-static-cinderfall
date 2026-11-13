extends GdUnitTestSuite
## V4-R in the layer: every new type has a pool of the size its `alive_cap` says (the data drives it), a view that wears its own mesh,
## the shard has a MiniSwarm of its own, the new gaits are finite and bounded, the Tremor Rig's footfalls reach the layer, High Contrast
## dresses every new surface, and a steady state of spawns and kills allocates nothing.

const STYLED: int = LookDevStyle.Look.STYLISED
const BODIES: Array[int] = [
	Ids.EN_SPITTER, Ids.EN_SPLITTER, Ids.EN_SHIELDBEARER, Ids.EN_RECLAIMER, Ids.EN_JAMMER, Ids.EN_BORER, Ids.EN_WARD_PYLON,
	Ids.EN_BROOD_CARRIER, Ids.EN_LANCE_PLATFORM, Ids.EN_AEGIS_ARRAY, Ids.EN_TREMOR_RIG,
]


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	LookActorsStyle.rollout_override = -1


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	LookActorsStyle.rollout_override = -1


func test_every_new_type_has_a_pool_of_its_alive_cap_and_the_layer_can_draw_it() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var pool: EnemyPool = layer.enemy_pool()
	for k: int in BODIES:
		var def: EnemyDef = w.content.enemies[k]
		assert_int(def.alive_cap).is_greater(0)
		assert_int(pool.capacity(k)).is_equal(def.alive_cap)
		assert_bool(layer.supports_enemy_type(k)).is_true()
	assert_int(pool.capacity(Ids.EN_SPITTER)).is_equal(12)
	assert_int(pool.capacity(Ids.EN_SPLITTER)).is_equal(12)
	assert_int(pool.capacity(Ids.EN_SHIELDBEARER)).is_equal(6)
	assert_int(pool.capacity(Ids.EN_RECLAIMER)).is_equal(4)
	assert_int(pool.capacity(Ids.EN_JAMMER)).is_equal(6)
	assert_int(pool.capacity(Ids.EN_BORER)).is_equal(16)
	assert_int(pool.capacity(Ids.EN_WARD_PYLON)).is_equal(3)
	assert_int(pool.capacity(Ids.EN_BROOD_CARRIER)).is_equal(1)  # a boss is one pooled node
	assert_int(pool.capacity(Ids.EN_TREMOR_RIG)).is_equal(1)
	assert_bool(layer.supports_enemy_type(Ids.EN_SHARD)).is_true()  # the mini: a MiniSwarm, no pooled view
	assert_int(pool.capacity(Ids.EN_SHARD)).is_equal(0)
	print("POOL total views=%d" % pool.total_capacity())
	assert_int(pool.total_capacity()).is_less_equal(200)  # every pooled node is allocated once, at setup


func test_each_new_body_gets_a_view_with_its_own_mesh_in_every_look() -> void:
	var w: SimWorld = VarietyFKit.world()
	var ids: Dictionary[int, int] = {}
	for k: int in BODIES:
		var i: int = w.spawn_enemy(k, -4.0 + float(ids.size()) * 1.5, 0.0)
		assert_int(i).is_greater_equal(0)
		ids[k] = w.enemies.id[i]
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	layer.render(0.5, 0.016)
	assert_int(layer.visible_enemy_count()).is_equal(BODIES.size())
	for look: int in [LookDevStyle.Look.CURRENT, STYLED]:
		layer.set_look(look)
		for k: int in BODIES:
			var actor: EnemyActor = layer.enemy_pool().by_id[ids[k]]
			var def: EnemyDef = w.content.enemies[k]
			assert_object(actor.mesh.mesh).is_same(ActorMeshes.enemy_look(Ids.ENEMIES[k], look))
			assert_int(actor.mesh.mesh.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
			assert_float(actor.hit_height).is_equal_approx(def.visual_height_m * 0.55, 0.0001)
			assert_float(actor.bar_height).is_equal_approx(def.visual_height_m + 0.3, 0.0001)
			assert_float(actor.shadow_radius).is_equal_approx(def.radius * 1.55, 0.0001)
	layer.render(0.5, 0.016)


func test_the_shard_swarm_draws_the_shard_and_the_mote_swarm_the_mote() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var shards: MiniSwarm = layer.mini_swarm(Ids.EN_SHARD)
	var motes: MiniSwarm = layer.mini_swarm(Ids.EN_MOTE)
	assert_object(shards).is_not_null()
	layer.set_look(STYLED)
	assert_int(ActorMeshes.triangle_count(shards.mesh())).is_less_equal(ActorMeshes.TRI_BUDGET[&"shard"])
	assert_int(ActorMeshes.triangle_count(motes.mesh())).is_less_equal(ActorMeshes.TRI_BUDGET[&"mote"])
	assert_int(LookDevTestKit.mesh_hash(shards.mesh())).is_not_equal(LookDevTestKit.mesh_hash(motes.mesh()))
	assert_int(shards.mesh().get_surface_count()).is_equal(2)
	var _s: Array[int] = VarietyFKit.spawn(w, Ids.EN_SHARD, 40)
	layer.render(0.5, 0.016)
	assert_int(shards.node.multimesh.visible_instance_count).is_equal(40)
	assert_int(shards.node.multimesh.instance_count).is_equal(w.content.enemies[Ids.EN_SHARD].alive_cap)
	assert_bool(shards.node.multimesh.use_colors).is_false()  # transform only
	assert_bool(shards.node.multimesh.use_custom_data).is_false()


func test_the_new_gaits_are_finite_bounded_and_the_old_ones_are_untouched() -> void:
	for k: int in BODIES:
		for mode: int in [ActorMotion.Mode.MOVE, ActorMotion.Mode.ATTACK, ActorMotion.Mode.STUN]:
			for step: int in 40:
				var t: float = 0.37 * float(step)
				var xf: Transform3D = ActorMotion.pose(k, t, mode, t)
				assert_bool(xf.origin.is_finite() and xf.basis.is_finite()).is_true()
				assert_float(absf(xf.origin.y)).is_less(0.2)
				assert_float(absf(xf.origin.z)).is_less(0.3)
				assert_float(xf.basis.get_scale().x).is_equal_approx(1.0, 0.0001)  # never scaled: only the Burster swells
				var euler: Vector3 = xf.basis.get_euler()
				assert_float(maxf(absf(euler.x), maxf(absf(euler.y), absf(euler.z)))).is_less(0.35)
	for k: int in [Ids.EN_SPITTER, Ids.EN_BORER, Ids.EN_TREMOR_RIG, Ids.EN_SHIELDBEARER]:  # they move: not a frozen mesh
		var seen: Array[float] = []
		for step: int in 30:
			seen.append(ActorMotion.pose(k, 0.1 * float(step), ActorMotion.Mode.MOVE).origin.y)
		assert_float(seen.max() - seen.min()).is_greater(0.005)
	# the legacy kinds and the burster still use their own poses (a table of values from before V4-R)
	var skitter: Transform3D = ActorMotion.pose(Ids.EN_SKITTER, 0.7, ActorMotion.Mode.MOVE)
	assert_float(skitter.origin.y).is_equal_approx(absf(sin(0.7 * 13.0)) * 0.05, 0.0001)
	assert_float(ActorMotion.pose(Ids.EN_HULK, 0.7, ActorMotion.Mode.MOVE).origin.y).is_equal_approx(0.12 * absf(sin(0.7 * ActorMotion.HULK_STEP_RATE)), 0.0001)
	assert_int(ActorMotion.step_index(Ids.EN_SPITTER, 5.0)).is_equal(-1)
	assert_int(ActorMotion.step_index(Ids.EN_SKITTER, 5.0)).is_equal(-1)
	assert_int(ActorMotion.step_index(Ids.EN_TREMOR_RIG, 0.0)).is_equal(0)
	assert_int(ActorMotion.step_index(Ids.EN_TREMOR_RIG, 4.0)).is_equal(floori(4.0 * ActorMotion2.TREMOR_STEP_RATE / PI))


func test_a_walking_tremor_rig_makes_footfalls_and_a_spitter_does_not() -> void:
	var w: SimWorld = VarietyFKit.world()
	var rig: int = w.spawn_enemy(Ids.EN_TREMOR_RIG, 2.0, 0.0)
	var spitter: int = w.spawn_enemy(Ids.EN_SPITTER, 5.0, 0.0)
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var falls: Array[int] = [0]
	layer.footfall.connect(func(_at: Vector3, _weight: float) -> void: falls[0] += 1)
	for _f: int in 600:  # ten seconds at 60 fps: the rig stomps every PI / 1.7 = 1.85 s
		layer.render(1.0, 1.0 / 60.0)
	print("FOOTFALLS in 10 s: %d" % falls[0])
	assert_int(falls[0]).is_between(4, 6)
	w.kill_enemy(rig, DamageSource.Id.WARDEN)
	Events.enemy_killed.emit(w.enemies.id[rig], DamageSource.Id.WARDEN)
	falls[0] = 0
	for _f: int in 120:
		layer.render(1.0, 1.0 / 60.0)
	assert_int(falls[0]).is_equal(0)  # the spitter alone makes none
	assert_bool(w.enemies.alive[spitter] == 1).is_true()


func test_high_contrast_dresses_every_surface_of_every_new_body() -> void:
	var w: SimWorld = VarietyFKit.world()
	var ids: Array[int] = []
	for k: int in BODIES:
		var i: int = w.spawn_enemy(k, -4.0 + float(ids.size()) * 1.5, 0.0)
		ids.append(w.enemies.id[i])
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	layer.set_look(STYLED)
	layer.render(0.5, 0.016)
	for id: int in ids:
		var actor: EnemyActor = layer.enemy_pool().by_id[id]
		var before: Array[Material] = []
		for s: int in actor.mesh.mesh.get_surface_count():
			before.append(actor.mesh.get_surface_override_material(s))
		layer.set_high_contrast(true)
		for s: int in actor.mesh.mesh.get_surface_count():
			assert_object(actor.mesh.get_surface_override_material(s)).is_not_null()  # every role has its High Contrast twin
		layer.set_high_contrast(false)
		for s: int in actor.mesh.mesh.get_surface_count():
			assert_object(actor.mesh.get_surface_override_material(s)).is_same(before[s])  # off restores the look's own materials


func test_the_borer_wears_the_baked_material_on_every_tier_like_the_small_machines() -> void:
	var w: SimWorld = VarietyFKit.world()
	var borer: int = w.spawn_enemy(Ids.EN_BORER, 2.0, 0.0)
	var jammer: int = w.spawn_enemy(Ids.EN_JAMMER, 4.0, 0.0)
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	layer.set_look(STYLED)
	layer.set_quality(VisualQuality.Tier.HIGH)
	layer.render(0.5, 0.016)
	var b: EnemyActor = layer.enemy_pool().by_id[w.enemies.id[borer]]
	var j: EnemyActor = layer.enemy_pool().by_id[w.enemies.id[jammer]]
	for s: int in b.mesh.mesh.get_surface_count():
		assert_bool(b.mesh.get_surface_override_material(s) is ShaderMaterial).is_false()  # 16 borers: no shader on a body that small
	var shaded: int = 0
	for s: int in j.mesh.mesh.get_surface_count():
		if j.mesh.get_surface_override_material(s) is ShaderMaterial:
			shaded += 1
	assert_int(shaded).is_greater(0)  # the 6 jammers keep the shader on MID and HIGH


func test_a_new_elite_is_larger_and_a_recycled_view_carries_nothing_over() -> void:
	var w: SimWorld = VarietyFKit.world()
	var i: int = w.spawn_enemy(Ids.EN_SPLITTER, 2.0, 0.0)
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var id: int = w.enemies.id[i]
	layer.render(0.5, 0.016)
	Events.elite_spawned.emit(id, &"splitter", 1)
	layer.render(0.5, 0.016)
	var actor: EnemyActor = layer.enemy_pool().by_id[id]
	assert_bool(actor.elite).is_true()
	assert_float(actor.mesh.transform.basis.get_scale().x).is_greater(1.2)
	assert_int(layer.decals().bar_count()).is_equal(1)  # elites show a bar, and so do damaged splitters (the layer's rule)
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	Events.enemy_killed.emit(id, DamageSource.Id.WARDEN)
	var again: int = w.spawn_enemy(Ids.EN_SPLITTER, 2.0, 0.0)
	Events.enemy_spawned.emit(w.enemies.id[again], &"splitter")
	layer.render(0.5, 0.016)
	var recycled: EnemyActor = layer.enemy_pool().by_id[w.enemies.id[again]]
	assert_bool(recycled.elite).is_false()
	assert_float(recycled.mesh.transform.basis.get_scale().x).is_less(1.01)


func test_a_steady_state_of_new_bodies_spawning_and_dying_allocates_nothing() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	layer.set_look(STYLED)
	var ids: Array[int] = []
	var kinds: Array[int] = [Ids.EN_SPITTER, Ids.EN_SPLITTER, Ids.EN_JAMMER, Ids.EN_BORER, Ids.EN_SHIELDBEARER, Ids.EN_RECLAIMER]
	for n: int in 18:
		var i: int = w.spawn_enemy(kinds[n % kinds.size()], -4.0 + float(n % 9) * 1.0, -2.0 + float(floori(float(n) / 9.0)) * 2.0)
		ids.append(w.enemies.id[i])
	for _warm: int in 5:
		layer.render(0.5, 0.016)
	var nodes: int = ActorsTestKit.count_nodes(layer)
	var objects_before: int = 0
	Sfx.disabled = true  # the audio autoload answers every hit and kill with a one-shot voice: those are not the view's objects
	for n: int in 450:
		if n == 150:
			var _events: Array[SimEvent] = w.events.drain()
			_events = []
			objects_before = VarietyFKit.objects()
		var k: int = n % ids.size()
		var index: int = w.enemies.index_of(ids[k])
		Events.enemy_damaged.emit(ids[k], 1.0, DamageSource.Id.WARDEN)
		var _drained: Array[SimEvent] = w.events.drain()
		if n % 11 == 0 and index >= 0:
			var kind: int = w.enemies.type[index]
			w.kill_enemy(index, DamageSource.Id.WARDEN)
			Events.enemy_killed.emit(ids[k], DamageSource.Id.WARDEN)
			var fresh: int = w.spawn_enemy(kind, -3.0 + float(k % 7), 3.0)
			ids[k] = w.enemies.id[fresh]
			Events.enemy_spawned.emit(ids[k], Ids.ENEMIES[kind])
		layer.render(0.5, 0.016)
	var _tail: Array[SimEvent] = w.events.drain()
	_tail = []
	var grown: int = VarietyFKit.objects() - objects_before
	Sfx.disabled = false
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(nodes)
	assert_int(grown).is_less_equal(2)
