extends GdUnitTestSuite
## V2-C: heat weapons (VARIETY_SPEC 3.3, ARCH 6.5 integer rules) and the unchanged cadence of magazine weapons.
## Arc projector: 1.6 shots per second (1600 milli per tick, a shot costs 60000), 12 heat per shot (V5-C: was 14), cap
## 100, vent 150 ticks, cooling 20 per second = 1 heat every 3 ticks. With a target always present the shots leave on
## ticks 38, 75, 113, 150, 188, 225, 263, 300, 338; the 9th brings the heat to 108 >= 100, so the weapon vents on ticks
## 339 .. 487 and fires again on tick 488 with heat 0 + 12.
## The accumulator rule is the legacy one: it clamps at one shot while no shot is allowed.


func _arc_world() -> SimWorld:
	var w: SimWorld = VarietyCKit.world()
	ArsenalSystem.give_weapon(w, 0, Ids.WP_ARC_PROJECTOR)
	return w


func _with_target(w: SimWorld) -> int:
	var i: int = VarietyCKit.place_rel(w, Ids.EN_HULK, 10.0, 0.0)
	VarietyCKit.tough(w, i)
	return i


func test_nine_shots_then_a_vent_of_exactly_150_ticks() -> void:
	var w: SimWorld = _arc_world()
	_with_target(w)
	var ticks: Array[int] = VarietyCKit.shot_ticks(w, 338)
	assert_array(ticks).is_equal([38, 75, 113, 150, 188, 225, 263, 300, 338])
	assert_int(w.arsenal.slot_heat[0]).is_equal(100)  # clamped at the cap
	assert_int(w.arsenal.slot_vent_left[0]).is_equal(150)
	assert_int(ArsenalSystem.slot_state(w, 0)).is_equal(ArsenalSystem.ST_VENTING)
	var vented: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.WEAPON_VENTED)
	assert_int(vented.size()).is_equal(1)
	assert_int(vented[0].tick).is_equal(338)
	assert_int(vented[0].a).is_equal(0)
	assert_int(vented[0].b).is_equal(150)
	assert_array(VarietyCKit.shot_ticks(w, 149)).is_empty()  # ticks 339 .. 487
	assert_int(w.arsenal.slot_heat[0]).is_equal(100)
	assert_int(ArsenalSystem.slot_ticks_left(w, 0)).is_equal(1)
	# heat restarts at 0 and the first shot is immediate; it leaves 1600 milli over, so the next comes 37 ticks later
	assert_array(VarietyCKit.shot_ticks(w, 40)).is_equal([488, 525])
	assert_int(w.arsenal.slot_heat[0]).is_equal(24)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.RELOAD_STARTED)).is_equal(0)  # a heat weapon never reloads


func test_heat_rises_12_per_shot_and_does_not_cool_between_the_shots_of_a_burst() -> void:
	var w: SimWorld = _arc_world()
	_with_target(w)
	VarietyCKit.run_weapon(w, 38)
	assert_int(w.arsenal.slot_heat[0]).is_equal(12)
	VarietyCKit.run_weapon(w, 36)  # tick 74, just before the second shot
	assert_int(w.arsenal.slot_heat[0]).is_equal(12)
	VarietyCKit.run_weapon(w, 39)  # tick 113: three shots
	assert_int(w.arsenal.slot_heat[0]).is_equal(36)
	assert_int(w.warden.magazine).is_equal(0)
	assert_int(w.warden.reload_ticks_left).is_equal(0)


func test_an_idle_weapon_cools_one_heat_every_three_ticks() -> void:
	var w: SimWorld = _arc_world()
	var target: int = _with_target(w)
	VarietyCKit.run_weapon(w, 113)
	assert_int(w.arsenal.slot_heat[0]).is_equal(36)
	w.kill_enemy(target, DamageSource.Id.WARDEN)  # nothing left to shoot at
	VarietyCKit.run_weapon(w, 2)
	assert_int(w.arsenal.slot_heat[0]).is_equal(36)
	VarietyCKit.run_weapon(w, 1)
	assert_int(w.arsenal.slot_heat[0]).is_equal(35)
	VarietyCKit.run_weapon(w, 27)  # 30 idle ticks
	assert_int(w.arsenal.slot_heat[0]).is_equal(26)
	VarietyCKit.run_weapon(w, 77)  # 107 idle ticks
	assert_int(w.arsenal.slot_heat[0]).is_equal(1)
	VarietyCKit.run_weapon(w, 1)  # 108 = 36 x 3
	assert_int(w.arsenal.slot_heat[0]).is_equal(0)
	VarietyCKit.run_weapon(w, 30)
	assert_int(w.arsenal.slot_heat[0]).is_equal(0)
	assert_int(w.arsenal.slot_cool_acc[0]).is_equal(0)


func test_a_holstered_weapon_cools_at_full_speed_and_finishes_its_vent() -> void:
	var w: SimWorld = VarietyCKit.world()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_ARC_PROJECTOR)
	w.arsenal.slot_heat[1] = 42
	VarietyCKit.run_weapon(w, 60)
	assert_int(w.arsenal.slot_heat[1]).is_equal(22)
	VarietyCKit.run_weapon(w, 66)
	assert_int(w.arsenal.slot_heat[1]).is_equal(0)
	w.arsenal.slot_heat[1] = 100
	w.arsenal.slot_vent_left[1] = 150
	VarietyCKit.run_weapon(w, 149)
	assert_int(w.arsenal.slot_heat[1]).is_equal(100)
	assert_int(ArsenalSystem.slot_state(w, 1)).is_equal(ArsenalSystem.ST_VENTING)
	VarietyCKit.run_weapon(w, 1)
	assert_int(w.arsenal.slot_heat[1]).is_equal(0)
	assert_int(ArsenalSystem.slot_state(w, 1)).is_equal(ArsenalSystem.ST_READY)


func test_swapping_away_from_a_venting_weapon_keeps_the_vent_running() -> void:
	var w: SimWorld = _arc_world()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_PISTOL)
	_with_target(w)
	VarietyCKit.run_weapon(w, 338)  # overheated on tick 338
	assert_int(VarietyCKit.swap_on_next_tick(w, 1)).is_equal(Reason.Id.OK)  # tick 339
	assert_int(w.arsenal.slot_vent_left[0]).is_equal(149)
	# the pistol speaks while the projector vents: the cadence accumulator is the Warden's one and swapping does not reset
	# it, so the pistol (2.2 shots a second since V5-C: a round every 27 or 28 ticks) fires on tick 365, the next 28 later
	assert_array(VarietyCKit.shot_ticks(w, 60)).is_equal([365, 393])
	VarietyCKit.run_weapon(w, 89)  # tick 488
	assert_int(w.arsenal.slot_vent_left[0]).is_equal(0)
	assert_int(w.arsenal.slot_heat[0]).is_equal(0)


func test_heat_capacity_and_vent_time_follow_the_modifiers() -> void:
	var w: SimWorld = _arc_world()
	w.mods.w_heat_cap_mul = 1.2
	w.mods.w_reload_mul = 0.8
	_with_target(w)
	assert_int(ArsenalSystem.heat_cap_of(w, 0)).is_equal(120)
	var ticks: Array[int] = VarietyCKit.shot_ticks(w, 375)
	assert_int(ticks.size()).is_equal(10)  # 10 x 12 = 120 >= 120
	assert_int(ticks[9]).is_equal(375)
	assert_int(w.arsenal.slot_vent_left[0]).is_equal(120)  # 150 x 0.8
	assert_array(VarietyCKit.shot_ticks(w, 120)).is_equal([495])


func test_the_fire_rate_follows_the_level_overdrive_and_the_rate_modifier() -> void:
	var w: SimWorld = _arc_world()
	var arc: WeaponDef = w.content.weapons[Ids.WP_ARC_PROJECTOR]
	assert_int(ArsenalSystem.sps_milli(w, arc)).is_equal(1600)
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(1600)
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 2  # cyclic_tuning x2: +30%
	assert_int(ArsenalSystem.sps_milli(w, arc)).is_equal(2080)
	w.mods.w_rate_mul = 0.9  # heavy_barrel
	assert_int(ArsenalSystem.sps_milli(w, arc)).is_equal(1872)
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 10
	assert_int(ArsenalSystem.sps_milli(w, arc)).is_equal(3744)


func test_the_pistol_timeline_on_variety_content() -> void:
	# V5-C: 2.2 shots a second (the legacy pistol fired 2): rounds 28 or 27 ticks apart, 12 a magazine, a 75-tick reload
	var w: SimWorld = VarietyCKit.world()
	_with_target(w)
	var ticks: Array[int] = VarietyCKit.shot_ticks(w, 900)
	assert_int(ticks[0]).is_equal(28)
	assert_int(ticks[11]).is_equal(328)
	assert_int(ticks[12]).is_equal(403)
	assert_int(ticks[13]).is_equal(430)
	assert_int(ticks[14]).is_equal(457)
	assert_int(ticks[23]).is_equal(702)
	assert_int(ticks[24]).is_equal(777)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(w.warden.magazine)


func test_pistol_and_smg_shot_counts_match_the_legacy_world_over_3600_ticks() -> void:
	for weapon: int in [Ids.WP_PISTOL, Ids.WP_SMG]:
		var w: SimWorld = VarietyCKit.world()
		ArsenalSystem.give_weapon(w, 0, weapon)
		_with_target(w)
		var legacy: SimWorld = CombatTestKit.world()
		# V5-C tuned the pistol and the smg of the variety data: the legacy world fires the same numbers, so the comparison
		# is still the arsenal path against the legacy warden path
		var tuned: WeaponDef = w.content.weapons[weapon]
		var old: WeaponDef = legacy.content.weapons[weapon]
		old.damage = tuned.damage
		old.sps_milli = tuned.sps_milli
		old.magazine = tuned.magazine
		old.reload_ticks = tuned.reload_ticks
		legacy.warden.weapon_index = weapon
		legacy.warden.magazine = legacy.content.weapons[weapon].magazine
		CombatTestKit.make_tough(legacy, CombatTestKit.place(legacy, Ids.EN_HULK, 10.0, 0.0))
		var ours: Array[int] = VarietyCKit.shot_ticks(w, 3600)
		var theirs: PackedInt32Array = CombatTestKit.warden_shot_ticks(legacy, 3600)
		assert_array(ours).is_equal(Array(theirs))
		var def: WeaponDef = w.content.weapons[weapon]
		assert_int(ours.size()).is_equal(CombatTestKit.model_shots(def.sps_milli, def.magazine, def.reload_ticks, 3600))
		assert_int(VarietyCKit.count(w, SimEventKind.Id.RELOAD_STARTED)).is_equal(
			CombatTestKit.count(legacy, SimEventKind.Id.RELOAD_STARTED)
		)
		assert_int(VarietyCKit.count(w, SimEventKind.Id.RELOAD_FINISHED)).is_equal(
			CombatTestKit.count(legacy, SimEventKind.Id.RELOAD_FINISHED)
		)
		assert_float(VarietyCKit.taken(w, 0)).is_equal(CombatTestKit.TOUGH_HP - legacy.enemies.hp[0])


func test_the_legacy_world_does_not_use_the_arsenal() -> void:
	var legacy: SimWorld = CombatTestKit.world()
	CombatTestKit.make_tough(legacy, CombatTestKit.place(legacy, Ids.EN_HULK, 10.0, 0.0))
	var before: StateHasher = StateHasher.new()
	legacy.arsenal.hash_into(before)
	CombatTestKit.run_warden(legacy, 500)
	var after: StateHasher = StateHasher.new()
	legacy.arsenal.hash_into(after)
	assert_str(after.finish()).is_equal(before.finish())
	assert_int(legacy.warden.shots_fired).is_equal(15)
