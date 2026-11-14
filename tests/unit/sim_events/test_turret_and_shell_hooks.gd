extends GdUnitTestSuite
## V4-V: the call points that TurretSystem and HazardSystem owe to the shot hooks and the weapons (WORK_PLAN V4-V / V4-W):
## ShotHooks.on_turret_shot after the shot is tallied, ShotHooks.on_turret_hit after the hit, the pool of a landed slag
## mortar shell, and the drum API that lets stray LMG rounds hit fuel drums.
##
## The pad 0 of the arena stands at (-2.5, -1.5); a skitter has no armor and the turret hits for 15 (x t_dmg_mul; V5-C:
## was 12).

const TURRET_DAMAGE: float = 15.0


## A pad with a target 1.5 m from it that is the best-ranked enemy, and two more skitters behind it.
func _field(w: SimWorld) -> void:
	w.turrets.active[0] = 1
	var target: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -1.5)
	var mid: int = VarietyVKit.place(w, Ids.EN_SKITTER, 0.0, -1.5)  # 1.0 m behind the target
	var far: int = VarietyVKit.place(w, Ids.EN_SKITTER, 1.5, -1.5)  # 1.5 m behind that
	for i: int in [target, mid, far]:
		VarietyVKit.tough(w, i)
	w.enemies.path_dist[target] = 1.0


func _run_until_shots(w: SimWorld, shots: int) -> void:
	for _n: int in 600:
		if w.combat.shots_by_source[DamageSource.Id.TURRET_0] >= shots:
			return
		VarietyVKit.tick(w)


# --- the turret call points ---


func test_arc_pylons_chain_from_every_fourth_turret_shot_that_the_turret_really_fires() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"arc_pylons": 1})
	_field(w)
	_run_until_shots(w, 3)
	assert_float(VarietyVKit.taken(w, 1)).is_equal(0.0)  # no chain before the fourth shot
	assert_float(VarietyVKit.taken(w, 0)).is_equal(3.0 * TURRET_DAMAGE)
	_run_until_shots(w, 4)
	assert_float(VarietyVKit.taken(w, 0)).is_equal(4.0 * TURRET_DAMAGE)  # the target took its four hits
	assert_float(VarietyVKit.taken(w, 1)).is_equal_approx(TURRET_DAMAGE * 0.6, 1e-5)  # 60% to the next in reach
	assert_float(VarietyVKit.taken(w, 2)).is_equal_approx(TURRET_DAMAGE * 0.6, 1e-5)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(2)


func test_flak_heads_splash_the_neighbours_of_the_target_after_every_hit() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"flak_heads": 1})
	_field(w)
	var near: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -0.6)  # 0.9 m from the target: inside 1.2
	VarietyVKit.tough(w, near)
	w.enemies.path_dist[near] = 100.0
	_run_until_shots(w, 2)
	assert_float(VarietyVKit.taken(w, 0)).is_equal(2.0 * TURRET_DAMAGE)  # the splash spares the target itself
	assert_float(VarietyVKit.taken(w, near)).is_equal_approx(2.0 * TURRET_DAMAGE * 0.4, 1e-5)
	assert_float(VarietyVKit.taken(w, 2)).is_equal(0.0)  # 2.5 m from the target: outside the splash


func test_the_splash_lands_where_the_target_stood_even_when_the_shot_killed_it() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"flak_heads": 1})
	_field(w)
	var near: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -0.6)
	VarietyVKit.tough(w, near)
	w.enemies.hp[0] = TURRET_DAMAGE  # the first shot kills the target
	w.enemies.max_hp[0] = TURRET_DAMAGE
	var target_id: int = w.enemies.id[0]
	_run_until_shots(w, 1)
	assert_int(w.enemies.alive[0]).is_equal(0)
	assert_float(VarietyVKit.taken(w, near)).is_equal_approx(TURRET_DAMAGE * 0.4, 1e-5)
	assert_int(w.turrets.target_id[0]).is_not_equal(target_id)  # and the pad looked for a new target afterwards


func test_the_turret_damage_factor_reaches_the_hooks_too() -> void:
	var w: SimWorld = VarietyVKit.directive_world({&"flak_heads": 1})
	w.mods.t_dmg_mul = 1.5
	_field(w)
	var near: int = VarietyVKit.place(w, Ids.EN_SKITTER, -1.0, -0.6)
	VarietyVKit.tough(w, near)
	_run_until_shots(w, 1)
	assert_float(VarietyVKit.taken(w, 0)).is_equal(TURRET_DAMAGE * 1.5)
	assert_float(VarietyVKit.taken(w, near)).is_equal_approx(TURRET_DAMAGE * 1.5 * 0.4, 1e-5)


func test_without_the_directives_a_turret_shot_is_just_a_shot() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	_field(w)
	_run_until_shots(w, 4)
	assert_float(VarietyVKit.taken(w, 0)).is_equal(4.0 * TURRET_DAMAGE)
	assert_float(VarietyVKit.taken(w, 1)).is_equal(0.0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.CHAIN_ARC)).is_equal(0)


# --- the pool of a landed slag mortar shell ---


func _shell(w: SimWorld, x: float, z: float, source: int = DamageSource.Id.WARDEN) -> void:
	var _seq: int = HazardSystem.queue_hit(w, w.tick + 5, HazardState.K_SHELL, x, z, 2.6, 80.0, 0.5, DamageResolver.F_AREA, source)


func test_a_landed_shell_leaves_the_pool_of_the_mortar_where_it_landed() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	var mortar: WeaponDef = w.content.weapons[Ids.WP_SLAG_MORTAR]
	assert_int(mortar.pool_ticks).is_greater(0)
	_shell(w, 4.0, 2.0)
	VarietyVKit.run(w, 4)
	assert_int(w.hazards.pool_count()).is_equal(0)  # in the air
	VarietyVKit.tick(w)  # tick 5: it lands
	assert_int(w.hazards.pool_count()).is_equal(1)
	assert_float(w.hazards.p_x[0]).is_equal(4.0)
	assert_float(w.hazards.p_z[0]).is_equal(2.0)
	assert_float(w.hazards.p_radius[0]).is_equal_approx(mortar.pool_radius_m, 1e-6)
	assert_int(w.hazards.p_ticks_left[0]).is_equal(mortar.pool_ticks - 1)  # one tick of it has run already
	assert_float(w.hazards.p_dps[0]).is_equal(mortar.pool_dps)
	assert_float(w.hazards.p_slow[0]).is_equal(mortar.pool_slow)


func test_the_pool_takes_the_level_of_the_mortar_in_the_slot_and_the_area_factor() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	ArsenalSystem.give_weapon(w, 1, Ids.WP_SLAG_MORTAR)
	w.arsenal.slot_level[1] = 3  # level 3 lengthens the pool
	w.mods.area_mul = 1.35
	var plain: WeaponDef = w.content.weapons[Ids.WP_SLAG_MORTAR]
	var leveled: WeaponDef = ArsenalSystem.effective_of(w, 1)
	assert_int(leveled.pool_ticks).is_greater(plain.pool_ticks)
	_shell(w, 4.0, 2.0)
	VarietyVKit.run(w, 5)
	assert_int(w.hazards.p_ticks_left[0]).is_equal(leveled.pool_ticks - 1)
	assert_float(w.hazards.p_radius[0]).is_equal_approx(leveled.pool_radius_m * 1.35, 1e-6)


func test_only_the_wardens_shells_leave_a_pool_and_each_shell_leaves_one() -> void:
	var enemy: SimWorld = VarietyVKit.world(1, 4)
	_shell(enemy, 4.0, 2.0, DamageSource.Id.HAZARD)
	VarietyVKit.run(enemy, 5)
	assert_int(enemy.hazards.pool_count()).is_equal(0)
	var offhand: SimWorld = VarietyVKit.world(1, 4)
	_shell(offhand, 4.0, 2.0, DamageSource.Id.WARDEN_OFFHAND)
	VarietyVKit.run(offhand, 5)
	assert_int(offhand.hazards.pool_count()).is_equal(1)
	# the landing hook is the only place a pool starts (the queue scan of ArsenalFire is gone): one shell, one pool
	var own: SimWorld = VarietyVKit.world(1, 4)
	_shell(own, 4.0, 2.0)
	VarietyVKit.run(own, 5)
	assert_int(own.hazards.pool_count()).is_equal(1)


func test_a_shell_that_lands_on_a_drum_lights_it() -> void:
	var w: SimWorld = VarietyVKit.world(1, 1)
	var p: Vector2 = HazardDrums.position_of(w, 0)
	_shell(w, p.x + 2.0, p.y)
	VarietyVKit.run(w, 5)
	assert_int(HazardDrums.alive_count(w)).is_equal(2)


# --- the drum API for stray rounds ---


func test_standing_drums_near_a_point_come_nearest_first_and_a_gone_drum_is_left_out() -> void:
	var w: SimWorld = VarietyVKit.world(1, 1)
	var a: Vector2 = HazardDrums.position_of(w, 0)
	var found: PackedInt32Array = PackedInt32Array()
	assert_int(HazardDrums.standing_near(w, a.x + 0.5, a.y, 1.0, found)).is_equal(1)
	assert_int(found[0]).is_equal(0)
	assert_int(HazardDrums.standing_near(w, a.x, a.y, 0.4, found)).is_equal(1)
	assert_int(HazardDrums.standing_near(w, a.x + 3.0, a.y, 1.0, found)).is_equal(0)
	var every: int = HazardDrums.standing_near(w, 0.0, 0.0, 100.0, found)
	assert_int(every).is_equal(3)
	var last: float = -1.0
	for k: int in found:
		var d: float = HazardDrums.position_of(w, k).length()
		assert_float(d).is_greater_equal(last)
		last = d
	HazardDrums.ignite(w, 0)
	assert_int(HazardDrums.standing_near(w, a.x, a.y, 1.0, found)).is_equal(0)


func test_rounds_sent_at_a_drum_add_up_and_light_it_at_eighty() -> void:
	var w: SimWorld = VarietyVKit.world(1, 1)
	HazardDrums.hit(w, 1, 30.0)
	HazardDrums.hit(w, 1, 30.0)
	assert_int(w.hazards.d_damage_milli[1]).is_equal(60000)
	assert_int(HazardDrums.alive_count(w)).is_equal(3)
	HazardDrums.hit(w, 1, 20.0)
	assert_int(HazardDrums.alive_count(w)).is_equal(2)
	assert_int(w.hazards.d_alive[1]).is_equal(0)
	HazardDrums.hit(w, 1, 500.0)  # a drum that is gone takes nothing
	HazardDrums.hit(w, 9, 500.0)
	HazardDrums.hit(w, -1, 500.0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)).is_equal(1)
