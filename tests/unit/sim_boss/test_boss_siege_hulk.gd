extends GdUnitTestSuite
## V4-L: NODE 9 // SIEGE HULK (VARIETY_SPEC 6, CONTENT 5; briefing lines boss.siege_hulk.* and boss.hulk_plated.*).
## Every hulk: below 25% HP its attack period is -30% (150 ticks become 105). The act I stand-in of the slice has no
## variant. PLATED: armor 24, sheds plating at 66% and 33% HP (12, then 4) and walks 25% faster each time.

const TYPE: int = Ids.EN_HULK
const SLOT_X: float = VarietyLKit.CORE_X + 3.6  ## at the cage


## A hulk standing at the cage and slamming (the attack timer starts at its period).
func _slamming(w: SimWorld) -> int:
	var i: int = VarietyLKit.place(w, TYPE, SLOT_X, VarietyLKit.CORE_Z)
	w.enemies.state[i] = EnemyStore.ST_ATTACKING
	w.enemies.attack_cd[i] = w.content.enemies[TYPE].attack_period_ticks
	return i


## Metres the body covers over the next `ticks` ticks with movement.
func _walked(w: SimWorld, i: int, ticks: int) -> float:
	var from: Vector2 = Vector2(w.enemies.x[i], w.enemies.z[i])
	VarietyLKit.run_move(w, ticks)
	return Vector2(w.enemies.x[i], w.enemies.z[i]).distance_to(from)


func test_the_slice_hulk_has_no_variant_two_phases_and_no_telegraph_in_60_seconds() -> void:
	var w: SimWorld = VarietyLKit.world()
	w.plan.boss_variant = 2  # the plan always holds one; act I does not use it
	w.set_core_max(100000.0)  # a debug write: 60 s of slams would empty the real core
	w.set_core_hp(100000.0)
	var i: int = _slamming(w)
	assert_int(w.boss.boss_id).is_equal(w.enemies.id[i])
	assert_int(w.boss.variant).is_equal(BossState.NO_VARIANT)
	assert_str(String(BossSiegeHulk.variant_id(w))).is_equal("")
	assert_int(w.boss.phase_count).is_equal(2)
	VarietyLKit.run_to(w, 3600)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH).size()).is_equal(0)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_PHASE).size()).is_equal(0)
	assert_int(w.alive_count()).is_equal(1)  # no parts, no escorts
	# its slam is the plain core attack: 90 every 150 ticks, never above 20% of the core
	assert_int(VarietyLKit.core_hit_ticks(w).size()).is_equal(24)
	assert_int(VarietyLKit.core_hit_ticks(w)[0]).is_equal(150)
	for e: SimEvent in VarietyLKit.events_of(w, SimEventKind.Id.CORE_HIT):
		assert_float(e.f + e.g).is_equal(90.0)
	assert_float(BossSystem.armor_of(w, i, 12.0)).is_equal(12.0)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)


func test_below_25_percent_it_enrages_and_slams_every_105_ticks() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _slamming(w)
	assert_int(w.content.enemies[TYPE].attack_period_ticks).is_equal(150)
	VarietyLKit.run_to(w, 309)
	VarietyLKit.set_hp_frac(w, i, 0.25)
	VarietyLKit.tick(w)  # 310: at 25% it is not yet "below"
	assert_bool(w.boss.has_flag(BossState.F_ENRAGED)).is_false()
	VarietyLKit.set_hp_frac(w, i, 0.249)
	VarietyLKit.tick(w)  # 311
	assert_bool(w.boss.has_flag(BossState.F_ENRAGED)).is_true()
	assert_int(w.boss.phase).is_equal(1)
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 2)])
	assert_int(w.enemies.attack_cd[i]).is_equal(105)
	assert_int(BossSiegeHulk.enraged_period_ticks(w, i)).is_equal(105)
	VarietyLKit.run_to(w, 630)
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([150, 300, 416, 521, 626])
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 2)])


func test_the_enrage_never_lengthens_a_timer_that_is_already_short() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _slamming(w)
	VarietyLKit.run_to(w, 120)  # 30 ticks to the slam
	VarietyLKit.set_hp_frac(w, i, 0.1)
	VarietyLKit.run_to(w, 150)
	assert_array(VarietyLKit.core_hit_ticks(w)).is_equal([150])


func test_a_variant_belongs_to_the_node_9_of_the_last_act_only() -> void:
	var content: ContentSet = VarietyLKit.pool_content()
	for act: int in [1, 2, 3]:
		var w: SimWorld = VarietyLKit.world(1, content)
		w.phase_state.act = act
		w.plan.boss_variant = 1
		VarietyLKit.place(w, TYPE)
		assert_int(w.boss.variant).is_equal(1 if act == 3 else BossState.NO_VARIANT)
	var names: Array[StringName] = content.run.hulk_variants
	assert_array(names).is_equal([BossSiegeHulk.PLATED, BossSiegeHulk.FED, BossSiegeHulk.OVERCLOCKED])
	for k: int in names.size():
		var w: SimWorld = VarietyLKit.world(1, content)
		VarietyLKit.place_hulk(w, names[k])
		assert_int(w.boss.variant).is_equal(k)
		assert_str(String(BossSiegeHulk.variant_id(w))).is_equal(String(names[k]))
		assert_int(w.boss.phase_count).is_equal(4 if names[k] == BossSiegeHulk.PLATED else 2)


func test_plated_armor_24_sheds_to_12_at_66_percent_and_to_4_at_33_percent() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.PLATED)
	var base: float = w.content.enemies[TYPE].armor
	assert_float(base).is_equal(12.0)
	VarietyLKit.tick(w)
	assert_float(BossSystem.armor_of(w, i, base)).is_equal(24.0)
	VarietyLKit.set_hp_frac(w, i, 0.67)
	VarietyLKit.tick(w)
	assert_float(BossSystem.armor_of(w, i, base)).is_equal(24.0)
	VarietyLKit.set_hp_frac(w, i, 0.66)
	VarietyLKit.tick(w)
	assert_float(BossSystem.armor_of(w, i, base)).is_equal(12.0)
	assert_int(w.boss.phase).is_equal(1)
	assert_float(BossSiegeHulk.speed_mult(w)).is_equal(1.25)
	VarietyLKit.set_hp_frac(w, i, 0.33)
	VarietyLKit.tick(w)
	assert_float(BossSystem.armor_of(w, i, base)).is_equal(4.0)
	assert_int(w.boss.phase).is_equal(2)
	assert_float(BossSiegeHulk.speed_mult(w)).is_equal(1.5)
	VarietyLKit.set_hp_frac(w, i, 0.2)
	VarietyLKit.tick(w)
	assert_bool(w.boss.has_flag(BossState.F_ENRAGED)).is_true()
	assert_int(w.boss.phase).is_equal(3)
	assert_float(BossSystem.armor_of(w, i, base)).is_equal(4.0)
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)])
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH).size()).is_equal(0)


func test_plated_one_hit_through_every_threshold_ends_in_the_last_phase_with_the_plating_gone() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.PLATED)
	VarietyLKit.tick(w)
	VarietyLKit.set_hp_frac(w, i, 0.1)
	VarietyLKit.run(w, 3)
	assert_int(w.boss.phase).is_equal(3)
	assert_float(BossSystem.armor_of(w, i, 12.0)).is_equal(4.0)
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(3, 4)])


func test_plated_walks_25_percent_faster_after_each_shed() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.PLATED, 9.5, VarietyLKit.CORE_Z)
	VarietyLKit.run_move(w, 30)
	var plain: float = _walked(w, i, 60)
	assert_float(plain).is_equal_approx(0.65, 0.02)  # 1 s at 0.65 m/s
	VarietyLKit.set_hp_frac(w, i, 0.6)
	VarietyLKit.run_move(w, 12)
	assert_float(_walked(w, i, 60) / plain).is_equal_approx(1.25, 0.02)
	VarietyLKit.set_hp_frac(w, i, 0.3)
	VarietyLKit.run_move(w, 12)
	assert_float(_walked(w, i, 60) / plain).is_equal_approx(1.5, 0.02)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.ENEMY_STUCK).size()).is_equal(0)


func test_a_plain_hulk_walks_at_its_own_speed() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place(w, TYPE, 9.5, VarietyLKit.CORE_Z)
	VarietyLKit.run_move(w, 30)
	assert_float(_walked(w, i, 60)).is_equal_approx(0.65, 0.02)
	assert_float(BossSiegeHulk.speed_mult(w)).is_equal(1.0)


func test_the_extra_step_never_enters_a_prop_the_cage_or_leaves_the_yard() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = VarietyLKit.place_hulk(w, BossSiegeHulk.PLATED, 9.5, VarietyLKit.CORE_Z)
	VarietyLKit.set_hp_frac(w, i, 0.3)
	var arena: ArenaDef = w.content.arena
	var clear: float = w.nav.t_clear[TYPE]
	for _n: int in 1500:
		VarietyLKit.tick_move(w)
		assert_bool(NavGeometry.inside_any(arena.obstacles, w.enemies.x[i], w.enemies.z[i], clear - 0.01)).is_false()
		assert_float(VarietyLKit.dist_to_core(w, i)).is_greater_equal(arena.core_radius + clear - 0.01)
		assert_float(w.enemies.x[i]).is_between(w.nav.bound_min_x, w.nav.bound_max_x)
	assert_int(w.enemies.state[i]).is_equal(EnemyStore.ST_ATTACKING)  # it arrived and took its slot
	assert_int(w.enemies.slot[i]).is_greater_equal(0)
