extends GdUnitTestSuite
## The combat systems together, stepped in SimWorld.step order (Warden, turrets, core attacks) on hand-placed
## enemies: kill order, dead attackers, Scrap bookkeeping, determinism and hashing.


func _crowd(w: SimWorld, count: int) -> void:
	for n: int in count:
		var angle: float = float(n) * 0.7
		var radius: float = 6.0 + float(n % 7) * 2.0
		var type_index: int = n % 4
		var state: int = EnemyStore.ST_ATTACKING if n % 5 == 0 else EnemyStore.ST_MOVING
		var i: int = CombatTestKit.place(w, type_index, cos(angle) * radius, sin(angle) * radius, state, float(n) * 1.5)
		w.enemies.attack_cd[i] = 30 + n


func _kill_order(w: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for e: SimEvent in CombatTestKit.events_of(w, SimEventKind.Id.ENEMY_KILLED):
		out.append(e.a)
	return out


func test_the_warden_kills_in_priority_order() -> void:
	var w: SimWorld = CombatTestKit.world()
	var slow_close: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0, EnemyStore.ST_MOVING, 30.0)
	var attacker: int = CombatTestKit.place(w, Ids.EN_SKITTER, 20.0, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	var soon: int = CombatTestKit.place(w, Ids.EN_SKITTER, 12.0, 0.0, EnemyStore.ST_MOVING, 5.0)
	w.enemies.attack_cd[attacker] = 100000  # keep the core out of this test
	var ids: PackedInt32Array = PackedInt32Array(
		[w.enemies.id[attacker], w.enemies.id[soon], w.enemies.id[slow_close]]
	)
	CombatTestKit.run_warden(w, 600)
	var order: PackedInt32Array = _kill_order(w)
	assert_int(order.size()).is_equal(3)
	for k: int in 3:
		assert_int(order[k]).is_equal(ids[k])
	assert_int(w.scrap).is_equal(60)
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.warden.target_id).is_equal(0)


func test_a_dead_attacker_never_hits_the_core() -> void:
	var w: SimWorld = CombatTestKit.world()
	var a: int = _attacker(w, 5.0)
	var b: int = _attacker(w, 8.0)
	var c: int = _attacker(w, 12.0)
	var ids: PackedInt32Array = PackedInt32Array([w.enemies.id[a], w.enemies.id[b], w.enemies.id[c]])
	CombatTestKit.run_combat(w, 200)
	# Warden kills: A at tick 60, B at 120, C at 180. Cores hits at tick 90 only: B and C (A is dead).
	var kills: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.ENEMY_KILLED)
	assert_int(kills.size()).is_equal(3)
	assert_int(kills[0].tick).is_equal(60)
	assert_int(kills[1].tick).is_equal(120)
	assert_int(kills[2].tick).is_equal(180)
	var hits: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(2)
	assert_int(hits[0].tick).is_equal(90)
	assert_int(hits[0].a).is_equal(ids[1])
	assert_int(hits[1].a).is_equal(ids[2])
	assert_float(w.core_hp).is_equal(976.0)


func _attacker(w: SimWorld, dx: float) -> int:
	var i: int = CombatTestKit.place(w, Ids.EN_SKITTER, dx, 0.0, EnemyStore.ST_ATTACKING, 0.0)
	w.enemies.attack_cd[i] = 90
	return i


func test_scrap_is_paid_once_per_kill_across_all_sources() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	CombatTestKit.activate_turret(w, 1)
	_crowd(w, 24)
	var spawned: int = w.alive_count()
	var expected_scrap: int = 0
	for i: int in w.enemies.high_water:
		expected_scrap += w.content.enemies[w.enemies.type[i]].scrap
	w.config.debug_damage_mult = 20.0  # make the crowd die within the run
	w.config.debug_invulnerable_core = true
	CombatTestKit.run_combat(w, 3000)
	assert_int(w.alive_count()).is_equal(0)
	var order: PackedInt32Array = _kill_order(w)
	assert_int(order.size()).is_equal(spawned)
	var seen: Dictionary[int, bool] = {}
	for enemy_id: int in order:
		assert_bool(seen.has(enemy_id)).is_false()
		seen[enemy_id] = true
	assert_int(w.scrap).is_equal(expected_scrap)
	assert_int(w.stats.scrap_earned).is_equal(expected_scrap)
	var total_kills: int = 0
	for k: int in w.stats.kills_by_type:
		total_kills += k
	assert_int(total_kills).is_equal(spawned)
	var by_source: int = 0
	for k: int in w.combat.kills_by_source:
		by_source += k
	assert_int(by_source).is_equal(spawned)


func test_enemy_hp_stays_within_zero_and_max_under_sustained_fire() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	CombatTestKit.activate_turret(w, 1)
	_crowd(w, 30)
	w.config.debug_invulnerable_core = true
	var in_bounds: bool = true
	for n: int in 1500:
		CombatTestKit.combat_tick(w)
		for i: int in w.enemies.high_water:
			if w.enemies.alive[i] == 1 and not (w.enemies.hp[i] > 0.0 and w.enemies.hp[i] <= w.enemies.max_hp[i]):
				in_bounds = false
	assert_bool(in_bounds).is_true()
	assert_float(w.combat.damage_by_source[DamageSource.Id.WARDEN]).is_greater(0.0)
	assert_float(w.combat.damage_by_source[DamageSource.Id.TURRET_0]).is_greater(0.0)


func test_two_identical_worlds_stay_identical() -> void:
	var a: SimWorld = CombatTestKit.world(5)
	var b: SimWorld = CombatTestKit.world(5)
	var worlds: Array[SimWorld] = [a, b]
	for w: SimWorld in worlds:
		CombatTestKit.activate_turret(w, 0)
		_crowd(w, 24)
		w.upgrade_levels[Ids.UP_DAMAGE] = 2
		w.upgrade_levels[Ids.UP_ARMOR_PIERCING] = 1
	CombatTestKit.run_combat(a, 1800)
	CombatTestKit.run_combat(b, 1800)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.events.event_hash).is_equal(b.events.event_hash)
	assert_int(a.events.total).is_equal(b.events.total)
	assert_int(a.scrap).is_equal(b.scrap)
	assert_float(a.core_hp).is_equal(b.core_hp)


func test_a_different_setup_gives_a_different_outcome() -> void:
	var a: SimWorld = CombatTestKit.world(5)
	var b: SimWorld = CombatTestKit.world(5)
	_crowd(a, 24)
	_crowd(b, 24)
	b.upgrade_levels[Ids.UP_DAMAGE] = 3
	CombatTestKit.run_combat(a, 900)
	CombatTestKit.run_combat(b, 900)
	assert_bool(a.state_hash() != b.state_hash()).is_true()


func test_combat_state_is_part_of_the_state_hash() -> void:
	var w: SimWorld = CombatTestKit.world()
	var h0: String = w.state_hash()
	w.combat.core_hits += 1
	var h1: String = w.state_hash()
	w.combat.shots_by_source[DamageSource.Id.TURRET_1] += 1
	var h2: String = w.state_hash()
	w.combat.damage_by_source[DamageSource.Id.WARDEN] += 0.5
	var h3: String = w.state_hash()
	w.combat.kills_by_source[DamageSource.Id.TURRET_0] += 1
	var h4: String = w.state_hash()
	assert_bool(h0 != h1 and h1 != h2 and h2 != h3 and h3 != h4).is_true()
