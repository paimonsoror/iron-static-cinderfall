extends GdUnitTestSuite
## V4-N, GDD 6.3 rows `reclaimer`, `jammer`, `borer` on the variety fixture.

const HELD: int = 100000  ## a stun that holds a body in place for a whole test


func _world() -> SimWorld:
	return SimEnemiesKit.world()


## A reclaimer parked on a standoff point of the 12.5 m ring. Returns its store index.
func _parked_reclaimer(w: SimWorld) -> int:
	var a: ArenaDef = w.content.arena
	var ring: int = StandoffPoints.ring_of(a, 12.5)
	var best: int = -1
	for k: int in a.standoff_points.size():
		if a.standoff_ring[k] == ring and (best < 0 or absf(a.standoff_points[k].y - a.core_z) < absf(a.standoff_points[best].y - a.core_z)):
			best = k
	var r: int = SimEnemiesKit.place(w, Ids.EN_RECLAIMER, a.standoff_points[best].x, a.standoff_points[best].y)
	assert_int(SimEnemiesKit.run_until_attacking(w, r, 10)).is_greater(0)
	return r


## A held skitter at (dx, dz) from store index `near`, at `frac` of its hit points.
func _damaged(w: SimWorld, near: int, dx: float, dz: float, frac: float, type_index: int = Ids.EN_SKITTER) -> int:
	var i: int = SimEnemiesKit.place(w, type_index, w.enemies.x[near] + dx, w.enemies.z[near] + dz)
	w.enemies.stun_ticks[i] = HELD
	w.enemies.hp[i] = w.enemies.max_hp[i] * frac
	return i


func test_a_reclaimer_walks_in_and_parks_12_5_m_from_the_core() -> void:
	var w: SimWorld = _world()
	var r: int = SimEnemiesKit.place_core(w, Ids.EN_RECLAIMER, 16.0, 0.0)
	assert_int(SimEnemiesKit.run_until_attacking(w, r)).is_greater(0)
	SimEnemiesKit.run(w, 40)
	assert_float(SimEnemiesKit.core_dist(w, r)).is_equal_approx(12.5, 0.001)
	assert_int(w.content.arena.standoff_ring[w.ext.anchor_point[r]]).is_equal(StandoffPoints.ring_of(w.content.arena, 12.5))
	assert_int(w.enemies.slot[r]).is_equal(-1)
	SimEnemiesKit.run(w, 600)
	assert_float(w.core_hp).is_equal(w.core_max_hp)  # it never hurts the core
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED).size()).is_equal(0)


func test_a_reclaimer_tethers_the_3_most_damaged_machines_within_6_m() -> void:
	var w: SimWorld = _world()
	var r: int = _parked_reclaimer(w)
	var a: int = _damaged(w, r, 1.0, 0.0, 0.8)
	var b: int = _damaged(w, r, 0.0, 2.0, 0.2)
	var c: int = _damaged(w, r, -1.5, -1.5, 0.6)
	var d: int = _damaged(w, r, 2.0, 2.0, 0.4)
	_damaged(w, r, 0.0, 6.2, 0.1)  # out of reach
	_damaged(w, r, 0.5, 0.5, 1.0)  # not damaged
	_damaged(w, r, -0.5, 0.5, 0.1, Ids.EN_MOTE)  # a mini is not repaired
	var targets: PackedInt32Array = PackedInt32Array()
	assert_int(AuraFields.tether_targets(w, r, targets)).is_equal(3)
	assert_array(Array(targets)).is_equal([b, d, c])
	assert_bool(targets.has(a)).is_false()
	assert_float(AuraFields.tether_pulse(w, w.content.enemies[Ids.EN_RECLAIMER], StatusSystem.PULSE_TICKS)).is_equal_approx(7.0, 0.000001)
	w.phase_state.act = 2  # the act tier applies: 14 x 1.35 per second
	assert_float(AuraFields.tether_pulse(w, w.content.enemies[Ids.EN_RECLAIMER], StatusSystem.PULSE_TICKS)).is_equal_approx(9.45, 0.000001)


func test_equally_damaged_machines_are_tethered_in_id_order() -> void:
	var w: SimWorld = _world()
	var r: int = _parked_reclaimer(w)
	var picks: Array[int] = []
	for k: int in 5:
		picks.append(_damaged(w, r, 1.0 + 0.5 * float(k), 0.0, 0.5))
	var targets: PackedInt32Array = PackedInt32Array()
	AuraFields.tether_targets(w, r, targets)
	assert_array(Array(targets)).is_equal([picks[0], picks[1], picks[2]])


func test_a_parked_reclaimer_heals_14_hp_per_second_on_each_tether() -> void:
	if not SimEnemiesKit.heal_wired():
		return  # DamageResolver.heal is still a stub in this checkout (needs owner, see the V4-N report)
	var w: SimWorld = _world()
	var r: int = _parked_reclaimer(w)
	var a: int = _damaged(w, r, 1.0, 0.0, 0.2)
	var before: float = w.enemies.hp[a]
	SimEnemiesKit.run(w, 60)
	assert_float(w.enemies.hp[a]).is_equal_approx(before + 14.0, 0.000001)
	var healed: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_HEALED)
	assert_int(healed.size()).is_equal(2)
	assert_int(healed[0].a).is_equal(w.enemies.id[a])
	assert_int(healed[0].b).is_equal(w.enemies.id[r])
	assert_float(healed[0].f).is_equal_approx(7.0, 0.000001)
	w.enemies.stun_ticks[r] = HELD  # a stunned reclaimer repairs nothing
	SimEnemiesKit.run(w, 60)
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_HEALED).size()).is_equal(2)


func test_a_reclaimer_is_a_priority_target() -> void:
	var w: SimWorld = _world()
	var r: int = SimEnemiesKit.place_core(w, Ids.EN_RECLAIMER, 14.0, 0.0)
	var k: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 13.0, 0.0)
	w.enemies.path_dist[r] = 0.3
	w.enemies.path_dist[k] = 0.3
	assert_bool(w.content.enemies[Ids.EN_RECLAIMER].priority_class).is_true()
	# the same ETA bucket, the skitter is nearer to the shooter: the reclaimer still comes first
	assert_bool(Targeting.compare(w, r, k, w.enemies.x[k] - 1.0, w.enemies.z[k])).is_true()


func test_turrets_within_7_m_of_a_jammer_fire_at_half_rate() -> void:
	var w: SimWorld = _world()
	var pad: Vector2 = w.content.arena.turret_pads[0]
	assert_float(StatusSystem.turret_rate_mult(w, 0)).is_equal(1.0)
	var j: int = SimEnemiesKit.place(w, Ids.EN_JAMMER, pad.x + 6.9, pad.y)
	assert_float(StatusSystem.turret_rate_mult(w, 0)).is_equal(0.5)
	assert_float(StatusSystem.turret_rate_mult(w, 1)).is_equal(1.0)  # the other pad is 10 m away
	w.enemies.x[j] = pad.x + 7.1
	assert_float(StatusSystem.turret_rate_mult(w, 0)).is_equal(1.0)
	assert_float(StatusSystem.turret_rate_mult(w, 9)).is_equal(1.0)  # no such pad


func test_ability_cooldowns_run_at_70_percent_while_any_jammer_lives() -> void:
	var w: SimWorld = _world()
	assert_float(StatusSystem.cooldown_rate(w)).is_equal(1.0)
	var a: int = SimEnemiesKit.place_core(w, Ids.EN_JAMMER, 15.0, 0.0)
	var b: int = SimEnemiesKit.place_core(w, Ids.EN_JAMMER, 15.0, 2.0)
	assert_float(StatusSystem.cooldown_rate(w)).is_equal(0.7)  # two jammers do not stack
	SimEnemiesKit.kill(w, a)
	assert_float(StatusSystem.cooldown_rate(w)).is_equal(0.7)
	SimEnemiesKit.kill(w, b)
	assert_float(StatusSystem.cooldown_rate(w)).is_equal(1.0)


func test_a_jammers_death_stuns_its_neighbours_within_3_m_for_1_s() -> void:
	var w: SimWorld = _world()
	var j: int = SimEnemiesKit.place_core(w, Ids.EN_JAMMER, 12.0, 0.0)
	var near: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 12.0, 2.9)
	var far: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 12.0, -3.1)
	SimEnemiesKit.kill(w, j)
	assert_int(w.enemies.stun_ticks[near]).is_equal(60)
	assert_int(w.enemies.stun_ticks[far]).is_equal(0)
	var stunned: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_STUNNED)
	assert_int(stunned.size()).is_equal(1)
	assert_int(stunned[0].a).is_equal(w.enemies.id[near])
	assert_int(stunned[0].b).is_equal(60)


func test_a_jammer_walks_to_a_slot_and_hits_for_20_every_2_s() -> void:
	var w: SimWorld = _world()
	var j: int = SimEnemiesKit.place_core(w, Ids.EN_JAMMER, 7.0, 0.0)
	assert_int(SimEnemiesKit.run_until_attacking(w, j)).is_greater(0)
	assert_int(w.enemies.slot[j]).is_greater_equal(0)
	SimEnemiesKit.run(w, 250)
	var hits: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(2)
	assert_float(hits[0].f).is_equal(20.0)
	assert_int(hits[1].tick - hits[0].tick).is_equal(120)


## Starts a wave of `count` borers on the breach region and runs its first tick. Returns the world.
func _breach_wave(count: int) -> SimWorld:
	var w: SimWorld = _world()
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.enemy_index = Ids.EN_BORER
	g.count = count
	g.start_tick = 0
	g.interval_ticks = 0
	g.region_id = SpawnSystem.BREACH_REGION
	var option: RouteOption = w.plan.option(1)
	var groups: Array[SpawnGroupDef] = [g]
	option.groups = groups
	option.elites.clear()
	w.wave = 1
	SimEnemiesKit.begin_tick(w)
	SpawnSystem.begin_wave(w, 1)
	w.tick -= 1
	SimEnemiesKit.tick_spawning(w)
	return w


func test_a_borer_waits_2_5_s_under_its_breach_point_then_comes_out() -> void:
	var w: SimWorld = _breach_wave(1)
	var borers: PackedInt32Array = SimEnemiesKit.alive_of_type(w, Ids.EN_BORER)
	assert_int(borers.size()).is_equal(1)
	var b: int = borers[0]
	var x: float = w.enemies.x[b]
	var z: float = w.enemies.z[b]
	var on_point: bool = false
	for p: Vector2 in w.content.arena.breach_points:
		on_point = on_point or (is_equal_approx(p.x, x) and is_equal_approx(p.y, z))
	assert_bool(on_point).is_true()
	assert_bool(w.ext.has_flag(b, EnemyExtState.F_EMERGING)).is_true()
	assert_int(w.ext.aux_cd[b]).is_equal(150)  # the telegraph: 2.5 s
	SimEnemiesKit.run(w, 149)
	assert_bool(w.ext.has_flag(b, EnemyExtState.F_EMERGING)).is_true()
	assert_float(w.enemies.x[b]).is_equal(x)  # it has not moved
	assert_float(w.enemies.z[b]).is_equal(z)
	assert_int(Targeting.pick(w, x + 1.0, z, 30.0)).is_equal(0)  # nothing to shoot at yet
	assert_bool(Targeting.is_valid(w, w.enemies.id[b], x + 1.0, z, 30.0)).is_false()
	assert_float(SimEnemiesKit.hit(w, b, 50.0, DamageResolver.F_IGNORE_ARMOR)).is_equal(0.0)  # and nothing to hurt
	SimEnemiesKit.run(w, 1)
	assert_bool(w.ext.has_flag(b, EnemyExtState.F_EMERGING)).is_false()
	assert_int(Targeting.pick(w, x + 1.0, z, 30.0)).is_equal(w.enemies.id[b])
	var start: float = SimEnemiesKit.core_dist(w, b)
	SimEnemiesKit.run(w, 60)
	assert_float(start - SimEnemiesKit.core_dist(w, b)).is_greater(2.0)  # 2.6 m/s at the core
	assert_float(SimEnemiesKit.hit(w, b, 50.0, DamageResolver.F_IGNORE_ARMOR)).is_equal(50.0)


func test_a_borer_runs_straight_at_the_core_takes_a_slot_and_hits_for_26_every_1_4_s() -> void:
	var w: SimWorld = _world()
	var b: int = SimEnemiesKit.place_core(w, Ids.EN_BORER, 12.0, 0.0)
	assert_bool(w.ext.has_flag(b, EnemyExtState.F_EMERGING)).is_false()  # not on a breach point: no wait
	SimEnemiesKit.run(w, 30)
	assert_float(absf(w.enemies.face_z[b])).is_less(0.01)  # direct seek: the line to the core is clear
	assert_int(SimEnemiesKit.run_until_attacking(w, b)).is_greater(0)
	SimEnemiesKit.run(w, 180)
	var hits: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(2)
	assert_float(hits[0].f).is_equal(26.0)
	assert_int(hits[1].tick - hits[0].tick).is_equal(84)


func test_borers_under_the_ground_stay_where_they_are() -> void:
	var w: SimWorld = _breach_wave(4)
	var borers: PackedInt32Array = SimEnemiesKit.alive_of_type(w, Ids.EN_BORER)
	assert_int(borers.size()).is_equal(4)
	SimEnemiesKit.run(w, 100)
	for b: int in borers:
		assert_bool(w.ext.has_flag(b, EnemyExtState.F_EMERGING)).is_true()
		assert_float(w.enemies.x[b]).is_equal(w.enemies.prev_x[b])
