extends GdUnitTestSuite
## V4-V: the directive rules of the auto turrets (CONTENT 3): sentry_link (t_inherit), overwatch, range_mul,
## last_stand_protocol and mine_layer, as TurretSystem and EventRates apply them. Pad 0 stands at (-2.5, -1.5) and hits for 15
## (V5-C: was 12).

const TURRET_DAMAGE: float = 15.0


func _pad(w: SimWorld) -> void:
	w.turrets.active[0] = 1


func _shots(w: SimWorld) -> int:
	return w.combat.shots_by_source[DamageSource.Id.TURRET_0]


func _run_until_shots(w: SimWorld, shots: int) -> void:
	for _n: int in 800:
		if _shots(w) >= shots:
			return
		VarietyVKit.tick(w)


# --- sentry_link ---


func test_sentry_link_gives_the_turrets_half_of_the_wardens_directive_levels_rounded_down() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"sentry_link": 1, &"hot_loads": 5, &"cyclic_tuning": 3})
	assert_float(w.mods.t_inherit).is_equal(0.5)
	assert_int(TurretRules.damage_level(w)).is_equal(2)  # floor(0.5 x 5)
	assert_int(TurretRules.rate_level(w)).is_equal(1)  # floor(0.5 x 3)
	var rate_up: UpgradeDef = w.content.upgrades[Ids.UP_FIRE_RATE]
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(roundi(1000.0 * (1.0 + rate_up.per_level)))
	_pad(w)
	var target: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -1.5)
	VarietyVKit.tough(w, target)
	_run_until_shots(w, 1)
	var damage_up: UpgradeDef = w.content.upgrades[Ids.UP_DAMAGE]
	assert_float(VarietyVKit.taken(w, target)).is_equal_approx(TURRET_DAMAGE * (1.0 + damage_up.per_level * 2.0), 1e-4)


func test_without_sentry_link_the_turrets_keep_level_zero() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"hot_loads": 5, &"cyclic_tuning": 3})
	assert_int(TurretRules.damage_level(w)).is_equal(0)
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1000)
	_pad(w)
	var target: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -1.5)
	VarietyVKit.tough(w, target)
	_run_until_shots(w, 1)
	assert_float(VarietyVKit.taken(w, target)).is_equal(TURRET_DAMAGE)


# --- overwatch ---


func _overwatch_field(w: SimWorld) -> PackedInt32Array:
	_pad(w)
	var near: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -1.5)  # the usual choice: the best-ranked, closest to the core
	var spitter: int = VarietyVKit.place(w, Ids.EN_SPITTER, 6.0, -1.5)
	for i: int in [near, spitter]:
		VarietyVKit.tough(w, i)
	w.enemies.path_dist[near] = 1.0
	return PackedInt32Array([near, spitter])


func test_overwatch_turns_the_turrets_on_specialists_and_elites_first_and_adds_forty_percent() -> void:
	var plain: SimWorld = VarietyVKit.world(1, 4)
	var field: PackedInt32Array = _overwatch_field(plain)
	_run_until_shots(plain, 3)
	assert_float(VarietyVKit.taken(plain, field[1])).is_equal(0.0)  # without it the turret shoots the nearer skitter
	var w: SimWorld = VarietyVKit.directive_world({&"overwatch": 1})
	field = _overwatch_field(w)
	_run_until_shots(w, 3)
	assert_float(VarietyVKit.taken(w, field[0])).is_equal(0.0)
	var per_hit: float = maxf(1.0, TURRET_DAMAGE * 1.4 - DamageResolver.effective_armor(w, field[1], 0))
	assert_float(VarietyVKit.taken(w, field[1])).is_equal_approx(3.0 * per_hit, 1e-4)


func test_an_elite_is_an_overwatch_target_too_and_a_plain_enemy_gets_no_bonus() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"overwatch": 1})
	_pad(w)
	var plain: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -1.5)
	var elite: int = VarietyVKit.place(w, Ids.EN_SKITTER, 5.0, -1.5)
	VarietyVKit.tough(w, plain)
	VarietyVKit.tough(w, elite)
	w.enemies.path_dist[plain] = 1.0
	w.ext.flags[elite] |= EnemyExtState.F_ELITE
	assert_bool(TurretRules.is_priority(w, elite)).is_true()
	assert_bool(TurretRules.is_priority(w, plain)).is_false()
	assert_float(TurretRules.damage_mul_vs(w, plain, true)).is_equal(1.0)
	assert_float(TurretRules.damage_mul_vs(w, elite, true)).is_equal(1.4)
	assert_float(TurretRules.damage_mul_vs(w, elite, false)).is_equal(1.0)
	_run_until_shots(w, 2)
	assert_float(VarietyVKit.taken(w, plain)).is_equal(0.0)
	assert_float(VarietyVKit.taken(w, elite)).is_equal_approx(2.0 * TURRET_DAMAGE * 1.4, 1e-4)


func test_overwatch_with_no_specialist_in_range_leaves_the_normal_choice() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"overwatch": 1})
	_pad(w)
	var plain: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -1.5)
	VarietyVKit.tough(w, plain)
	var far_spitter: int = VarietyVKit.place(w, Ids.EN_SPITTER, 14.0, -1.5)  # 16.5 m from the pad ...
	VarietyVKit.tough(w, far_spitter)
	w.mods.range_mul = 0.5  # the range is 8.5 m: the spitter is out of it
	_run_until_shots(w, 2)
	assert_float(VarietyVKit.taken(w, plain)).is_equal(2.0 * TURRET_DAMAGE)
	assert_float(VarietyVKit.taken(w, far_spitter)).is_equal(0.0)


# --- range_mul and last_stand_protocol ---


func test_range_mul_scales_the_turret_range() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_pad(w)
	var def: UpgradeDef = w.content.upgrades[Ids.UP_AUTO_TURRET]
	var target: int = VarietyVKit.place(w, Ids.EN_SKITTER, def.turret_range_m * 0.7 - 2.5, -1.5)  # 70% of the range away
	VarietyVKit.tough(w, target)
	w.mods.range_mul = 0.5
	assert_float(TurretRules.range_of(w, def)).is_equal_approx(def.turret_range_m * 0.5, 1e-6)
	VarietyVKit.run(w, 200)
	assert_float(VarietyVKit.taken(w, target)).is_equal(0.0)  # out of reach
	w.mods.range_mul = 1.0
	VarietyVKit.run(w, 200)
	assert_float(VarietyVKit.taken(w, target)).is_greater(0.0)


func test_last_stand_protocol_speeds_the_turrets_up_below_thirty_five_percent_of_the_core() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	w.mods.set_flag(&"last_stand", true)
	w.core_hp = w.core_max_hp * 0.5
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1000)
	w.core_hp = w.core_max_hp * 0.34
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(1800)
	w.events_state.turret_rate_milli = 2000  # a surge on top: x1.8 x2
	w.events_state.turret_rate_ticks = 100
	assert_int(EventRates.turret_rate_milli(w, 0)).is_equal(3600)


# --- mine_layer ---


func _mine_world(stacks: int) -> SimWorld:
	var w: SimWorld = VarietyVKit.directive_world({&"mine_layer": stacks})
	VarietyVKit.clear_plan(w)
	_pad(w)
	return w


func test_mine_layer_lays_a_mine_every_eight_seconds_toward_the_spawn_edge_three_at_most() -> void:
	var w: SimWorld = _mine_world(1)
	VarietyVKit.run(w, 479)
	assert_int(HazardMines.count(w)).is_equal(0)
	VarietyVKit.tick(w)  # tick 480
	assert_int(HazardMines.count(w)).is_equal(1)
	var pad: Vector2 = Vector2(w.turrets.x[0], w.turrets.z[0])
	var mine: Vector2 = Vector2(w.hazards.m_x[0], w.hazards.m_z[0])
	assert_float(pad.distance_to(mine)).is_between(1.99, 4.01)
	assert_float(mine.x).is_greater(pad.x)  # the spawn edge is on the right
	assert_int(w.hazards.m_owner[0]).is_equal(0)
	VarietyVKit.run(w, 480 * 4)
	assert_int(HazardMines.count(w)).is_equal(3)  # three per pad: the fourth and fifth are not laid


func test_a_second_stack_lays_every_six_seconds_and_the_places_come_from_the_seed() -> void:
	var w: SimWorld = _mine_world(2)
	VarietyVKit.run(w, 360)
	assert_int(HazardMines.count(w)).is_equal(1)
	var twin: SimWorld = _mine_world(2)
	VarietyVKit.run(twin, 360)
	assert_float(twin.hazards.m_x[0]).is_equal(w.hazards.m_x[0])
	assert_float(twin.hazards.m_z[0]).is_equal(w.hazards.m_z[0])


func test_a_laid_mine_goes_off_under_an_enemy_and_no_mines_without_the_directive() -> void:
	var w: SimWorld = _mine_world(1)
	VarietyVKit.run(w, 480)
	var mine: Vector2 = Vector2(w.hazards.m_x[0], w.hazards.m_z[0])
	var victim: int = VarietyVKit.place(w, Ids.EN_SKITTER, mine.x, mine.y)
	VarietyVKit.tough(w, victim)
	VarietyVKit.run(w, 3)
	assert_int(HazardMines.count(w)).is_equal(0)
	assert_float(VarietyVKit.taken(w, victim)).is_greater(0.0)
	var none: SimWorld = VarietyVKit.world(1, 4)
	_pad(none)
	VarietyVKit.run(none, 1000)
	assert_int(HazardMines.count(none)).is_equal(0)
