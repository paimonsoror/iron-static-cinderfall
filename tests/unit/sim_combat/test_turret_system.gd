extends GdUnitTestSuite
## Auto turrets (GDD 5.3): 12 damage, 3 shots/s, 17 m, no magazine; no damage or fire-rate upgrades and no
## Overdrive; armor piercing applies; hits carry TURRET_0 + pad. Pad 0 is at (-2.5, -1.5), pad 1 at (-1.0, 8.0).

const RANGE: float = 17.0


func _near_pad(w: SimWorld, pad: int, dx: float, dz: float, type_index: int = Ids.EN_SKITTER) -> int:
	return CombatTestKit.place_abs(w, type_index, w.turrets.x[pad] + dx, w.turrets.z[pad] + dz)


func test_inactive_turrets_never_fire() -> void:
	var w: SimWorld = CombatTestKit.world()
	var e: int = _near_pad(w, 0, 5.0, 0.0)
	CombatTestKit.make_tough(w, e)
	for n: int in 600:
		CombatTestKit.turret_tick(w)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(0)
	assert_float(w.enemies.hp[e]).is_equal(CombatTestKit.TOUGH_HP)
	assert_int(w.turrets.target_id[0]).is_equal(0)
	assert_int(w.turrets.fire_acc_milli[0]).is_equal(0)


func test_an_active_turret_fires_3_shots_per_second() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	var e: int = _near_pad(w, 0, 8.0, 0.0)
	CombatTestKit.make_tough(w, e)
	var shot_ticks: PackedInt32Array = PackedInt32Array()
	for n: int in 600:
		var before: int = CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED)
		CombatTestKit.turret_tick(w)
		if CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED) > before:
			shot_ticks.append(w.tick)
	assert_int(shot_ticks.size()).is_equal(30)
	assert_int(shot_ticks[0]).is_equal(20)
	assert_int(shot_ticks[1]).is_equal(40)
	assert_int(shot_ticks[29]).is_equal(600)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_0]).is_equal(30)
	assert_float(w.enemies.hp[e]).is_equal(CombatTestKit.TOUGH_HP - 30.0 * 12.0)


func test_the_turret_has_no_magazine_and_never_reloads() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	CombatTestKit.make_tough(w, _near_pad(w, 0, 8.0, 0.0))
	for n: int in 3600:
		CombatTestKit.turret_tick(w)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_0]).is_equal(180)  # 3 per second x 60 s
	assert_int(CombatTestKit.count(w, SimEventKind.Id.RELOAD_STARTED)).is_equal(0)


func test_the_range_is_17_metres_from_the_pad() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	var out_of_range: int = _near_pad(w, 0, 0.0, 17.5, Ids.EN_RUSHER)
	for n: int in 120:
		CombatTestKit.turret_tick(w)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(0)
	assert_float(w.enemies.hp[out_of_range]).is_equal(65.0)
	var edge: int = _near_pad(w, 0, 0.0, -RANGE)
	CombatTestKit.make_tough(w, edge)
	CombatTestKit.turret_tick(w)  # its accumulator is clamped at one shot, so it fires at once
	assert_int(CombatTestKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(1)
	assert_int(w.turrets.target_id[0]).is_equal(w.enemies.id[edge])


func test_a_turret_shoots_what_the_warden_could_not_reach() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	# 16.9 m from the pad, straight away from the Warden: inside the turret's 17 m, outside the Warden's 25 m.
	var away: Vector2 = Vector2(w.turrets.x[0] - w.warden.x, w.turrets.z[0] - w.warden.z).normalized()
	var far_from_warden: int = CombatTestKit.place_abs(
		w, Ids.EN_SKITTER, w.turrets.x[0] + away.x * 16.9, w.turrets.z[0] + away.y * 16.9
	)
	CombatTestKit.make_tough(w, far_from_warden)
	var dx: float = w.enemies.x[far_from_warden] - w.warden.x
	var dz: float = w.enemies.z[far_from_warden] - w.warden.z
	assert_float(sqrt(dx * dx + dz * dz)).is_greater(25.0)  # beyond the Warden's 25 m
	CombatTestKit.run_combat(w, 60)
	assert_int(w.warden.shots_fired).is_equal(0)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_0]).is_equal(3)


func test_turret_damage_ignores_the_damage_and_fire_rate_levels_and_overdrive() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	w.upgrade_levels[Ids.UP_DAMAGE] = 5
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 5
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 100000
	var e: int = _near_pad(w, 0, 8.0, 0.0)
	CombatTestKit.make_tough(w, e)
	for n: int in 120:
		CombatTestKit.turret_tick(w)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_0]).is_equal(6)  # still 3 per second
	assert_float(w.enemies.hp[e]).is_equal(CombatTestKit.TOUGH_HP - 6.0 * 12.0)  # still 12 per hit, armor 0


func test_turret_hits_benefit_from_armor_piercing() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	var hollow: int = _near_pad(w, 0, 8.0, 0.0, Ids.EN_HOLLOW)
	w.turrets.fire_acc_milli[0] = CombatTestKit.MILLI_PER_SHOT
	CombatTestKit.turret_tick(w)
	assert_float(w.enemies.hp[hollow]).is_equal(150.0 - 4.0)  # 12 - armor 8
	w.upgrade_levels[Ids.UP_ARMOR_PIERCING] = 5  # armor 8 x 0.25 = 2
	w.turrets.fire_acc_milli[0] = CombatTestKit.MILLI_PER_SHOT
	w.turrets.lock_ticks_left[0] = 0
	CombatTestKit.turret_tick(w)
	assert_float(w.enemies.hp[hollow]).is_equal_approx(150.0 - 4.0 - 10.0, 0.000001)


func test_events_carry_turret_0_and_turret_1() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	CombatTestKit.activate_turret(w, 1)
	var by_pad0: int = _near_pad(w, 0, 0.0, -6.0)
	var by_pad1: int = _near_pad(w, 1, 0.0, 6.0)
	CombatTestKit.make_tough(w, by_pad0)
	CombatTestKit.make_tough(w, by_pad1)
	w.turrets.fire_acc_milli[0] = CombatTestKit.MILLI_PER_SHOT
	w.turrets.fire_acc_milli[1] = CombatTestKit.MILLI_PER_SHOT
	CombatTestKit.turret_tick(w)
	var shots: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.SHOT_FIRED)
	assert_int(shots.size()).is_equal(2)
	assert_int(shots[0].a).is_equal(DamageSource.Id.TURRET_0)
	assert_int(shots[1].a).is_equal(DamageSource.Id.TURRET_1)
	var damaged: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.ENEMY_DAMAGED)
	assert_int(damaged.size()).is_equal(2)
	assert_int(damaged[0].b).is_equal(DamageSource.Id.TURRET_0)
	assert_int(damaged[1].b).is_equal(DamageSource.Id.TURRET_1)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_0]).is_equal(1)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_1]).is_equal(1)


func test_each_turret_picks_its_target_from_its_own_position() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	CombatTestKit.activate_turret(w, 1)
	var near_pad0: int = _near_pad(w, 0, 0.0, -4.0)
	var near_pad1: int = _near_pad(w, 1, 0.0, 4.0)
	CombatTestKit.make_tough(w, near_pad0)
	CombatTestKit.make_tough(w, near_pad1)
	CombatTestKit.turret_tick(w)
	assert_int(w.turrets.target_id[0]).is_equal(w.enemies.id[near_pad0])
	assert_int(w.turrets.target_id[1]).is_equal(w.enemies.id[near_pad1])
	assert_float(w.turrets.aim_x[0]).is_equal(w.enemies.x[near_pad0])
	assert_float(w.turrets.aim_z[1]).is_equal(w.enemies.z[near_pad1])


func test_turret_cadence_clamps_without_a_target_and_the_first_shot_is_immediate() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 1)
	for n: int in 100:
		CombatTestKit.turret_tick(w)
	assert_int(w.turrets.fire_acc_milli[1]).is_equal(CombatTestKit.MILLI_PER_SHOT)
	CombatTestKit.make_tough(w, _near_pad(w, 1, 5.0, 0.0))
	CombatTestKit.turret_tick(w)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_1]).is_equal(1)
	CombatTestKit.run_turrets(w, 18)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_1]).is_equal(1)  # 3000 left over, 19 more ticks to go
	CombatTestKit.turret_tick(w)
	assert_int(w.combat.shots_by_source[DamageSource.Id.TURRET_1]).is_equal(2)


func test_a_turret_kill_pays_scrap_once_and_the_turret_moves_on() -> void:
	var w: SimWorld = CombatTestKit.world()
	CombatTestKit.activate_turret(w, 0)
	var weak: int = _near_pad(w, 0, 0.0, -3.0, Ids.EN_RUSHER)
	var other: int = _near_pad(w, 0, 0.0, 6.0)
	CombatTestKit.make_tough(w, other)
	w.enemies.hp[weak] = 5.0
	w.turrets.fire_acc_milli[0] = CombatTestKit.MILLI_PER_SHOT
	CombatTestKit.turret_tick(w)
	assert_int(w.scrap).is_equal(25)
	assert_int(w.combat.kills_by_source[DamageSource.Id.TURRET_0]).is_equal(1)
	assert_int(w.turrets.target_id[0]).is_equal(w.enemies.id[other])
	assert_int(w.turrets.lock_ticks_left[0]).is_equal(24)
