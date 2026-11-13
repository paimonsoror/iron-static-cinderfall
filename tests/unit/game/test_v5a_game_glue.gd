extends GdUnitTestSuite
## V5-A: the game-layer glue of the 15-wave integration without a scene tree: the debug starts in the launch arguments
## and in the run file, the closing reward of a run that cannot be resumed (the banked Data of its boundary), the Archive
## facts of a run that is not live any more, the Daily Run's kit, the relay of the two new sim events and the ability
## cooldown the HUD's radial reads.

var _log: GameSignalLog


func before_test() -> void:
	GameRunKit.fresh_save()
	_log = GameSignalLog.new()
	_log.attach()


func after_test() -> void:
	_log.detach()
	GameRunFlow.set_launch(&"", false)
	GameRunKit.reset_save()


func _args(list: Array[String]) -> DebugArgs:
	return DebugArgs.parse(PackedStringArray(list))


# --- the debug starts ---


func test_the_scenario_argument_names_a_start_wave_or_a_boss() -> void:
	assert_int(GameLaunch.start_wave_of(_args(["--scenario=wave:7"]))).is_equal(7)
	assert_int(GameLaunch.start_wave_of(_args(["--scenario=wave:x"]))).is_equal(0)
	assert_int(GameLaunch.start_wave_of(_args(["--scenario=hold50"]))).is_equal(0)
	assert_int(GameLaunch.start_wave_of(_args([]))).is_equal(0)
	assert_str(String(GameLaunch.boss_of(_args(["--scenario=boss:tremor_rig"])))).is_equal("tremor_rig")
	assert_str(String(GameLaunch.boss_of(_args(["--scenario=boss"])))).is_equal("")  # the sandbox scenario, not a game start
	assert_str(String(GameLaunch.boss_of(_args(["--scenario=wave:7"])))).is_equal("")
	assert_bool(GameLaunch.wants_autostart(_args(["--scenario=wave:7"]))).is_true()
	assert_bool(GameLaunch.wants_autostart(_args(["--scenario=boss:hulk_fed"]))).is_true()
	assert_bool(GameLaunch.wants_autostart(_args(["--scenario=wave:1"]))).is_false()  # wave 1 is a normal start
	assert_bool(GameLaunch.wants_autostart(_args(["--seed=4"]))).is_false()


func test_configure_puts_the_debug_start_into_the_sim_config() -> void:
	var rc: RunController = RunController.new()
	auto_free(rc)
	var config: SimConfig = SimConfig.create(TestContent.variety(), 3)
	GameLaunch.configure(config, rc, _args(["--scenario=wave:11"]), 3)
	assert_int(config.debug_start_wave).is_equal(11)
	assert_str(String(config.debug_boss)).is_equal("")
	assert_bool(config.is_debug()).is_true()
	assert_object(rc.scenario).is_null()  # not a hold scenario: the run file is written as usual
	var boss: SimConfig = SimConfig.create(TestContent.variety(), 3)
	GameLaunch.configure(boss, rc, _args(["--scenario=boss:aegis_array"]), 3)
	assert_str(String(boss.debug_boss)).is_equal("aegis_array")
	var plain: SimConfig = SimConfig.create(TestContent.variety(), 3)
	GameLaunch.configure(plain, rc, _args(["--seed=3"]), 3)
	assert_bool(plain.is_debug()).is_false()


func test_the_run_file_keeps_a_debug_start_so_such_a_run_resumes() -> void:
	var config: SimConfig = SimConfig.create(TestContent.variety(), 5)
	config.debug_start_wave = 6
	config.debug_boss = &"hulk_plated"
	var world: SimWorld = SimWorld.new(config)
	var doc: Dictionary = RunFile.compose(RunFile.header(config, "900-5"), RunFile.boundary(world), world.command_log.to_dicts(), -1)
	var back: Dictionary = RunStore.decode(RunStore.encode(doc))
	var again: SimConfig = RunFile.config_from(back, config.content)
	assert_int(again.debug_start_wave).is_equal(6)
	assert_str(String(again.debug_boss)).is_equal("hulk_plated")
	var rebuilt: RunResumeResult = RunResume.rebuild(back, config.content)
	assert_bool(rebuilt.ok()).is_true()
	assert_int(rebuilt.mode).is_equal(RunResume.Mode.SNAPSHOT)
	assert_str(rebuilt.world.state_hash()).is_equal(world.state_hash())
	assert_int(rebuilt.world.waves_completed).is_equal(14)


# --- the closing reward ---


func test_a_run_that_cannot_be_resumed_is_paid_what_it_had_banked() -> void:
	var content: ContentSet = TestContent.variety()
	var world: SimWorld = SimWorld.new(SimConfig.create(content, 5))
	world.waves_completed = 7
	world.stats.data = 6 * 7 + 30 + 15  # seven waves, the act I boss, one rw_data route
	var doc: Dictionary = RunFile.compose(RunFile.header(world.config, "900-5"), RunFile.boundary(world), world.command_log.to_dicts(), -1)
	var back: Dictionary = RunStore.decode(RunStore.encode(doc))
	assert_int(RunFile.closing_reward(back, content)).is_equal(87)
	# a document without the counter pays the waves; a damaged or edited number never more than a whole run could bank
	var boundary: Dictionary = back["boundary"]
	var state: Dictionary = boundary["state"]
	var stats: Dictionary = state["stats"]
	stats.erase("data")
	assert_int(RunFile.closing_reward(back, content)).is_equal(6 * 7)
	stats["data"] = 1000000.0
	assert_int(RunFile.closing_reward(back, content)).is_equal(RunFile.closing_cap(content))
	assert_int(RunFile.closing_cap(content)).is_equal(15 * 36 + 75)
	stats["data"] = -5.0
	assert_int(RunFile.closing_reward(back, content)).is_equal(6 * 7)


# --- rewards ---


func test_a_debug_run_and_a_legacy_run_leave_no_archive_facts() -> void:
	var content: ContentSet = TestContent.variety()
	var plain: SimConfig = SimConfig.create(content, 1)
	plain.kit_index = content.kit_index(&"k_signal")
	plain.daily = true
	var launch: Dictionary = GameRewards.launch_from(plain)
	assert_str(str(launch["kit"])).is_equal("k_signal")
	assert_bool(launch["daily"]).is_true()
	for switch: int in 5:
		var debug: SimConfig = SimConfig.create(content, 1)
		match switch:
			0:
				debug.debug_damage_mult = 4.0
			1:
				debug.debug_invulnerable_core = true
			2:
				debug.debug_start_scrap = 100
			3:
				debug.debug_start_wave = 5
			4:
				debug.debug_boss = &"tremor_rig"
		assert_bool(GameRewards.launch_from(debug).is_empty()).override_failure_message("switch %d" % switch).is_true()
	assert_bool(GameRewards.launch_from(SimConfig.create(TestContent.baseline(), 1)).is_empty()).is_true()
	assert_bool(GameRewards.launch_from(null).is_empty()).is_true()


func test_a_finished_run_found_on_resume_is_paid_with_its_archive_facts() -> void:
	var content: ContentSet = TestContent.variety()
	Save.use_content(content)
	var config: SimConfig = SimConfig.create(content, 9)
	var summary: RunSummary = RunSummary.new()
	summary.run_id = "1700000000-9"
	summary.result = RunResult.Id.DEFEAT
	summary.waves_completed = 7
	summary.act_reached = 2
	summary.data_reward = 72
	summary.kills_by_type = PackedInt32Array()
	summary.kills_by_type.resize(content.enemies.size())
	summary.kills_by_type[Ids.EN_BROOD_CARRIER] = 1
	summary.weapons = PackedInt32Array([Ids.WP_PISTOL, Ids.WP_SMG, -1])
	assert_bool(GameRewards.grant(summary, config)).is_true()  # no live run: the config of the rebuilt one says how it started
	assert_int(Save.profile.best_wave).is_equal(7)
	var kills: int = Save.profile.boss_kills.get("brood_carrier", 0)
	assert_int(kills).is_equal(1)
	assert_bool(Save.profile.claimed.has("ms_first_boss_brood_carrier")).is_true()
	assert_int(Save.profile.data).is_equal(72 + 50)
	assert_bool(GameRewards.grant(summary, config)).is_false()  # once
	# without the config it is the plain Data grant (a stale file closed at launch)
	summary.run_id = "1700000001-9"
	assert_bool(GameRewards.grant(summary)).is_true()
	kills = Save.profile.boss_kills.get("brood_carrier", 0)
	assert_int(kills).is_equal(1)
	Save.use_content(null)


func test_a_daily_run_always_takes_the_standard_kit() -> void:
	var content: ContentSet = TestContent.variety()
	GameRunFlow.set_launch(&"k_gunline", true)
	var config: SimConfig = SimConfig.create(content, 1)
	GameRunFlow.apply_launch(config, content, _args([]))
	assert_bool(config.daily).is_true()
	assert_int(config.kit_index).is_equal(content.kit_index(GameLaunch.DAILY_KIT))
	GameRunFlow.set_launch(&"k_gunline", false)
	var normal: SimConfig = SimConfig.create(content, 1)
	GameRunFlow.apply_launch(normal, content, _args([]))
	assert_int(normal.kit_index).is_equal(content.kit_index(&"k_gunline"))
	Save.profile.kit = &"k_ledger"  # the kit selector wrote it
	var from_profile: SimConfig = SimConfig.create(content, 1)
	GameRunFlow.apply_launch(from_profile, content, _args([]))
	assert_int(from_profile.kit_index).is_equal(content.kit_index(&"k_ledger"))
	var by_flag: SimConfig = SimConfig.create(content, 1)
	GameRunFlow.apply_launch(by_flag, content, _args(["--daily", "--kit=k_ledger"]))
	assert_bool(by_flag.daily).is_true()
	assert_int(by_flag.kit_index).is_equal(0)


# --- the relay and the API ---


func test_the_two_new_sim_events_reach_the_event_bus() -> void:
	var relay: GameEventRelay = GameEventRelay.new(TestContent.variety())
	var charge: SimEvent = SimEvent.new()
	charge.kind = SimEventKind.Id.WEAPON_CHARGING
	charge.a = 1
	charge.b = 60
	assert_bool(relay.relay(charge)).is_true()
	assert_array(_log.first_args(&"weapon_charging")).is_equal([1])
	var removed: SimEvent = SimEvent.new()
	removed.kind = SimEventKind.Id.TURRET_REMOVED
	removed.a = 1
	assert_bool(relay.relay(removed)).is_true()
	assert_array(_log.first_args(&"turret_removed")).is_equal([1])


func test_the_cooldown_total_is_the_one_a_cooldown_starts_with() -> void:
	var rc: RunController = GameRunKit.controller(self, SimConfig.create(TestContent.variety(), 1), null, "v5a-cd")
	var base: int = rc.sim.content.abilities[Ids.AB_EMP].cooldown_ticks
	assert_int(rc.api.ability_cooldown_total(&"emp")).is_equal(base)
	rc.sim.mods.emp_cd_mul = 0.8  # the SIGNAL kit, emp_capacitor
	assert_int(rc.api.ability_cooldown_total(&"emp")).is_equal(AbilitySystem.cooldown_ticks_of(rc.sim, Ids.AB_EMP))
	assert_int(rc.api.ability_cooldown_total(&"emp")).is_equal(roundi(float(base) * 0.8))
	assert_int(rc.api.ability_cooldown_total(&"shield")).is_equal(rc.sim.content.abilities[Ids.AB_SHIELD].cooldown_ticks)
	assert_int(rc.api.ability_cooldown_total(&"nope")).is_equal(0)
