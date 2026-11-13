extends GdUnitTestSuite
## V4-C: the pure-data directives (ops on ModState, VARIETY_CONTENT 3): one test per family, with the exact numbers of the
## table, and for the stats a system already reads, the number that system produces. Worlds are put in a combat phase.

var w: SimWorld


func before_test() -> void:
	w = DirectiveKit.world()


func _pistol() -> WeaponDef:
	return w.content.weapons[Ids.WP_PISTOL]


func _fresh_skitter() -> int:
	return DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)


func test_weapon_stat_directives_change_exactly_their_stats() -> void:
	DirectiveKit.give(w, &"extended_feed", 2)
	assert_float(w.mods.w_mag_mul).is_equal_approx(1.6, 0.00001)
	assert_float(w.mods.w_heat_cap_mul).is_equal_approx(1.4, 0.00001)
	assert_int(ArsenalSystem.magazine_size_of(w, 0)).is_equal(19)  # 12 x 1.6 = 19.2
	DirectiveKit.give(w, &"fast_hands", 1)
	assert_float(w.mods.w_reload_mul).is_equal_approx(0.8, 0.00001)
	assert_float(w.mods.swap_ticks_add).is_equal(-9.0)
	assert_int(ArsenalSystem.reload_ticks_of(w, _pistol())).is_equal(60)  # 75 x 0.8
	assert_int(ArsenalSystem.swap_ticks(w)).is_equal(15)  # 24 - 9
	DirectiveKit.give(w, &"fast_hands", 2)
	assert_float(w.mods.swap_ticks_add).is_equal(-27.0)
	assert_int(ArsenalSystem.swap_ticks(w)).is_equal(0)  # never below 0
	DirectiveKit.give(w, &"heavy_barrel", 2)
	assert_float(w.mods.w_dmg_mul).is_equal_approx(1.7, 0.00001)
	assert_float(w.mods.w_rate_mul).is_equal_approx(0.8, 0.00001)
	assert_int(ArsenalSystem.sps_milli(w, _pistol())).is_equal(1600)  # 2000 x 0.8
	DirectiveKit.give(w, &"overpressure", 2)
	assert_float(w.mods.area_mul).is_equal_approx(1.7, 0.00001)


func test_first_strike_only_boosts_the_first_hit_on_a_full_hp_enemy() -> void:
	DirectiveKit.give(w, &"first_strike", 1)
	assert_float(w.mods.w_full_hp_mul).is_equal_approx(1.5, 0.00001)
	var i: int = _fresh_skitter()
	assert_float(DamageResolver.warden_amount(w, i, _pistol(), 1)).is_equal_approx(45.0, 0.0001)  # 30 x 1.5
	w.enemies.hp[i] = w.enemies.max_hp[i] - 1.0
	assert_float(DamageResolver.warden_amount(w, i, _pistol(), 1)).is_equal_approx(30.0, 0.0001)
	DirectiveKit.give(w, &"first_strike", 1)
	w.enemies.hp[i] = w.enemies.max_hp[i]
	assert_float(DamageResolver.warden_amount(w, i, _pistol(), 1)).is_equal_approx(60.0, 0.0001)  # 30 x 2.0


func test_executioner_bonus_does_not_stack_but_its_threshold_does() -> void:
	DirectiveKit.give(w, &"executioner", 1)
	assert_float(w.mods.w_low_hp_mul).is_equal_approx(1.6, 0.00001)
	assert_float(w.mods.w_low_hp_threshold).is_equal_approx(0.30, 0.00001)
	var i: int = _fresh_skitter()  # 45 hp
	w.enemies.hp[i] = 9.0  # 20%
	assert_float(DamageResolver.warden_amount(w, i, _pistol(), 1)).is_equal_approx(48.0, 0.0001)  # 30 x 1.6
	w.enemies.hp[i] = 15.75  # 35%
	assert_float(DamageResolver.warden_amount(w, i, _pistol(), 1)).is_equal_approx(30.0, 0.0001)
	DirectiveKit.give(w, &"executioner", 1)
	assert_float(w.mods.w_low_hp_mul).is_equal_approx(1.6, 0.00001)  # the bonus stays +60%
	assert_float(w.mods.w_low_hp_threshold).is_equal_approx(0.40, 0.00001)
	assert_float(DamageResolver.warden_amount(w, i, _pistol(), 1)).is_equal_approx(48.0, 0.0001)  # 35% is below 40%
	w.enemies.hp[i] = 20.25  # 45%
	assert_float(DamageResolver.warden_amount(w, i, _pistol(), 1)).is_equal_approx(30.0, 0.0001)


func test_turret_stat_directives() -> void:
	DirectiveKit.give(w, &"turret_deploy", 1)
	DirectiveKit.give(w, &"turret_servos", 4)
	assert_float(w.mods.t_rate_mul).is_equal_approx(2.0, 0.00001)
	DirectiveKit.give(w, &"turret_heavy_slugs", 2)
	assert_float(w.mods.t_dmg_mul).is_equal_approx(1.6, 0.00001)
	DirectiveKit.give(w, &"sentry_link")
	assert_float(w.mods.t_inherit).is_equal(0.5)
	DirectiveKit.give(w, &"pad_capacitors")
	assert_bool(w.mods.has_flag(&"od_turrets")).is_true()
	DirectiveKit.give(w, &"last_stand_protocol")
	assert_bool(w.mods.has_flag(&"last_stand")).is_true()
	assert_int(w.turrets.active_count()).is_equal(1)


func test_ground_wire_slows_the_enemy_attack_timer_of_the_core_attack() -> void:
	DirectiveKit.give(w, &"ground_wire", 2)
	assert_float(w.mods.enemy_attack_period_mul).is_equal_approx(1.5, 0.00001)
	var i: int = DirectiveKit.attacker(w)  # a skitter: 1.5 s = 90 ticks
	w.enemies.attack_cd[i] = 1
	DirectiveKit.begin_tick(w)
	CoreAttackSystem.step(w)
	assert_int(w.enemies.attack_cd[i]).is_equal(135)  # 90 x 1.5
	assert_float(w.core_hp).is_equal(988.0)


func test_field_weld_repairs_now_and_sets_the_wave_repair() -> void:
	w.set_core_hp(500.0)
	DirectiveKit.give(w, &"field_weld")
	assert_float(w.core_hp).is_equal_approx(620.0, 0.001)  # +12% of 1000
	assert_float(w.mods.core_regen_wave).is_equal_approx(0.02, 0.00001)
	DirectiveKit.give(w, &"field_weld", 2)
	assert_float(w.mods.core_regen_wave).is_equal_approx(0.06, 0.00001)
	assert_float(w.core_hp).is_equal_approx(860.0, 0.001)  # two more 12% repairs: 620 + 120 + 120
	assert_float(w.core_max_hp).is_equal(1000.0)


func test_ability_stat_directives() -> void:
	DirectiveKit.give(w, &"shield_lattice", 2)
	assert_float(w.mods.shield_absorb_add).is_equal(120.0)
	assert_float(w.mods.shield_dur_add).is_equal(4.0)
	DirectiveKit.give(w, &"overdrive_coolant", 3)
	assert_float(w.mods.od_dur_add).is_equal(6.0)
	assert_float(w.mods.od_cd_mul).is_equal_approx(0.7, 0.00001)
	DirectiveKit.give(w, &"emp_tether", 2)
	assert_float(w.mods.emp_stun_add).is_equal(3.0)
	assert_float(w.mods.stunned_dmg_mul).is_equal_approx(1.5, 0.00001)
	var i: int = _fresh_skitter()
	w.enemies.stun_ticks[i] = 60
	var stunned: float = DamageResolver.warden_amount(w, i, _pistol(), 1)
	assert_float(stunned).is_equal_approx(30.0 * _pistol().stunned_mult * 1.5, 0.0001)
	DirectiveKit.give(w, &"emp_capacitor", 3)
	assert_float(w.mods.emp_cd_mul).is_equal_approx(0.55, 0.00001)


func test_deadfall_uplink_and_signal_hijack_add_charges_now_and_at_each_act_start() -> void:
	var strike: int = w.content.event_index(&"deadfall_strike")
	assert_int(w.events_state.charges[strike]).is_equal(1)
	DirectiveKit.give(w, &"deadfall_uplink")
	assert_float(w.mods.strike_per_act).is_equal(1.0)
	assert_int(w.events_state.charges[strike]).is_equal(2)  # +1 now
	w.wave = 2  # not an act start: nothing more
	ModSystem.set_wave_modifier(w, -1)
	assert_int(w.events_state.charges[strike]).is_equal(2)
	w.wave = 1  # the first wave of act I
	ModSystem.set_wave_modifier(w, -1)
	assert_int(w.events_state.charges[strike]).is_equal(3)
	ModSystem.set_wave_modifier(w, -1)
	assert_int(w.events_state.charges[strike]).is_equal(3)  # the cap of the event is 3
	DirectiveKit.give(w, &"deadfall_uplink")
	assert_float(w.mods.strike_per_act).is_equal(2.0)
	assert_int(w.events_state.charges[strike]).is_equal(3)
	DirectiveKit.give(w, &"signal_hijack")  # the freight call is not in the slice events: nothing breaks
	assert_float(w.mods.freight_per_act).is_equal(1.0)


func test_economy_stat_directives() -> void:
	DirectiveKit.give(w, &"scavenger_protocol", 2)
	assert_float(w.mods.scrap_mul).is_equal_approx(1.5, 0.00001)
	var i: int = _fresh_skitter()  # 5 Scrap
	assert_int(DeathHooks.scrap_for(w, i, DamageSource.Id.WARDEN)).is_equal(8)  # 7.5 rounds up
	DirectiveKit.give(w, &"black_box", 2)
	assert_float(w.mods.crate_choices).is_equal(2.0)
	DirectiveKit.give(w, &"salvage_drone")
	assert_float(w.mods.crate_time_mul).is_equal_approx(0.5, 0.00001)
	assert_bool(w.mods.has_flag(&"crate_never_lost")).is_true()
	assert_int(SalvageSystem.secure_ticks(w)).is_equal(360)  # 12 s x 0.5
	DirectiveKit.give(w, &"data_siphon", 2)
	assert_float(w.mods.data_per_wave).is_equal(4.0)


func test_requisition_line_halves_reroll_prices_and_gives_a_free_reroll() -> void:
	DirectiveKit.give(w, &"requisition_line")
	assert_int(w.draft.free_rerolls).is_equal(1)
	assert_float(w.mods.reroll_cost_mul).is_equal_approx(0.5, 0.00001)
	w.draft.free_rerolls = 0
	assert_int(DraftSystem.reroll_cost(w)).is_equal(30)  # 60 x 0.5
	w.draft.rerolls_paid = 2
	assert_int(DraftSystem.reroll_cost(w)).is_equal(70)  # (60 + 2 x 40) x 0.5
	DirectiveKit.give(w, &"requisition_line")
	assert_float(w.mods.reroll_cost_mul).is_equal_approx(0.0, 0.00001)
	assert_int(w.draft.free_rerolls).is_equal(1)
	w.draft.free_rerolls = 0
	assert_int(DraftSystem.reroll_cost(w)).is_equal(0)


func test_quartermaster_offers_four_directives() -> void:
	assert_int(VarietyBKit.offer_n(w, 0).size()).is_equal(3)
	DirectiveKit.give(w, &"quartermaster")
	assert_float(w.mods.draft_slots).is_equal(1.0)
	var offer: PackedInt32Array = VarietyBKit.offer_n(w, 1)
	assert_int(offer.size()).is_equal(4)
	var seen: Dictionary[int, bool] = {}
	for index: int in offer:
		seen[index] = true
	assert_int(seen.size()).is_equal(4)  # no duplicate in one offer


func test_corrupted_data_directives_gain_and_price() -> void:
	DirectiveKit.give(w, &"glass_cannon")
	DirectiveKit.give(w, &"open_gate")
	assert_float(w.mods.scrap_mul).is_equal_approx(1.6, 0.00001)
	assert_float(w.mods.spawn_interval_mul).is_equal_approx(0.75, 0.00001)
	DirectiveKit.give(w, &"overclocked_core")
	assert_float(w.mods.ability_cd_mul).is_equal_approx(0.6, 0.00001)
	DirectiveKit.give(w, &"chorus_handshake")
	assert_float(w.mods.extra_elites).is_equal(1.0)
	assert_float(w.mods.w_dmg_mul).is_equal_approx(1.8, 0.00001)
	assert_float(w.core_max_hp).is_equal(700.0)


func test_single_point_trades_the_turrets_for_damage_and_rate() -> void:
	DirectiveKit.give(w, &"turret_deploy", 2)
	assert_int(w.turrets.active_count()).is_equal(2)
	DirectiveKit.give(w, &"single_point")
	assert_float(w.mods.w_dmg_mul).is_equal_approx(1.6, 0.00001)
	assert_float(w.mods.w_rate_mul).is_equal_approx(1.3, 0.00001)
	assert_bool(w.mods.has_flag(&"pads_disabled")).is_true()
	assert_int(w.turrets.active_count()).is_equal(0)
	assert_int(w.upgrade_levels[Ids.UP_AUTO_TURRET]).is_equal(0)
	assert_bool(EconomySystem.has_free_pad(w)).is_false()
	assert_bool(DraftOffer.candidates(w).has(w.content.directive_index(&"turret_deploy"))).is_false()
	ModSystem.recompute(w)  # a later recompute does not bring a turret back
	assert_int(w.turrets.active_count()).is_equal(0)


func test_bottomless_and_scrap_rounds_set_their_flags() -> void:
	DirectiveKit.give(w, &"bottomless")
	assert_bool(w.mods.has_flag(&"od_free_ammo")).is_true()
	DirectiveKit.give(w, &"scrap_rounds")
	assert_bool(w.mods.has_flag(&"scrap_rounds")).is_true()
