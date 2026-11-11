extends GdUnitTestSuite
## SimRunApi: queries read the live sim, block reasons are the real ones from SimWorld, an unbound API is safe.


func before_test() -> void:
	GameRunKit.fresh_save()


func after_test() -> void:
	GameRunKit.reset_save()


func _combat_controller(scrap: int = 0) -> RunController:
	var cfg: SimConfig = GameRunKit.config()
	cfg.debug_start_scrap = scrap
	var rc: RunController = GameRunKit.controller(self, cfg)
	GameRunKit.frames(rc, rc.sim.content.mission.prepare_ticks + 10)
	return rc


func test_an_unbound_api_returns_the_safe_defaults() -> void:
	var api: SimRunApi = SimRunApi.new()
	assert_int(api.phase()).is_equal(GameState.Id.PREPARING)
	assert_float(api.core_hp()).is_equal(0.0)
	assert_int(api.scrap()).is_equal(0)
	assert_int(api.upgrade_cost(&"damage")).is_equal(-1)
	assert_int(api.purchase_block_reason(&"damage")).is_equal(Reason.Id.WRONG_STATE)
	assert_int(api.ability_block_reason(&"emp")).is_equal(Reason.Id.WRONG_STATE)
	assert_float(api.boss_hp()).is_equal(-1.0)
	assert_bool(api.is_paused()).is_false()
	api.purchase_upgrade(1, &"damage")  # no controller, no crash
	api.pause()


func test_the_basic_queries_mirror_the_sim() -> void:
	var rc: RunController = _combat_controller(600)
	var api: SimRunApi = rc.api
	var content: ContentSet = rc.sim.content
	assert_int(api.phase()).is_equal(rc.sim.phase)
	assert_int(api.wave()).is_equal(1)
	assert_int(api.wave_count()).is_equal(content.waves.size())
	assert_float(api.core_hp()).is_equal(rc.sim.core_hp)
	assert_float(api.core_max_hp()).is_equal(content.mission.core_max_hp)
	assert_float(api.shield_max()).is_equal(content.abilities[Ids.AB_SHIELD].absorb)
	assert_int(api.scrap()).is_equal(rc.sim.scrap)
	assert_int(api.alive_count()).is_equal(rc.sim.alive_count())
	assert_int(api.pending_spawn_count()).is_equal(SpawnSystem.pending_count(rc.sim))
	assert_str(String(api.weapon_id())).is_equal("pistol")
	assert_int(api.magazine()).is_equal(rc.sim.warden.magazine)
	assert_int(api.magazine_size()).is_equal(content.weapons[0].magazine)


func test_upgrade_queries_use_the_ids_and_the_sim_cost() -> void:
	var rc: RunController = _combat_controller(600)
	var api: SimRunApi = rc.api
	assert_int(api.upgrade_level(&"damage")).is_equal(0)
	assert_int(api.upgrade_max_level(&"damage")).is_equal(rc.sim.content.upgrades[Ids.UP_DAMAGE].max_level)
	assert_int(api.upgrade_cost(&"damage")).is_equal(rc.sim.upgrade_cost(Ids.UP_DAMAGE))
	assert_int(api.upgrade_cost(&"nonsense")).is_equal(-1)
	assert_int(api.upgrade_level(&"nonsense")).is_equal(0)
	api.purchase_upgrade(api.next_command_id(), &"damage")
	GameRunKit.frames(rc, 1)
	assert_int(api.upgrade_level(&"damage")).is_equal(1)
	assert_int(api.upgrade_cost(&"damage")).is_equal(rc.sim.upgrade_cost(Ids.UP_DAMAGE))


func test_purchase_block_reasons_are_the_real_ones() -> void:
	var rc: RunController = _combat_controller(0)
	var api: SimRunApi = rc.api
	assert_int(api.purchase_block_reason(&"damage")).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_int(api.purchase_block_reason(&"smg_unlock")).is_equal(rc.sim.purchase_block_reason(Ids.UP_SMG))
	assert_int(api.purchase_block_reason(&"nonsense")).is_equal(Reason.Id.UNKNOWN_ID)
	rc.sim.scrap = 5000
	assert_int(api.purchase_block_reason(&"damage")).is_equal(Reason.Id.OK)
	rc.sim.upgrade_levels[Ids.UP_DAMAGE] = rc.sim.content.upgrades[Ids.UP_DAMAGE].max_level
	assert_int(api.purchase_block_reason(&"damage")).is_equal(Reason.Id.MAX_LEVEL)


func test_ability_block_reasons_are_wrong_state_in_preparing_and_real_in_combat() -> void:
	var cfg: SimConfig = GameRunKit.config()
	var rc: RunController = GameRunKit.controller(self, cfg)
	assert_int(rc.sim.phase).is_equal(GameState.Id.PREPARING)
	for id: StringName in Ids.ABILITIES:
		assert_int(rc.api.ability_block_reason(id)).is_equal(Reason.Id.WRONG_STATE)  # the HUD shows "standby"
	GameRunKit.frames(rc, rc.sim.content.mission.prepare_ticks + 5)
	assert_int(rc.api.ability_block_reason(&"emp")).is_equal(Reason.Id.OK)
	rc.api.activate_ability(rc.api.next_command_id(), &"emp")
	GameRunKit.frames(rc, 1)
	assert_int(rc.api.ability_block_reason(&"emp")).is_equal(Reason.Id.ON_COOLDOWN)
	assert_int(rc.api.ability_block_reason(&"nonsense")).is_equal(Reason.Id.UNKNOWN_ID)


func test_ability_timers_report_cooldown_and_active_time() -> void:
	var rc: RunController = _combat_controller()
	var api: SimRunApi = rc.api
	var content: ContentSet = rc.sim.content
	assert_int(api.ability_cooldown_total(&"emp")).is_equal(content.abilities[Ids.AB_EMP].cooldown_ticks)
	assert_int(api.ability_active_total(&"shield")).is_equal(content.abilities[Ids.AB_SHIELD].duration_ticks)
	api.activate_ability(api.next_command_id(), &"shield")
	GameRunKit.frames(rc, 1)
	assert_int(api.ability_active_left(&"shield")).is_greater(0)
	assert_float(api.shield_hp()).is_greater(0.0)
	assert_int(api.ability_cooldown_left(&"emp")).is_equal(0)


func test_the_phase_countdown_and_deploy_state_are_visible_before_combat() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	GameRunKit.frames(rc, 10)
	assert_int(rc.api.phase()).is_equal(GameState.Id.PREPARING)
	assert_int(rc.api.phase_ticks_left()).is_equal(rc.sim.content.mission.prepare_ticks - 10)
	assert_int(rc.api.wave()).is_equal(0)


func test_pause_and_resume_go_through_the_controller() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	rc.api.pause()
	assert_bool(rc.paused).is_true()
	assert_bool(rc.api.is_paused()).is_true()
	rc.api.resume()
	assert_bool(rc.paused).is_false()
	assert_bool(rc.api.is_paused()).is_false()


func test_the_boss_queries_follow_the_store() -> void:
	var rc: RunController = _combat_controller()
	assert_float(rc.api.boss_hp()).is_equal(-1.0)
	var i: int = rc.sim.spawn_enemy(Ids.EN_HULK, 5.0, 5.0)
	assert_int(i).is_greater_equal(0)
	assert_float(rc.api.boss_hp()).is_equal(rc.sim.enemies.hp[i])
	assert_float(rc.api.boss_max_hp()).is_equal(rc.sim.content.enemies[Ids.EN_HULK].hp)
