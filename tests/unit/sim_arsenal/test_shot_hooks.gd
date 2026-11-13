extends GdUnitTestSuite
## V4-W: ShotHooks (CONTENT 3.1, 3.2) and the off-hand fire of twin_link. The slice data lists none of these directives, so
## the worlds come from ArsenalWKit.directive_world, which appends the ids it is given to the fixture content and holds them.
## Pistol: 30 damage, a shot every 30 ticks, 12 rounds, a 75-tick reload. Skitter: 45 hp, armor 0, radius 0.35.


func _pistol_hit(w: SimWorld, enemy_index: int) -> void:
	var def: WeaponDef = ArsenalSystem.effective_of(w, 0)
	var _dealt: float = DamageResolver.warden_hit(w, enemy_index, def, 1, 1.0, 0, DamageSource.Id.WARDEN)


# --- shock_rounds ---


func _arc_field(w: SimWorld) -> void:
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0, true)  # id 1, the target
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 11.0, 1.0)  # id 2, 1.41 m from it
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 12.5, 1.5)  # id 3, 1.58 m from id 2
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 5.0)  # id 4, out of reach of the chain


func test_every_sixth_shot_arcs_on_to_two_enemies_for_half() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"shock_rounds": 1})
	_arc_field(w)
	ArsenalWKit.run_until_shots(w, 5)
	assert_float(VarietyCKit.taken(w, 1)).is_equal(0.0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(0)
	ArsenalWKit.run_until_shots(w, 6)
	assert_int(w.tick).is_equal(180)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(180.0)  # six rounds of 30
	assert_float(VarietyCKit.taken(w, 1)).is_equal(15.0)
	assert_float(VarietyCKit.taken(w, 2)).is_equal(15.0)
	assert_float(VarietyCKit.taken(w, 3)).is_equal(0.0)
	var pairs: Array[Array] = []
	for e: SimEvent in VarietyCKit.events_of(w, SimEventKind.Id.CHAIN_ARC):
		pairs.append([e.a, e.b])
	assert_array(pairs).is_equal([[1, 2], [2, 3]])


func test_more_stacks_shorten_the_period_and_the_reach_follows_overpressure() -> void:
	var two: SimWorld = ArsenalWKit.directive_world({&"shock_rounds": 2})
	_arc_field(two)
	ArsenalWKit.run_until_shots(two, 5)
	assert_float(VarietyCKit.taken(two, 1)).is_equal(15.0)  # the 5th round
	var three: SimWorld = ArsenalWKit.directive_world({&"shock_rounds": 3})
	_arc_field(three)
	ArsenalWKit.run_until_shots(three, 4)
	assert_float(VarietyCKit.taken(three, 1)).is_equal(15.0)  # the 4th round
	var wide: SimWorld = ArsenalWKit.directive_world({&"shock_rounds": 1})
	wide.mods.area_mul = 1.35
	ArsenalWKit.foe(wide, Ids.EN_SKITTER, 10.0, 0.0, true)
	var reached: int = ArsenalWKit.foe(wide, Ids.EN_SKITTER, 12.9, 0.0)  # 2.9 m: beyond 2.5, inside 3.375
	ArsenalWKit.run_until_shots(wide, 6)
	assert_float(VarietyCKit.taken(wide, reached)).is_equal(15.0)


func test_without_the_directive_nothing_arcs() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"ricochet": 1})
	_arc_field(w)
	ArsenalWKit.run_until_shots(w, 12)
	assert_float(VarietyCKit.taken(w, 1)).is_equal(0.0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(0)


# --- ricochet ---


func _ricochet_field(w: SimWorld) -> void:
	var weak: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 10.0, 0.0)
	w.enemies.hp[weak] = 10.0
	w.enemies.path_dist[weak] = 1.0
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 12.0, 0.0)  # id 2: 2.0 m from the first
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 14.5, 0.0)  # id 3: 2.5 m beyond id 2, 4.5 m from the first
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 4.0)  # id 4: 4 m from the first


func test_a_killing_hitscan_round_goes_on_to_one_more_enemy_for_60_percent() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"ricochet": 1})
	_ricochet_field(w)
	ArsenalWKit.run_until_shots(w, 1)
	assert_int(w.enemies.alive[0]).is_equal(0)
	assert_float(VarietyCKit.taken(w, 1)).is_equal_approx(18.0, 1e-5)
	assert_float(VarietyCKit.taken(w, 2)).is_equal(0.0)
	assert_float(VarietyCKit.taken(w, 3)).is_equal(0.0)
	assert_int(w.combat.kills_by_source[DamageSource.Id.WARDEN]).is_equal(1)


func test_the_second_stack_goes_on_to_two_enemies_from_where_the_last_one_stood() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"ricochet": 2})
	_ricochet_field(w)
	ArsenalWKit.run_until_shots(w, 1)
	assert_float(VarietyCKit.taken(w, 1)).is_equal_approx(18.0, 1e-5)
	assert_float(VarietyCKit.taken(w, 2)).is_equal_approx(18.0, 1e-5)  # within 3 m of the second, not of the first
	assert_float(VarietyCKit.taken(w, 3)).is_equal(0.0)


func test_a_round_that_does_not_kill_and_a_cone_shot_do_not_ricochet() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"ricochet": 2})
	_ricochet_field(w)
	w.enemies.hp[0] = 100.0
	ArsenalWKit.run_until_shots(w, 1)
	assert_float(w.enemies.hp[0]).is_equal(70.0)
	assert_float(VarietyCKit.taken(w, 1)).is_equal(0.0)
	var cone: SimWorld = ArsenalWKit.directive_world({&"ricochet": 2}, Ids.WP_SCATTERGUN)
	var weak: int = VarietyCKit.place_rel(cone, Ids.EN_SKITTER, 3.0, 0.0)
	cone.enemies.hp[weak] = 5.0
	cone.enemies.path_dist[weak] = 1.0
	var beside: int = ArsenalWKit.foe(cone, Ids.EN_SKITTER, 3.0, 2.5)  # outside the cone, within 3 m of the kill
	ArsenalWKit.run_until_shots(cone, 1)
	assert_int(cone.enemies.alive[weak]).is_equal(0)
	assert_float(VarietyCKit.taken(cone, beside)).is_equal(0.0)


# --- kill_chain ---


func test_each_kill_adds_four_percent_up_to_forty_and_they_last_two_seconds() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"kill_chain": 1})
	for k: int in 12:
		var i: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 4.0 + float(k) * 0.5, 0.0)
		w.enemies.hp[i] = 1.0
	var a: ArsenalState = w.arsenal
	assert_int(ShotHooks.kill_chain_mult_milli(a)).is_equal(1000)
	for k: int in 3:
		_pistol_hit(w, k)
	assert_int(ShotHooks.kill_chain_stacks(a)).is_equal(3)
	assert_int(ShotHooks.kill_chain_mult_milli(a)).is_equal(1120)
	assert_int(ShotHooks.kill_chain_ticks(a)).is_equal(120)
	assert_int(ArsenalFire.rate_milli(w, a, ArsenalSystem.effective_of(w, 0))).is_equal(2240)  # 2000 x 1.12
	for k: int in range(3, 12):
		_pistol_hit(w, k)
	assert_int(ShotHooks.kill_chain_stacks(a)).is_equal(10)
	assert_int(ShotHooks.kill_chain_mult_milli(a)).is_equal(1400)
	assert_int(a.shots_since_proc & 15).is_equal(0)  # the pistol's counter lives in the low bits and is untouched
	for _n: int in 119:
		ShotHooks.kill_chain_tick(a)
	assert_int(ShotHooks.kill_chain_stacks(a)).is_equal(10)
	ShotHooks.kill_chain_tick(a)
	assert_int(ShotHooks.kill_chain_stacks(a)).is_equal(0)
	assert_int(ShotHooks.kill_chain_mult_milli(a)).is_equal(1000)


func test_a_kill_restarts_the_two_seconds_and_the_chain_speeds_the_cadence() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"kill_chain": 1})
	var a: ArsenalState = w.arsenal
	for k: int in 2:
		var i: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 4.0 + float(k), 0.0)
		w.enemies.hp[i] = 1.0
	_pistol_hit(w, 0)
	for _n: int in 100:
		ShotHooks.kill_chain_tick(a)
	_pistol_hit(w, 1)
	assert_int(ShotHooks.kill_chain_stacks(a)).is_equal(2)
	assert_int(ShotHooks.kill_chain_ticks(a)).is_equal(120)
	var plain: SimWorld = ArsenalWKit.world(Ids.WP_PISTOL)
	ArsenalWKit.foe(plain, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	assert_int(ArsenalWKit.shot_ticks(plain, 70)[0]).is_equal(30)
	assert_int(ArsenalWKit.shot_ticks(w, 70)[0]).is_less(30)


# --- unstable_munitions ---


func test_a_fifth_of_the_kills_blast_and_the_proc_stream_decides() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"unstable_munitions": 1})
	var mirror: RandomNumberGenerator = SimRng.new(1).stream(&"proc")
	var expected: int = 0
	for k: int in 60:
		var i: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 4.0 + float(k % 10), -1.0 - floorf(float(k) / 10.0) * 0.1)
		w.enemies.hp[i] = 1.0
		_pistol_hit(w, i)
		if mirror.randf() < 0.2:
			expected += 1
	assert_int(expected).is_greater(0)
	assert_int(w.hazards.queued()).is_equal(expected)
	assert_float(w.hazards.q_radius[0]).is_equal(2.0)
	assert_float(w.hazards.q_damage[0]).is_equal(50.0)
	assert_int(w.hazards.q_kind[0]).is_equal(HazardState.K_BLAST)
	assert_int(w.hazards.q_source[0]).is_equal(DamageSource.Id.WARDEN)
	assert_int(w.hazards.q_due[0]).is_equal(w.tick + 6)


func test_five_percent_of_reloads_jam_for_a_second_and_a_half() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"unstable_munitions": 1})
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(w, 24)
	var mirror: RandomNumberGenerator = SimRng.new(1).stream(&"proc")
	var reloads: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)
	assert_int(reloads.size()).is_equal(2)
	for e: SimEvent in reloads:
		assert_int(e.a).is_equal(75 + (90 if mirror.randf() < 0.05 else 0))
	var plain: SimWorld = ArsenalWKit.world(Ids.WP_PISTOL)
	ArsenalWKit.foe(plain, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(plain, 12)
	assert_int(VarietyCKit.events_of(plain, SimEventKind.Id.RELOAD_STARTED)[0].a).is_equal(75)
	assert_bool(plain.rng.names_sorted().has("proc")).is_false()


# --- twin_link ---


func _twin(held: Dictionary[StringName, int], holstered: int) -> SimWorld:
	var w: SimWorld = ArsenalWKit.directive_world(held, Ids.WP_PISTOL)
	ArsenalSystem.give_weapon(w, 1, holstered)
	return w


func _offhand_ticks(w: SimWorld) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in VarietyCKit.events_of(w, SimEventKind.Id.ENEMY_DAMAGED):
		if e.b == DamageSource.Id.WARDEN_OFFHAND:
			out.append(e.tick)
	return out


func test_the_holstered_weapon_fires_at_35_percent_of_its_rate_with_its_own_magazine() -> void:
	var w: SimWorld = _twin({&"twin_link": 1}, Ids.WP_SMG)
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_both(w, 120)
	var ticks: Array[int] = _offhand_ticks(w)
	assert_int(ticks[0]).is_equal(29)  # 6 a second x 0.35 = 2100 milli a tick
	assert_int(ticks.size()).is_equal(4)  # 29, 58, 86, 115
	assert_int(w.arsenal.slot_magazine[1]).is_equal(30 - 4)
	assert_int(w.combat.shots_by_source[DamageSource.Id.WARDEN_OFFHAND]).is_equal(4)
	assert_int(w.warden.shots_fired).is_equal(4)  # the pistol's own: ticks 30, 60, 90, 120
	assert_int(w.arsenal.slot_magazine[0]).is_equal(12 - 4)


func test_without_twin_link_the_holstered_weapon_stays_quiet() -> void:
	var w: SimWorld = _twin({&"ricochet": 1}, Ids.WP_SMG)
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_both(w, 120)
	assert_array(_offhand_ticks(w)).is_empty()
	assert_int(w.arsenal.slot_magazine[1]).is_equal(30)


func test_the_off_hand_shot_must_be_in_the_range_of_the_holstered_weapon() -> void:
	var w: SimWorld = _twin({&"twin_link": 1}, Ids.WP_SCATTERGUN)  # 9 m
	var t: int = ArsenalWKit.foe(w, Ids.EN_HULK, 12.0, 0.0, true)
	ArsenalWKit.run_both(w, 200)
	assert_array(_offhand_ticks(w)).is_empty()
	assert_int(w.arsenal.offhand_acc_milli).is_equal(60000)  # it waits with a banked shot
	w.enemies.x[t] = w.warden.x + 8.0
	ArsenalWKit.run_both(w, 1)
	assert_int(_offhand_ticks(w).size()).is_equal(8)  # eight pellets of the scattergun, one volley


func test_the_rail_lance_and_the_torch_do_not_fire_from_the_holster() -> void:
	for weapon: int in [Ids.WP_RAIL_LANCE, Ids.WP_CUTTING_TORCH]:
		var w: SimWorld = _twin({&"twin_link": 1}, weapon)
		ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
		ArsenalWKit.run_both(w, 300)
		assert_array(_offhand_ticks(w)).is_empty()


func test_a_holstered_heat_weapon_adds_heat_and_vents_at_the_cap() -> void:
	var w: SimWorld = _twin({&"twin_link": 1}, Ids.WP_ARC_PROJECTOR)
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_both(w, 110)  # 1.6 a second x 0.35 = 560 milli a tick: the first arc on tick 108
	assert_array(_offhand_ticks(w)).is_equal([108])
	assert_int(VarietyCKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(1)
	assert_int(w.arsenal.slot_heat[1]).is_equal(14)  # 14 a shot; two ticks of cooling are less than one heat


# --- the turret hooks (called by TurretSystem, a file of V4-V) ---


func _turret_field(w: SimWorld) -> void:
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0)  # id 1, the turret's target
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 11.0, 1.0)  # id 2: 1.41 m from it
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 12.5, 1.5)  # id 3: 1.58 m from id 2
	w.turrets.active[0] = 1
	w.turrets.target_id[0] = 1
	w.turrets.aim_x[0] = w.enemies.x[0]
	w.turrets.aim_z[0] = w.enemies.z[0]


func test_arc_pylons_chain_every_fourth_turret_shot_for_60_percent() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"arc_pylons": 1})
	_turret_field(w)
	w.combat.shots_by_source[DamageSource.Id.TURRET_0] = 3
	ShotHooks.on_turret_shot(w, 0, 0)
	assert_float(VarietyCKit.taken(w, 1)).is_equal(0.0)
	w.combat.shots_by_source[DamageSource.Id.TURRET_0] = 4
	ShotHooks.on_turret_shot(w, 0, 0)
	assert_float(VarietyCKit.taken(w, 1)).is_equal_approx(7.2, 1e-5)  # 12 x 0.6
	assert_float(VarietyCKit.taken(w, 2)).is_equal_approx(7.2, 1e-5)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(0.0)
	assert_float(w.combat.damage_by_source[DamageSource.Id.TURRET_0]).is_equal_approx(14.4, 1e-5)
	var two: SimWorld = ArsenalWKit.directive_world({&"arc_pylons": 2})
	_turret_field(two)
	two.combat.shots_by_source[DamageSource.Id.TURRET_0] = 3
	ShotHooks.on_turret_shot(two, 0, 0)
	assert_float(VarietyCKit.taken(two, 1)).is_equal_approx(7.2, 1e-5)  # every third shot at stack 2


func test_flak_heads_splash_the_neighbours_of_the_hit_for_40_then_60_percent() -> void:
	var w: SimWorld = ArsenalWKit.directive_world({&"flak_heads": 1})
	_turret_field(w)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 11.4, 0.0)  # id 4: 1.4 m from the target, out of the 1.2 m splash
	ShotHooks.on_turret_hit(w, 0, 0, 12.0)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(0.0)  # the target took its own hit elsewhere
	assert_float(VarietyCKit.taken(w, 1)).is_equal(0.0)  # 1.41 m: outside 1.2
	var near: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.9)  # 0.9 m
	ShotHooks.on_turret_hit(w, 0, 0, 12.0)
	assert_float(VarietyCKit.taken(w, near)).is_equal_approx(4.8, 1e-5)  # 12 x 0.4
	var two: SimWorld = ArsenalWKit.directive_world({&"flak_heads": 2})
	_turret_field(two)
	var close: int = ArsenalWKit.foe(two, Ids.EN_SKITTER, 10.0, 0.9)
	ShotHooks.on_turret_hit(two, 0, 0, 12.0)
	assert_float(VarietyCKit.taken(two, close)).is_equal_approx(7.2, 1e-5)
	two.mods.area_mul = 1.35  # a 1.62 m splash now reaches the second skitter at 1.41 m
	ShotHooks.on_turret_hit(two, 0, 0, 12.0)
	assert_float(VarietyCKit.taken(two, 1)).is_equal_approx(7.2, 1e-5)


func test_the_legacy_content_has_no_directives_and_no_hook_fires() -> void:
	var legacy: SimWorld = TestContent.world()
	assert_int(ShotHooks.stacks(legacy, &"ricochet")).is_equal(0)
	assert_int(ShotHooks.reload_jam_ticks(legacy)).is_equal(0)
	ShotHooks.on_warden_kill(legacy, 0.0, 0.0)
	assert_int(legacy.hazards.queued()).is_equal(0)
