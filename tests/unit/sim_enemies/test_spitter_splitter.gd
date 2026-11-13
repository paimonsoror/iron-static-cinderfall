extends GdUnitTestSuite
## V4-N, GDD 6.3 rows `spitter`, `splitter`, `shard`, `mote`, `burster` on the variety fixture: the standoff artillery
## (parks at 10.5 m, a bolt every 2.4 s that flies 0.8 s for 18), the splitter (3 shards on a 0.6 m ring; a full mini
## cap queues them), and the one-time attackers.

const BOLT: int = HazardState.K_BOLT


func _world() -> SimWorld:
	return SimEnemiesKit.world()


## A spitter parked on the standoff point of ring 0 that is nearest to angle 0. Returns its store index.
func _parked_spitter(w: SimWorld) -> int:
	var a: ArenaDef = w.content.arena
	var best: int = -1
	for k: int in a.standoff_points.size():
		if a.standoff_ring[k] == 0 and (best < 0 or absf(a.standoff_points[k].y - a.core_z) < absf(a.standoff_points[best].y - a.core_z)):
			best = k
	var s: int = SimEnemiesKit.place(w, Ids.EN_SPITTER, a.standoff_points[best].x, a.standoff_points[best].y)
	assert_int(SimEnemiesKit.run_until_attacking(w, s, 10)).is_greater(0)
	return s


func _launches(w: SimWorld) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in SimEnemiesKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED):
		if e.a == BOLT:
			out.append(e)
	return out


func _core_hits(w: SimWorld, type_index: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in SimEnemiesKit.events_of(w, SimEventKind.Id.CORE_HIT):
		if e.b == type_index:
			out.append(e)
	return out


func test_a_spitter_walks_in_and_parks_on_a_standoff_point_10_5_m_from_the_core() -> void:
	var w: SimWorld = _world()
	var s: int = SimEnemiesKit.place_core(w, Ids.EN_SPITTER, 15.0, 0.0)
	assert_int(SimEnemiesKit.run_until_attacking(w, s)).is_greater(0)
	SimEnemiesKit.run(w, 30)
	var point: int = w.ext.anchor_point[s]
	assert_int(point).is_greater_equal(0)
	assert_int(w.content.arena.standoff_ring[point]).is_equal(0)
	assert_int(w.enemies.slot[s]).is_equal(-1)
	assert_float(SimEnemiesKit.core_dist(w, s)).is_equal_approx(10.5, 0.001)
	assert_float(w.enemies.x[s]).is_equal_approx(w.content.arena.standoff_points[point].x, 0.000001)
	assert_float(w.enemies.z[s]).is_equal_approx(w.content.arena.standoff_points[point].y, 0.000001)
	var reached: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_REACHED_SLOT)
	assert_int(reached.size()).is_equal(1)
	assert_int(reached[0].b).is_equal(-1)  # no attack slot
	var x: float = w.enemies.x[s]
	SimEnemiesKit.run(w, 600)
	assert_float(w.enemies.x[s]).is_equal(x)  # it stays parked
	assert_float(w.enemies.path_dist[s]).is_equal(0.0)


func test_a_parked_spitter_lobs_a_bolt_every_2_4_s_that_lands_0_8_s_later_for_18() -> void:
	var w: SimWorld = _world()
	var s: int = _parked_spitter(w)
	var core_before: float = w.core_hp
	SimEnemiesKit.run(w, 400)
	var launches: Array[SimEvent] = _launches(w)
	var hits: Array[SimEvent] = _core_hits(w, Ids.EN_SPITTER)
	assert_int(launches.size()).is_equal(2)
	assert_int(hits.size()).is_equal(2)
	assert_int(launches[1].tick - launches[0].tick).is_equal(144)  # 2.4 s
	assert_int(launches[0].b).is_equal(48)  # 0.8 s of flight, announced
	assert_int(hits[0].tick - launches[0].tick).is_equal(48)  # and flown
	assert_int(hits[1].tick - launches[1].tick).is_equal(48)
	assert_float(launches[0].f).is_equal(w.enemies.x[s])  # the arc starts at the spitter
	assert_float(launches[0].g).is_equal(w.enemies.z[s])
	assert_float(hits[0].f).is_equal(18.0)
	assert_int(hits[0].a).is_equal(0)  # a bolt has no living attacker
	assert_float(w.core_hp).is_equal(core_before - 36.0)
	assert_bool(w.ext.has_flag(s, EnemyExtState.F_FIRED)).is_true()
	assert_int(w.alive_count()).is_equal(1)  # firing never consumes it


func test_the_shield_eats_bolts() -> void:
	var w: SimWorld = _world()
	_parked_spitter(w)
	w.shield_hp = 100.0
	SimEnemiesKit.run(w, 200)
	var hits: Array[SimEvent] = _core_hits(w, Ids.EN_SPITTER)
	assert_int(hits.size()).is_equal(1)
	assert_float(hits[0].f).is_equal(0.0)
	assert_float(hits[0].g).is_equal(18.0)
	assert_float(w.shield_hp).is_equal(82.0)
	assert_float(w.core_hp).is_equal(w.core_max_hp)


func test_a_bolt_in_the_air_still_lands_after_its_spitter_died() -> void:
	var w: SimWorld = _world()
	var s: int = _parked_spitter(w)
	while _launches(w).is_empty() and w.tick < 400:
		SimEnemiesKit.tick(w)
	assert_int(_launches(w).size()).is_equal(1)
	SimEnemiesKit.kill(w, s)
	SimEnemiesKit.run(w, 60)
	assert_int(_core_hits(w, Ids.EN_SPITTER).size()).is_equal(1)
	assert_float(w.core_hp).is_equal(w.core_max_hp - 18.0)
	assert_int(w.hazards.q_due.size()).is_equal(0)  # the queue dropped the entry


func test_a_stun_freezes_the_spitters_timer() -> void:
	var plain: SimWorld = _world()
	var stunned: SimWorld = _world()
	_parked_spitter(plain)
	var s: int = _parked_spitter(stunned)
	stunned.enemies.stun_ticks[s] = 100
	SimEnemiesKit.run(plain, 300)
	SimEnemiesKit.run(stunned, 300)
	# the stun timer counts down before the core step: a stun of 100 holds the spitter for 99 of its ticks
	assert_int(_launches(stunned)[0].tick - _launches(plain)[0].tick).is_equal(99)


func test_a_spitter_counts_as_attacking_the_core_only_once_it_has_fired() -> void:
	var w: SimWorld = _world()
	var s: int = _parked_spitter(w)
	var k: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 3.0, 0.0)
	w.enemies.state[k] = EnemyStore.ST_ATTACKING
	w.enemies.path_dist[k] = 0.0
	# the shooter stands next to the spitter, so the spitter wins every tie on distance
	var from_x: float = w.enemies.x[s] + 0.5
	var from_z: float = w.enemies.z[s]
	assert_bool(w.ext.has_flag(s, EnemyExtState.F_FIRED)).is_false()
	assert_bool(Targeting.compare(w, k, s, from_x, from_z)).is_true()  # parked, silent: ranked below an attacker
	w.ext.flags[s] |= EnemyExtState.F_FIRED
	assert_bool(Targeting.compare(w, s, k, from_x, from_z)).is_true()  # it has fired: an attacker, and nearer


func test_a_splitter_dies_into_3_shards_on_a_0_6_m_ring() -> void:
	var w: SimWorld = _world()
	var s: int = SimEnemiesKit.place_core(w, Ids.EN_SPLITTER, 8.0, 0.0)
	var enemy_id: int = w.enemies.id[s]
	var x: float = w.enemies.x[s]
	var z: float = w.enemies.z[s]
	SimEnemiesKit.kill(w, s)
	var shards: PackedInt32Array = SimEnemiesKit.alive_of_type(w, Ids.EN_SHARD)
	assert_int(shards.size()).is_equal(3)
	assert_int(w.alive_count()).is_equal(3)
	for i: int in shards:
		assert_bool(w.ext.has_flag(i, EnemyExtState.F_MINI)).is_true()
		assert_float(Vector2(w.enemies.x[i] - x, w.enemies.z[i] - z).length()).is_equal_approx(0.6, 0.000001)
	assert_float(Vector2(w.enemies.x[shards[0]] - w.enemies.x[shards[1]], w.enemies.z[shards[0]] - w.enemies.z[shards[1]]).length()).is_greater(1.0)
	var split: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_SPLIT)
	assert_int(split.size()).is_equal(1)
	assert_int(split[0].a).is_equal(enemy_id)
	assert_int(split[0].b).is_equal(3)
	assert_float(split[0].f).is_equal(x)


func test_a_splitter_with_a_full_mini_cap_queues_its_shards_at_its_death_position() -> void:
	var w: SimWorld = _world()
	var motes: Array[int] = []
	for k: int in w.content.run.swarm_cap:
		motes.append(SimEnemiesKit.place_core(w, Ids.EN_MOTE, 12.0, -6.0 + 0.2 * float(k)))
	assert_int(motes[-1]).is_greater_equal(0)
	var s: int = SimEnemiesKit.place_core(w, Ids.EN_SPLITTER, 8.0, 0.0)
	var x: float = w.enemies.x[s]
	var z: float = w.enemies.z[s]
	SimEnemiesKit.kill(w, s)
	assert_int(SimEnemiesKit.alive_of_type(w, Ids.EN_SHARD).size()).is_equal(0)
	assert_int(SpawnSystem.pending_count(w)).is_equal(3)  # nothing is dropped
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_SPLIT).size()).is_equal(1)
	SimEnemiesKit.begin_tick(w)
	SpawnSystem.step(w)
	assert_int(SpawnSystem.pending_count(w)).is_equal(3)  # still no room
	w.kill_enemy(motes[0], DamageSource.Id.WARDEN)
	w.kill_enemy(motes[1], DamageSource.Id.WARDEN)
	SimEnemiesKit.begin_tick(w)
	SpawnSystem.step(w)
	var shards: PackedInt32Array = SimEnemiesKit.alive_of_type(w, Ids.EN_SHARD)
	assert_int(shards.size()).is_equal(2)
	assert_int(SpawnSystem.pending_count(w)).is_equal(1)
	for i: int in shards:
		assert_float(Vector2(w.enemies.x[i] - x, w.enemies.z[i] - z).length()).is_equal_approx(0.6, 0.000001)
	w.kill_enemy(motes[2], DamageSource.Id.WARDEN)
	SimEnemiesKit.begin_tick(w)
	SpawnSystem.step(w)
	assert_int(SimEnemiesKit.alive_of_type(w, Ids.EN_SHARD).size()).is_equal(3)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)


func test_a_living_splitter_walks_to_a_slot_and_hits_for_24_every_1_8_s() -> void:
	var w: SimWorld = _world()
	var s: int = SimEnemiesKit.place_core(w, Ids.EN_SPLITTER, 7.0, 0.0)
	assert_int(SimEnemiesKit.run_until_attacking(w, s)).is_greater(0)
	assert_int(w.enemies.slot[s]).is_greater_equal(0)
	SimEnemiesKit.run(w, 230)
	var hits: Array[SimEvent] = _core_hits(w, Ids.EN_SPLITTER)
	assert_int(hits.size()).is_equal(2)
	assert_float(hits[0].f).is_equal(24.0)
	assert_int(hits[1].tick - hits[0].tick).is_equal(108)


func test_shards_run_at_the_core_and_burn_out_for_8_each_with_no_scrap() -> void:
	var w: SimWorld = _world()
	var s: int = SimEnemiesKit.place_core(w, Ids.EN_SPLITTER, 6.0, 0.0)
	SimEnemiesKit.kill(w, s)
	var scrap_after_kill: int = w.scrap
	assert_int(scrap_after_kill).is_equal(w.content.enemies[Ids.EN_SPLITTER].scrap)
	SimEnemiesKit.run(w, 200)
	var hits: Array[SimEvent] = _core_hits(w, Ids.EN_SHARD)
	assert_int(hits.size()).is_equal(3)
	for e: SimEvent in hits:
		assert_float(e.f).is_equal(8.0)
	assert_float(w.core_hp).is_equal(w.core_max_hp - 24.0)
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.scrap).is_equal(scrap_after_kill)
	# a shard is faster than a mote (3.2 against 3.0 m/s)
	assert_float(w.nav.t_step[Ids.EN_SHARD]).is_greater(w.nav.t_step[Ids.EN_MOTE])


func test_a_mote_runs_the_flow_field_and_burns_out_on_the_cage_for_6() -> void:
	var w: SimWorld = _world()
	var m: int = SimEnemiesKit.place_core(w, Ids.EN_MOTE, 8.0, 0.0)
	assert_int(w.enemies.slot[m]).is_equal(-1)
	SimEnemiesKit.run(w, 200)
	var hits: Array[SimEvent] = _core_hits(w, Ids.EN_MOTE)
	assert_int(hits.size()).is_equal(1)
	assert_float(hits[0].f).is_equal(6.0)
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.scrap).is_equal(0)


func test_a_burster_walks_to_its_slot_arms_for_1_2_s_and_detonates_on_the_core_for_70() -> void:
	var w: SimWorld = _world()
	var b: int = SimEnemiesKit.place_core(w, Ids.EN_BURSTER, 7.0, 0.0)
	assert_int(SimEnemiesKit.run_until_attacking(w, b)).is_greater(0)
	var reached: int = w.tick
	assert_bool(w.ext.has_flag(b, EnemyExtState.F_ARMED)).is_true()
	SimEnemiesKit.run(w, 80)
	var hits: Array[SimEvent] = _core_hits(w, Ids.EN_BURSTER)
	assert_int(hits.size()).is_equal(1)
	assert_float(hits[0].f).is_equal(70.0)
	assert_int(hits[0].tick - reached).is_equal(72)
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.scrap).is_equal(0)
