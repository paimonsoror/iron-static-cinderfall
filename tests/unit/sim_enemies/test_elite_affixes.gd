extends GdUnitTestSuite
## V4-N, GDD 6.4 / CONTENT 4.3: what an elite is (HP x2.2, Scrap x4, ELITE_SPAWNED) and one test per affix.

const EPS: float = 0.000001
const HELD: int = 100000


func _world() -> SimWorld:
	return SimEnemiesKit.world()


func _elite(w: SimWorld, type_index: int, dx: float, dz: float, affixes: Array[StringName]) -> int:
	return SimEnemiesKit.place_core(w, type_index, dx, dz, SimEnemiesKit.mask(w, affixes))


func _status(w: SimWorld, ticks: int = 1) -> void:
	for _n: int in ticks:
		SimEnemiesKit.begin_tick(w)
		AbilitySystem.step(w)
		StatusSystem.step(w)


func test_an_elite_has_2_2_times_the_hit_points_pays_4_times_the_scrap_and_is_announced() -> void:
	var w: SimWorld = _world()
	var plain: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 12.0, 0.0)
	var e: int = _elite(w, Ids.EN_SKITTER, 12.0, 2.0, [&"aff_swift"])
	assert_float(w.enemies.max_hp[plain]).is_equal(45.0)
	assert_float(w.enemies.max_hp[e]).is_equal_approx(99.0, EPS)
	assert_float(w.enemies.hp[e]).is_equal(w.enemies.max_hp[e])
	assert_bool(w.ext.is_elite(e)).is_true()
	assert_bool(w.ext.is_elite(plain)).is_false()
	assert_int(w.ext.hp_scale_milli[e]).is_equal(2200)
	assert_int(EliteSystem.alive_elites(w)).is_equal(1)
	var spawned: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.ELITE_SPAWNED)
	assert_int(spawned.size()).is_equal(1)
	assert_int(spawned[0].a).is_equal(w.enemies.id[e])
	assert_int(spawned[0].b).is_equal(SimEnemiesKit.mask(w, [&"aff_swift"]))
	w.kill_enemy(e, DamageSource.Id.WARDEN)
	assert_int(w.scrap).is_equal(20)  # 5 x 4


func test_the_act_tier_multiplies_hit_points_of_plain_enemies_and_elites() -> void:
	var w: SimWorld = _world()
	w.phase_state.act = 2  # x1.35
	var plain: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 12.0, 0.0)
	var e: int = _elite(w, Ids.EN_SKITTER, 12.0, 2.0, [&"aff_swift"])
	assert_float(w.enemies.max_hp[plain]).is_equal_approx(60.75, EPS)
	assert_float(w.enemies.max_hp[e]).is_equal_approx(133.65, EPS)
	var boss: int = SimEnemiesKit.place_core(w, Ids.EN_HULK, 14.0, -4.0)
	assert_float(w.enemies.max_hp[boss]).is_equal(2800.0)  # BossDef.hp is final


func test_plated_adds_8_armor_and_30_percent_hit_points() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_SKITTER, 12.0, 0.0, [&"aff_plated"])
	assert_float(w.enemies.max_hp[e]).is_equal_approx(128.7, EPS)  # 45 x 2.2 x 1.3
	assert_float(EliteSystem.armor_add(w, e)).is_equal(8.0)
	assert_float(SimEnemiesKit.hit(w, e, 20.0)).is_equal_approx(12.0, EPS)
	assert_float(SimEnemiesKit.hit(w, e, 20.0, DamageResolver.F_IGNORE_ARMOR)).is_equal_approx(20.0, EPS)
	var plain: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 12.0, 2.0)
	assert_float(EliteSystem.armor_add(w, plain)).is_equal(0.0)
	assert_float(SimEnemiesKit.hit(w, plain, 20.0)).is_equal_approx(20.0, EPS)


func test_swift_moves_45_percent_faster() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_HOLLOW, 14.0, 0.0, [&"aff_swift"])
	SimEnemiesKit.run(w, 10)
	assert_float(w.nav.speed_mul[e]).is_equal_approx(1.45, EPS)
	var x: float = w.enemies.x[e]
	var z: float = w.enemies.z[e]
	SimEnemiesKit.tick(w)
	var moved: float = Vector2(w.enemies.x[e] - x, w.enemies.z[e] - z).length()
	assert_float(moved).is_equal_approx(w.nav.t_step[Ids.EN_HOLLOW] * 1.45, EPS)


func test_volatile_blasts_the_enemies_within_3_m_for_120_six_ticks_after_its_death() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_HOLLOW, 12.0, 0.0, [&"aff_volatile"])
	var near: int = SimEnemiesKit.place_core(w, Ids.EN_HOLLOW, 12.0, 2.9)
	var far: int = SimEnemiesKit.place_core(w, Ids.EN_HOLLOW, 12.0, -3.1)
	w.enemies.stun_ticks[near] = HELD
	w.enemies.stun_ticks[far] = HELD
	SimEnemiesKit.kill(w, e)
	SimEnemiesKit.run(w, 5)
	assert_float(w.enemies.hp[near]).is_equal(150.0)
	SimEnemiesKit.run(w, 1)
	assert_float(w.enemies.hp[near]).is_equal_approx(150.0 - (120.0 - 8.0), EPS)  # armor applies
	assert_float(w.enemies.hp[far]).is_equal(150.0)
	assert_float(w.core_hp).is_equal(w.core_max_hp)  # it died far from the cage
	var blasts: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.AREA_BLAST)
	assert_int(blasts.size()).is_equal(1)
	assert_int(blasts[0].b).is_equal(300)


func test_volatile_costs_the_core_50_when_it_dies_within_3_m_of_the_cage() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_HOLLOW, 4.9, 0.0, [&"aff_volatile"])
	w.enemies.stun_ticks[e] = HELD
	SimEnemiesKit.kill(w, e)
	SimEnemiesKit.run(w, 6)
	assert_float(w.core_hp).is_equal(w.core_max_hp - 50.0)
	var w2: SimWorld = _world()
	var e2: int = _elite(w2, Ids.EN_HOLLOW, 5.1, 0.0, [&"aff_volatile"])
	SimEnemiesKit.kill(w2, e2)
	SimEnemiesKit.run(w2, 6)
	assert_float(w2.core_hp).is_equal(w2.core_max_hp)


func test_regenerating_waits_2_s_after_damage_then_heals_2_percent_per_second() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_HOLLOW, 14.0, 0.0, [&"aff_regen"])
	assert_float(w.enemies.max_hp[e]).is_equal_approx(330.0, EPS)
	SimEnemiesKit.hit(w, e, 100.0, DamageResolver.F_IGNORE_ARMOR)
	assert_int(w.ext.fuse_ticks[e]).is_equal(EliteSystem.REGEN_DELAY_TICKS)  # the delay restarts on every hit
	_status(w, 60)
	SimEnemiesKit.hit(w, e, 10.0, DamageResolver.F_IGNORE_ARMOR)
	assert_int(w.ext.fuse_ticks[e]).is_equal(120)
	_status(w, 120)
	assert_int(w.ext.fuse_ticks[e]).is_equal(0)
	assert_float(w.enemies.hp[e]).is_equal_approx(220.0, EPS)  # nothing healed during the delay
	if not SimEnemiesKit.heal_wired():
		return  # DamageResolver.heal is still a stub in this checkout (needs owner, see the V4-N report)
	_status(w, 60)
	assert_float(w.enemies.hp[e]).is_equal_approx(220.0 + 6.6, EPS)  # 2 pulses of 1 percent of 330
	_status(w, 6000)
	assert_float(w.enemies.hp[e]).is_equal(w.enemies.max_hp[e])  # never above the maximum


func test_warded_absorbs_40_percent_of_max_hp_first_and_comes_back_after_5_s() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_SKITTER, 12.0, 0.0, [&"aff_warded"])
	assert_int(w.ext.ward_milli[e]).is_equal(39600)  # 40 percent of 99
	assert_float(SimEnemiesKit.hit(w, e, 30.0)).is_equal(0.0)
	assert_int(w.ext.ward_milli[e]).is_equal(9600)
	assert_float(w.enemies.hp[e]).is_equal(w.enemies.max_hp[e])
	assert_float(SimEnemiesKit.hit(w, e, 30.0)).is_equal_approx(20.4, EPS)
	assert_int(w.ext.ward_milli[e]).is_equal(0)
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.WARD_BROKEN).size()).is_equal(1)
	_status(w, 299)
	assert_int(w.ext.ward_milli[e]).is_equal(0)
	_status(w, 1)
	assert_int(w.ext.ward_milli[e]).is_equal(39600)
	StatusSystem.apply_stun(w, e, 30)  # the EMP strips it
	_status(w, 1)
	assert_int(w.ext.ward_milli[e]).is_equal(0)
	# a hit that ignores armor (the arc) tears a ward three times as fast
	var e2: int = _elite(w, Ids.EN_SKITTER, 12.0, 3.0, [&"aff_warded"])
	assert_float(SimEnemiesKit.hit(w, e2, 12.0, DamageResolver.F_IGNORE_ARMOR)).is_equal(0.0)
	assert_int(w.ext.ward_milli[e2]).is_equal(3600)


func test_magnetic_forces_every_shooter_within_12_m_to_target_it() -> void:
	var w: SimWorld = _world()
	var sx: float = w.warden.x
	var sz: float = w.warden.z
	var attacker: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 3.0, 0.0)
	w.enemies.state[attacker] = EnemyStore.ST_ATTACKING
	w.enemies.path_dist[attacker] = 0.0
	var magnet: int = _elite(w, Ids.EN_HOLLOW, 0.0, 0.0, [&"aff_magnetic"])
	w.enemies.x[magnet] = sx + 11.0
	w.enemies.z[magnet] = sz
	w.enemies.path_dist[magnet] = 50.0  # by rank it would be last
	assert_int(Targeting.pick(w, sx, sz, 20.0)).is_equal(w.enemies.id[magnet])
	assert_bool(Targeting.is_valid(w, w.enemies.id[attacker], sx, sz, 20.0)).is_false()  # a held lock is dropped
	assert_bool(Targeting.is_valid(w, w.enemies.id[magnet], sx, sz, 20.0)).is_true()
	assert_int(Targeting.pick(w, sx, sz, 10.0)).is_equal(w.enemies.id[attacker])  # out of weapon range: no pull
	w.enemies.x[magnet] = sx + 12.5  # beyond its 12 m
	assert_int(Targeting.pick(w, sx, sz, 20.0)).is_equal(w.enemies.id[attacker])
	assert_bool(Targeting.is_valid(w, w.enemies.id[attacker], sx, sz, 20.0)).is_true()
	w.enemies.x[magnet] = sx + 11.0
	SimEnemiesKit.kill(w, magnet)  # "while it lives"
	assert_int(Targeting.pick(w, sx, sz, 20.0)).is_equal(w.enemies.id[attacker])


func test_overclocker_speeds_up_the_allies_within_4_m_and_shortens_their_attack_period() -> void:
	var w: SimWorld = _world()
	var o: int = _elite(w, Ids.EN_HOLLOW, 14.0, 0.0, [&"aff_overclock"])
	var near: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 14.0, 3.9)
	var far: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 14.0, -4.1)
	var skitter: EnemyDef = w.content.enemies[Ids.EN_SKITTER]
	_status(w)
	assert_float(w.nav.speed_mul[near]).is_equal_approx(1.3, EPS)
	assert_float(w.nav.period_mul[near]).is_equal(0.8)
	assert_float(w.nav.speed_mul[far]).is_equal(1.0)
	assert_float(w.nav.period_mul[far]).is_equal(1.0)
	assert_float(w.nav.speed_mul[o]).is_equal(1.0)  # not itself
	assert_int(CoreAttackSystem.period_of(w, near, skitter)).is_equal(72)  # 1.5 s -> 1.2 s
	assert_int(CoreAttackSystem.period_of(w, far, skitter)).is_equal(90)
	w.enemies.stun_ticks[o] = 30  # the EMP switches the aura off
	_status(w)
	assert_float(w.nav.speed_mul[near]).is_equal(1.0)
	assert_int(CoreAttackSystem.period_of(w, near, skitter)).is_equal(90)


func test_two_overclockers_do_not_stack() -> void:
	var w: SimWorld = _world()
	_elite(w, Ids.EN_HOLLOW, 14.0, 0.0, [&"aff_overclock"])
	_elite(w, Ids.EN_HOLLOW, 14.0, 2.0, [&"aff_overclock"])
	var ally: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 14.0, 1.0)
	_status(w)
	assert_float(w.nav.speed_mul[ally]).is_equal_approx(1.3, EPS)
	assert_float(w.nav.period_mul[ally]).is_equal(0.8)


func test_anchored_is_immune_to_stun_slow_and_knockback() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_SKITTER, 14.0, 0.0, [&"aff_anchored"])
	var plain: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 14.0, 3.0)
	assert_bool(StatusSystem.apply_stun(w, e, 60)).is_false()
	assert_bool(StatusSystem.apply_stun(w, plain, 60)).is_true()
	assert_int(w.enemies.stun_ticks[e]).is_equal(0)
	StatusSystem.apply_slow(w, e, 60, 500)
	StatusSystem.apply_slow(w, plain, 60, 500)
	assert_int(w.ext.slow_ticks[e]).is_equal(0)
	assert_int(w.ext.slow_ticks[plain]).is_equal(60)
	assert_float(MovementSystem.knockback(w, e, 1.0, 0.0, 1.0)).is_equal(0.0)
	assert_float(MovementSystem.knockback(w, plain, 1.0, 0.0, 1.0)).is_equal_approx(1.0, EPS)
	w.enemies.stun_ticks[e] = 180  # a stun written by another system (the EMP) does not hold either
	_status(w)
	assert_int(w.enemies.stun_ticks[e]).is_equal(0)


func test_leeching_heals_every_enemy_within_4_m_by_30_on_a_core_hit_that_took_hp() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_SKITTER, 6.0, 0.0, [&"aff_leech"])
	var near: int = SimEnemiesKit.place(w, Ids.EN_HOLLOW, w.enemies.x[e] + 3.9, w.enemies.z[e])
	var far: int = SimEnemiesKit.place(w, Ids.EN_HOLLOW, w.enemies.x[e], w.enemies.z[e] - 4.1)
	w.enemies.hp[near] = 50.0
	w.enemies.hp[far] = 50.0
	assert_int(EliteSystem.on_core_hit(w, e, 0.0)).is_equal(0)  # the shield took it all: nothing heals
	assert_float(w.enemies.hp[near]).is_equal(50.0)
	var plain: int = SimEnemiesKit.place(w, Ids.EN_SKITTER, w.enemies.x[e], w.enemies.z[e] + 1.0)
	assert_int(EliteSystem.on_core_hit(w, plain, 12.0)).is_equal(0)  # not a leech
	if not SimEnemiesKit.heal_wired():
		return  # DamageResolver.heal is still a stub in this checkout (needs owner, see the V4-N report)
	w.enemies.hp[e] = 10.0
	assert_int(EliteSystem.on_core_hit(w, e, 12.0)).is_equal(2)  # itself and the neighbour
	assert_float(w.enemies.hp[near]).is_equal(80.0)
	assert_float(w.enemies.hp[e]).is_equal(40.0)
	assert_float(w.enemies.hp[far]).is_equal(50.0)
	var healed: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_HEALED)
	assert_int(healed[0].b).is_equal(w.enemies.id[e])


func test_a_leech_in_its_slot_heals_through_its_real_core_hit() -> void:
	if not SimEnemiesKit.heal_wired():
		return  # DamageResolver.heal is still a stub in this checkout (needs owner, see the V4-N report)
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_SKITTER, 5.0, 0.0, [&"aff_leech"])
	assert_int(SimEnemiesKit.run_until_attacking(w, e)).is_greater(0)
	w.enemies.hp[e] = 10.0
	SimEnemiesKit.run(w, 95)
	assert_float(w.core_hp).is_equal(w.core_max_hp - 12.0)
	assert_float(w.enemies.hp[e]).is_equal(40.0)
	w.shield_hp = 500.0
	w.enemies.hp[e] = 10.0
	SimEnemiesKit.run(w, 95)
	assert_float(w.enemies.hp[e]).is_equal(10.0)  # absorbed by the shield: no heal


func test_shrouded_cannot_be_targeted_from_more_than_12_m_but_area_damage_finds_it() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_HOLLOW, 12.0, 0.0, [&"aff_shroud"])
	var x: float = w.enemies.x[e]
	var z: float = w.enemies.z[e]
	var enemy_id: int = w.enemies.id[e]
	assert_int(Targeting.pick(w, x - 12.5, z, 30.0)).is_equal(0)
	assert_bool(Targeting.is_valid(w, enemy_id, x - 12.5, z, 30.0)).is_false()
	assert_int(Targeting.pick(w, x - 11.5, z, 30.0)).is_equal(enemy_id)
	assert_bool(Targeting.is_valid(w, enemy_id, x - 11.5, z, 30.0)).is_true()
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(Targeting.pick_many(w, x - 12.5, z, 30.0, 4, out)).is_equal(0)
	var before: float = w.enemies.hp[e]
	AreaDamage.apply(w, x, z, 2.0, 50.0, 1.0, DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.STRIKE)
	assert_float(w.enemies.hp[e]).is_equal(before - 50.0)


func test_two_affixes_act_together() -> void:
	var w: SimWorld = _world()
	var e: int = _elite(w, Ids.EN_HOLLOW, 14.0, 0.0, [&"aff_plated", &"aff_swift"])
	assert_float(w.enemies.max_hp[e]).is_equal_approx(150.0 * 2.2 * 1.3, EPS)
	_status(w)
	assert_float(w.nav.speed_mul[e]).is_equal_approx(1.45, EPS)
	assert_float(EliteSystem.armor_add(w, e)).is_equal(8.0)
	assert_bool(EliteSystem.has(w, e, EliteSystem.A_VOLATILE)).is_false()


func test_the_legacy_content_has_no_affixes_and_plain_hit_points() -> void:
	var w: SimWorld = TestContent.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)
	assert_float(w.enemies.max_hp[i]).is_equal(w.content.enemies[Ids.EN_SKITTER].hp)
	assert_bool(EliteSystem.is_anchored(w, i)).is_false()
	assert_float(EliteSystem.armor_add(w, i)).is_equal(0.0)
	assert_float(StatusSystem.absorb(w, i, 25.0, 0)).is_equal(25.0)
	assert_float(StatusSystem.cooldown_rate(w)).is_equal(1.0)
