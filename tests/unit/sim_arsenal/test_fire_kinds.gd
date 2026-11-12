extends GdUnitTestSuite
## V2-C: the arc projector's chain (VARIETY_SPEC 3.3 kind A), the pierce of hitscan weapons (kind H) and the damage
## order of DamageResolver. Arc projector: 40 damage, 4 jumps of at most 3 m, x0.75 per jump, armor ignored, x1.5 on a
## stunned enemy. Hollow Warden: 150 hp, armor 8. Positions are relative to the Warden.


## Six Hollow Wardens, ids 1 .. 6. A is the target (the only one about to arrive). B and C are both 2 m from A; from B
## the nearest is D (2.5 m, C is 2.83 m away); from D only E is in reach; from E only F. C is never hit.
func _chain_world() -> SimWorld:
	var w: SimWorld = VarietyCKit.world()
	ArsenalSystem.give_weapon(w, 0, Ids.WP_ARC_PROJECTOR)
	var a: int = VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 10.0, 0.0)
	VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 12.0, 0.0)  # B
	VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 10.0, 2.0)  # C
	VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 14.5, 0.0)  # D
	VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 14.5, 2.9)  # E
	VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 16.0, 2.9)  # F
	w.enemies.path_dist[a] = 1.0
	return w


func _first_shot(w: SimWorld) -> void:
	VarietyCKit.run_weapon(w, 38)
	assert_int(w.warden.shots_fired).is_equal(1)


func test_the_chain_takes_the_nearest_enemy_and_the_lower_id_on_a_tie() -> void:
	var w: SimWorld = _chain_world()
	_first_shot(w)
	var arcs: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CHAIN_ARC)
	var pairs: Array[Array] = []
	for e: SimEvent in arcs:
		pairs.append([e.a, e.b])
	assert_array(pairs).is_equal([[0, 1], [1, 2], [2, 4], [4, 5], [5, 6]])
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(1)
	assert_float(w.enemies.hp[2]).is_equal(150.0)  # C: out of the chain


func test_each_jump_deals_three_quarters_of_the_one_before_and_armor_is_ignored() -> void:
	var w: SimWorld = _chain_world()
	_first_shot(w)
	assert_float(w.enemies.hp[0]).is_equal(150.0 - 40.0)
	assert_float(w.enemies.hp[1]).is_equal(150.0 - 30.0)
	assert_float(w.enemies.hp[3]).is_equal(150.0 - 22.5)
	assert_float(w.enemies.hp[4]).is_equal(150.0 - 16.875)
	assert_float(w.enemies.hp[5]).is_equal(150.0 - 12.65625)
	assert_float(w.combat.damage_by_source[DamageSource.Id.WARDEN]).is_equal(40.0 + 30.0 + 22.5 + 16.875 + 12.65625)


func test_the_chain_is_no_longer_than_the_enemies_in_reach() -> void:
	var w: SimWorld = VarietyCKit.world()
	ArsenalSystem.give_weapon(w, 0, Ids.WP_ARC_PROJECTOR)
	var a: int = VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 10.0, 0.0)
	VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 12.9, 0.0)  # 2.9 m: in reach
	VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 16.0, 0.0)  # 3.1 m from the second: out of reach
	w.enemies.path_dist[a] = 1.0
	_first_shot(w)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(2)
	assert_float(w.enemies.hp[2]).is_equal(150.0)
	w.mods.area_mul = 1.35  # overpressure: the chain reaches 4.05 m
	VarietyCKit.run_weapon(w, 37)
	assert_int(w.warden.shots_fired).is_equal(2)
	assert_float(w.enemies.hp[2]).is_equal(150.0 - 22.5)


func test_the_chain_goes_on_from_a_target_the_bolt_killed() -> void:
	var w: SimWorld = _chain_world()
	w.enemies.hp[0] = 10.0
	_first_shot(w)
	assert_int(w.enemies.alive[0]).is_equal(0)
	assert_float(w.enemies.hp[1]).is_equal(120.0)
	assert_float(w.enemies.hp[5]).is_equal(150.0 - 12.65625)
	assert_int(w.scrap).is_equal(w.content.enemies[Ids.EN_HOLLOW].scrap)
	assert_int(w.combat.kills_by_source[DamageSource.Id.WARDEN]).is_equal(1)
	assert_int(w.warden.target_id).is_not_equal(1)  # the Warden picked a new target at once


func test_a_stunned_enemy_takes_half_again_as_much() -> void:
	var w: SimWorld = _chain_world()
	w.enemies.stun_ticks[0] = 600
	w.enemies.stun_ticks[3] = 600
	_first_shot(w)
	assert_float(w.enemies.hp[0]).is_equal(150.0 - 60.0)
	assert_float(w.enemies.hp[1]).is_equal(150.0 - 30.0)
	assert_float(w.enemies.hp[3]).is_equal(150.0 - 33.75)


func test_the_weapon_level_and_the_damage_level_multiply() -> void:
	var w: SimWorld = _chain_world()
	ArsenalSystem.level_up(w, 0)  # level 2: x1.25
	w.upgrade_levels[Ids.UP_DAMAGE] = 3  # hot_loads x3: x1.6
	_first_shot(w)
	assert_float(w.enemies.hp[0]).is_equal_approx(150.0 - 80.0, 1e-9)
	assert_float(w.enemies.hp[1]).is_equal_approx(150.0 - 60.0, 1e-9)


func test_the_pistol_meets_armor_with_the_golden_values() -> void:
	var w: SimWorld = VarietyCKit.world()
	var hollow: int = VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 10.0, 0.0)
	VarietyCKit.run_weapon(w, 30)
	assert_float(w.enemies.hp[hollow]).is_equal(150.0 - 22.0)  # hit_damage(30, 0, 0.2, 8) = 22
	w.upgrade_levels[Ids.UP_DAMAGE] = 3
	VarietyCKit.run_weapon(w, 30)
	assert_float(w.enemies.hp[hollow]).is_equal_approx(150.0 - 22.0 - 40.0, 1e-9)  # 30 x 1.6 - 8


func test_conditional_multipliers_full_hp_low_hp_and_the_global_damage() -> void:
	var w: SimWorld = VarietyCKit.world()
	var pistol: WeaponDef = w.content.weapons[Ids.WP_PISTOL]
	var i: int = VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 10.0, 0.0)
	assert_float(DamageResolver.warden_amount(w, i, pistol, 1)).is_equal(30.0)
	w.mods.w_full_hp_mul = 1.5  # first_strike
	assert_float(DamageResolver.warden_amount(w, i, pistol, 1)).is_equal(45.0)
	w.enemies.hp[i] = 149.0
	assert_float(DamageResolver.warden_amount(w, i, pistol, 1)).is_equal(30.0)
	w.mods.w_low_hp_mul = 1.6  # executioner below 30%
	w.mods.w_low_hp_threshold = 0.3
	w.enemies.hp[i] = 45.0
	assert_float(DamageResolver.warden_amount(w, i, pistol, 1)).is_equal(30.0)  # exactly 30% is not below it
	w.enemies.hp[i] = 44.0
	assert_float(DamageResolver.warden_amount(w, i, pistol, 1)).is_equal_approx(48.0, 1e-9)
	w.mods.w_dmg_mul = 1.8  # glass_cannon
	assert_float(DamageResolver.warden_amount(w, i, pistol, 3)).is_equal_approx(30.0 * 1.55 * 1.8 * 1.6, 1e-4)


func test_hit_ex_flags() -> void:
	var w: SimWorld = VarietyCKit.world()
	var hollow: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 0.0, 0.0)
	var hulk: int = VarietyCKit.place(w, Ids.EN_HULK, 5.0, 0.0)
	VarietyCKit.tough(w, hollow)
	VarietyCKit.tough(w, hulk)
	assert_float(DamageResolver.hit_ex(w, hollow, 30.0, 0, DamageSource.Id.HAZARD)).is_equal(22.0)
	assert_float(DamageResolver.hit_ex(w, hollow, 30.0, DamageResolver.F_HALF_ARMOR, DamageSource.Id.HAZARD)).is_equal(26.0)
	assert_float(DamageResolver.hit_ex(w, hollow, 30.0, DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.HAZARD)).is_equal(30.0)
	assert_float(DamageResolver.hit_ex(w, hollow, 5.0, 0, DamageSource.Id.HAZARD)).is_equal(1.0)  # the floor of 1
	assert_float(DamageResolver.hit_ex(w, hollow, 0.25, DamageResolver.F_BURN, DamageSource.Id.HAZARD)).is_equal(0.25)
	var boss_flags: int = DamageResolver.F_IGNORE_ARMOR | DamageResolver.F_BOSS_HALF
	assert_float(DamageResolver.hit_ex(w, hulk, 100.0, boss_flags, DamageSource.Id.STRIKE)).is_equal(50.0)
	assert_float(DamageResolver.hit_ex(w, hollow, 100.0, boss_flags, DamageSource.Id.STRIKE)).is_equal(100.0)
	assert_float(w.combat.damage_by_source[DamageSource.Id.STRIKE]).is_equal(150.0)
	w.mods.enemy_armor_add = 4.0  # mod_plated
	assert_float(DamageResolver.hit_ex(w, hollow, 30.0, 0, DamageSource.Id.HAZARD)).is_equal(18.0)
	w.ext.shred_milli[hollow] = 6000
	assert_float(DamageResolver.hit_ex(w, hollow, 30.0, 0, DamageSource.Id.HAZARD)).is_equal(24.0)
	w.upgrade_levels[Ids.UP_ARMOR_PIERCING] = 2  # penetrator_cores x2: 30% of the 6 that are left
	assert_float(DamageResolver.hit_ex(w, hollow, 30.0, 0, DamageSource.Id.HAZARD)).is_equal_approx(30.0 - 4.2, 1e-9)
	assert_float(DamageResolver.hit_ex(w, -1, 30.0, 0, DamageSource.Id.HAZARD)).is_equal(0.0)
	assert_float(DamageResolver.hit_ex(w, 40, 30.0, 0, DamageSource.Id.HAZARD)).is_equal(0.0)  # an empty row


func test_the_legacy_hit_is_the_same_path_with_no_flags() -> void:
	var w: SimWorld = VarietyCKit.world()
	var hollow: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 0.0, 0.0)
	var hulk: int = VarietyCKit.place(w, Ids.EN_HULK, 5.0, 0.0)
	assert_float(DamageResolver.hit(w, hollow, 30.0, 0, DamageSource.Id.WARDEN)).is_equal(22.0)
	assert_float(DamageResolver.hit(w, hulk, 15.0, 0, DamageSource.Id.TURRET_0)).is_equal(3.0)
	assert_float(DamageResolver.hit(w, hulk, 12.0, 0, DamageSource.Id.TURRET_1)).is_equal(1.0)
	assert_float(DamageResolver.hit(w, hollow, 30.0, 3, DamageSource.Id.WARDEN)).is_equal(
		Formulas.hit_damage(30.0, 3, w.content.upgrades[Ids.UP_DAMAGE].per_level, 8.0)
	)


func test_a_piercing_round_passes_into_the_next_enemy_on_the_line() -> void:
	var w: SimWorld = VarietyCKit.world()
	ArsenalSystem.give_weapon(w, 0, Ids.WP_ASSAULT_RIFLE)  # 28 damage, pierce 1, x0.6
	var first: int = VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 10.0, 0.0)
	var behind: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 11.5, 0.2)  # 1.5 m behind, 0.2 m off the line
	var third: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 13.0, 0.0)  # a second pass would reach it
	var beside: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 11.0, 1.0)  # 1 m off the line
	w.enemies.path_dist[first] = 1.0
	VarietyCKit.run_weapon(w, 14)  # 4.5 shots per second: the first round leaves on tick 14
	assert_int(w.warden.shots_fired).is_equal(1)
	assert_float(w.enemies.hp[first]).is_equal(150.0 - 20.0)  # 28 - 8 armor
	assert_float(w.enemies.hp[behind]).is_equal_approx(45.0 - 16.8, 1e-9)  # 28 x 0.6
	assert_float(w.enemies.hp[third]).is_equal(45.0)
	assert_float(w.enemies.hp[beside]).is_equal(45.0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(1)


func test_a_pistol_round_does_not_pierce_and_an_enemy_too_far_behind_is_safe() -> void:
	var w: SimWorld = VarietyCKit.world()
	var first: int = VarietyCKit.place_rel(w, Ids.EN_HOLLOW, 10.0, 0.0)
	var behind: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 11.0, 0.0)
	w.enemies.path_dist[first] = 1.0
	VarietyCKit.run_weapon(w, 30)
	assert_float(w.enemies.hp[behind]).is_equal(45.0)
	ArsenalSystem.give_weapon(w, 0, Ids.WP_ASSAULT_RIFLE)
	w.enemies.x[behind] = w.warden.x + 12.5  # 2.5 m behind: out of the 2 m reach
	VarietyCKit.run_weapon(w, 14)
	assert_float(w.enemies.hp[behind]).is_equal(45.0)
