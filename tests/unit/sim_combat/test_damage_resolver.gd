extends GdUnitTestSuite
## DamageResolver.hit: ARCH 6.5 golden values, hp clamp, exactly-once kills and Scrap (A09).
## Baseline armor: Skitter 0, Hollow 8, Rusher 2, Hulk 12. armor_piercing 0.15 per level, cap 0.9.


func _hit(w: SimWorld, index: int, base: float, damage_level: int = 0, source: int = DamageSource.Id.WARDEN) -> float:
	return DamageResolver.hit(w, index, base, damage_level, source)


func test_golden_hits_against_each_armor() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hollow: int = CombatTestKit.place(w, Ids.EN_HOLLOW, 5.0, 0.0)
	var hulk: int = CombatTestKit.place(w, Ids.EN_HULK, 5.0, 1.0)
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 2.0)
	var rusher: int = CombatTestKit.place(w, Ids.EN_RUSHER, 5.0, 3.0)
	assert_float(_hit(w, hollow, 30.0)).is_equal(22.0)  # 30 - 8
	assert_float(w.enemies.hp[hollow]).is_equal(128.0)
	assert_float(_hit(w, hulk, 15.0)).is_equal(3.0)  # SMG round vs armor 12
	assert_float(_hit(w, hulk, 12.0)).is_equal(1.0)  # turret round vs armor 12: floor of 1 applies
	assert_float(w.enemies.hp[hulk]).is_equal(2796.0)
	assert_float(_hit(w, skitter, 30.0)).is_equal(30.0)
	assert_float(w.enemies.hp[skitter]).is_equal(15.0)
	assert_float(_hit(w, rusher, 30.0)).is_equal(28.0)  # 30 - 2


func test_damage_level_scales_the_base_damage_before_armor() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hollow: int = CombatTestKit.place(w, Ids.EN_HOLLOW, 5.0, 0.0)
	CombatTestKit.make_tough(w, hollow)
	assert_float(_hit(w, hollow, 30.0, 3)).is_equal_approx(40.0, 0.000001)  # 30 x 1.6 - 8
	assert_float(_hit(w, hollow, 30.0, 5)).is_equal_approx(52.0, 0.000001)  # 30 x 2.0 - 8
	assert_float(_hit(w, hollow, 15.0, 5)).is_equal_approx(22.0, 0.000001)  # SMG: 15 x 2.0 - 8


func test_armor_piercing_levels_reduce_armor_with_a_90_percent_cap() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hulk: int = CombatTestKit.place(w, Ids.EN_HULK, 5.0, 0.0)
	CombatTestKit.make_tough(w, hulk)
	assert_float(_hit(w, hulk, 30.0)).is_equal(18.0)
	w.upgrade_levels[Ids.UP_ARMOR_PIERCING] = 5  # 12 x (1 - 0.75) = 3.0
	assert_float(_hit(w, hulk, 30.0)).is_equal_approx(27.0, 0.000001)
	w.upgrade_levels[Ids.UP_ARMOR_PIERCING] = 6  # capped at 0.9: 12 x 0.1 = 1.2
	assert_float(_hit(w, hulk, 30.0)).is_equal_approx(28.8, 0.000001)
	w.upgrade_levels[Ids.UP_ARMOR_PIERCING] = 9  # still capped
	assert_float(_hit(w, hulk, 30.0)).is_equal_approx(28.8, 0.000001)


func test_every_hit_deals_at_least_one() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hulk: int = CombatTestKit.place(w, Ids.EN_HULK, 5.0, 0.0)
	assert_float(_hit(w, hulk, 1.0)).is_equal(1.0)
	assert_float(_hit(w, hulk, 0.0)).is_equal(1.0)


func test_hp_never_goes_below_zero_and_overkill_reports_only_the_hp_left() -> void:
	var w: SimWorld = CombatTestKit.world()
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0)
	var dealt: float = _hit(w, skitter, 500.0)
	assert_float(dealt).is_equal(45.0)
	assert_int(w.stats.kills_by_type[Ids.EN_SKITTER]).is_equal(1)
	var damaged: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.ENEMY_DAMAGED)
	assert_int(damaged.size()).is_equal(1)
	assert_float(damaged[0].f).is_equal(45.0)
	assert_float(damaged[0].g).is_equal(0.0)  # hp after, never negative
	assert_int(w.alive_count()).is_equal(0)


func test_an_exact_kill_removes_the_enemy_and_pays_by_type() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hollow: int = CombatTestKit.place(w, Ids.EN_HOLLOW, 5.0, 0.0)
	w.enemies.hp[hollow] = 22.0
	assert_float(_hit(w, hollow, 30.0)).is_equal(22.0)
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.scrap).is_equal(35)


func test_overkill_pays_scrap_once_when_a_second_hit_lands_on_the_dead_slot() -> void:
	var w: SimWorld = CombatTestKit.world()
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0)
	w.enemies.hp[skitter] = 10.0
	assert_float(_hit(w, skitter, 30.0, 0, DamageSource.Id.WARDEN)).is_equal(10.0)
	assert_float(_hit(w, skitter, 12.0, 0, DamageSource.Id.TURRET_0)).is_equal(0.0)
	assert_int(w.scrap).is_equal(20)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.ENEMY_KILLED)).is_equal(1)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.ENEMY_DAMAGED)).is_equal(1)
	assert_int(w.stats.kills_by_type[Ids.EN_SKITTER]).is_equal(1)
	assert_int(w.stats.scrap_earned).is_equal(20)


func test_two_sources_killing_on_the_same_tick_pay_scrap_once() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	var skitter: int = CombatTestKit.place_abs(
		w, Ids.EN_SKITTER, w.turrets.x[0] + 5.0, w.turrets.z[0], EnemyStore.ST_ATTACKING, 0.0
	)
	var skitter_id: int = w.enemies.id[skitter]
	w.enemies.hp[skitter] = 10.0
	CombatTestKit.turret_tick(w)  # the turret locks the Skitter (its accumulator is still short of a shot)
	assert_int(w.turrets.target_id[0]).is_equal(skitter_id)
	# Both shooters are now loaded and either shot would kill it; the Warden goes first within the tick.
	w.warden.fire_acc_milli = CombatTestKit.MILLI_PER_SHOT
	w.turrets.fire_acc_milli[0] = CombatTestKit.MILLI_PER_SHOT
	CombatTestKit.begin_tick(w)
	WeaponSystem.step(w)
	TurretSystem.step(w)
	assert_int(w.scrap).is_equal(20)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.ENEMY_KILLED)).is_equal(1)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(1)  # the turret does not shoot a corpse
	assert_int(w.turrets.target_id[0]).is_equal(0)
	assert_int(w.stats.kills_by_type[Ids.EN_SKITTER]).is_equal(1)
	assert_int(w.stats.scrap_earned).is_equal(20)


func test_debug_damage_mult_scales_the_hit_after_armor() -> void:
	var w: SimWorld = CombatTestKit.world()
	w.config.debug_damage_mult = 2.0
	var hollow: int = CombatTestKit.place(w, Ids.EN_HOLLOW, 5.0, 0.0)
	assert_float(_hit(w, hollow, 30.0)).is_equal(44.0)  # (30 - 8) x 2
	assert_float(w.enemies.hp[hollow]).is_equal(106.0)


func test_enemy_damaged_event_payload() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hollow: int = CombatTestKit.place(w, Ids.EN_HOLLOW, 5.0, 0.0)
	_hit(w, hollow, 30.0, 0, DamageSource.Id.TURRET_1)
	var damaged: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.ENEMY_DAMAGED)
	assert_int(damaged.size()).is_equal(1)
	assert_int(damaged[0].a).is_equal(w.enemies.id[hollow])
	assert_int(damaged[0].b).is_equal(DamageSource.Id.TURRET_1)
	assert_float(damaged[0].f).is_equal(22.0)
	assert_float(damaged[0].g).is_equal(128.0)


func test_the_kill_event_follows_the_damage_event_and_carries_the_source() -> void:
	var w: SimWorld = CombatTestKit.world()
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0)
	w.enemies.hp[skitter] = 5.0
	_hit(w, skitter, 30.0, 0, DamageSource.Id.TURRET_1)
	var kinds: PackedInt32Array = PackedInt32Array()
	for e: SimEvent in w.events.peek():
		if e.kind == SimEventKind.Id.ENEMY_DAMAGED or e.kind == SimEventKind.Id.ENEMY_KILLED:
			kinds.append(e.kind)
	assert_int(kinds.size()).is_equal(2)
	assert_int(kinds[0]).is_equal(SimEventKind.Id.ENEMY_DAMAGED)
	assert_int(kinds[1]).is_equal(SimEventKind.Id.ENEMY_KILLED)
	assert_int(CombatTestKit.events_of(w, SimEventKind.Id.ENEMY_KILLED)[0].b).is_equal(DamageSource.Id.TURRET_1)


func test_invalid_or_dead_indices_do_nothing() -> void:
	var w: SimWorld = CombatTestKit.world()
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 5.0, 0.0)
	assert_float(_hit(w, -1, 30.0)).is_equal(0.0)
	assert_float(_hit(w, w.enemies.capacity, 30.0)).is_equal(0.0)
	assert_float(_hit(w, skitter + 1, 30.0)).is_equal(0.0)  # an empty slot
	assert_int(w.events.peek().size()).is_equal(1)  # only the spawn event


func test_combat_state_tallies_damage_and_kills_per_source() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hollow: int = CombatTestKit.place(w, Ids.EN_HOLLOW, 5.0, 0.0)
	var skitter: int = CombatTestKit.place(w, Ids.EN_SKITTER, 6.0, 0.0)
	_hit(w, hollow, 30.0, 0, DamageSource.Id.WARDEN)
	_hit(w, skitter, 100.0, 0, DamageSource.Id.TURRET_1)
	assert_float(w.combat.damage_by_source[DamageSource.Id.WARDEN]).is_equal(22.0)
	assert_float(w.combat.damage_by_source[DamageSource.Id.TURRET_1]).is_equal(45.0)
	assert_int(w.combat.kills_by_source[DamageSource.Id.TURRET_1]).is_equal(1)
	assert_int(w.combat.kills_by_source[DamageSource.Id.WARDEN]).is_equal(0)
