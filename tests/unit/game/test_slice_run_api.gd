extends GdUnitTestSuite
## V3-I: what the slice integration added to the game layer. The RunApi queries the overlays and the ticker were missing
## (the used buy-out, the locked draft, the crate on the field), the wave count of a generated run, the boss briefing in
## the key convention of the overlay, `--autoplay=<any policy>`, and the base-class defaults.

var c: ContentSet


func before_test() -> void:
	GameRunKit.fresh_save()
	c = TestContent.variety()


func after_test() -> void:
	GameRunKit.reset_save()


func _rc(run_seed: int = 1) -> RunController:
	return GameRunKit.controller(self, SimConfig.create(c, run_seed), null, "slice-%d" % run_seed)


## Clears the running wave at once (every enemy dies, the schedule counts as spawned) until the run waits for a choice.
func _to_await(rc: RunController) -> void:
	assert_bool(VarietyAKit.run_to_await(rc.sim)).is_true()


func test_the_base_class_answers_nothing_is_used_locked_or_dropped() -> void:
	var api: RunApi = RunApi.new()
	assert_bool(api.draft_buyout_used()).is_false()
	assert_bool(api.draft_actions_locked()).is_false()
	assert_bool(api.crate_status().is_empty()).is_true()
	var fake: FakeRunApi = FakeRunApi.new()
	assert_bool(fake.draft_buyout_used()).is_false()
	fake.fake_buyout_used = true
	fake.fake_draft_locked = true
	fake.fake_crate_status = {"contested": true, "ticks_left": 60, "ticks_total": 720, "life_left": 900, "x": 1.0, "z": 2.0}
	assert_bool(fake.draft_buyout_used()).is_true()
	assert_bool(fake.draft_actions_locked()).is_true()
	assert_int(fake.crate_status()["ticks_left"]).is_equal(60)


func test_the_legacy_content_gets_the_defaults() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config(1), null, "legacy")
	assert_bool(rc.api.draft_buyout_used()).is_false()
	assert_bool(rc.api.draft_actions_locked()).is_false()
	assert_bool(rc.api.crate_status().is_empty()).is_true()
	assert_int(rc.api.wave_count()).is_equal(5)  # the five scripted waves


func test_the_wave_count_is_the_plan_s() -> void:
	var rc: RunController = _rc()
	assert_int(rc.api.wave_count()).is_equal(rc.sim.plan.wave_count())
	assert_int(rc.api.wave_count()).is_equal(5)
	rc.sim.plan.waves.resize(3)  # a debug write: the HUD shows what the plan holds, not the scripted wave list
	assert_int(rc.api.wave_count()).is_equal(3)
	assert_int(rc.sim.content.waves.size()).is_equal(5)


func test_the_wave_route_is_the_option_the_current_wave_spawns() -> void:
	var rc: RunController = _rc(1)
	var w: SimWorld = rc.sim
	assert_bool(rc.api.wave_route().is_empty()).is_true()  # PREPARING: no wave yet
	GameRunKit.frames(rc, c.mission.prepare_ticks + 1)
	assert_int(w.wave).is_equal(1)
	var opener: Dictionary = rc.api.wave_route()
	assert_str(str(opener["pack"])).is_equal("pack_tide")  # the opener's fixed pack
	assert_str(str(opener["name_key"])).is_equal("pack.tide.name")
	assert_int(opener["total"]).is_equal(w.plan.option(1).total_count())
	assert_str(str(opener["modifier"])).is_equal("")
	w.plan.chosen[1] = 1  # a debug write: the route picked for wave 2
	w.wave = 2
	assert_dict(rc.api.wave_route()).is_equal(SimRunQueries.describe_option(w, w.plan.wave(2).options[1], 1))
	assert_bool(rc.api.wave_route()["hot"]).is_true()
	w.wave = 5
	var boss_wave: Dictionary = rc.api.wave_route()
	assert_str(str(boss_wave["name_key"])).is_equal("")  # a boss wave has no pack
	assert_int(boss_wave["total"]).is_greater(1)
	assert_bool(RunApi.new().wave_route().is_empty()).is_true()
	assert_bool(GameRunKit.controller(self, GameRunKit.config(1), null, "legacy-route").api.wave_route().is_empty()).is_true()


func test_the_buy_out_is_reported_used_after_it_was_used() -> void:
	var rc: RunController = _rc()
	assert_bool(rc.api.draft_buyout_used()).is_false()  # no draft is open
	_to_await(rc)
	assert_int(rc.api.awaiting()).is_equal(RunApi.AWAIT_DRAFT)
	assert_bool(rc.api.draft_buyout_used()).is_false()
	rc.sim.add_scrap(1000)
	rc.api.buy_out(rc.api.next_command_id(), 1)
	rc.step_frame(GameRunKit.DT)
	assert_int(rc.api.draft_offer()[1]).is_equal(-1)  # the bought slot is taken, the draft stays open for the pick
	assert_bool(rc.api.draft_buyout_used()).is_true()
	assert_int(rc.api.draft_buyout_cost()).is_greater(0)  # the price alone never said so
	rc.api.pick_directive(rc.api.next_command_id(), 0)
	rc.step_frame(GameRunKit.DT)
	assert_bool(rc.api.draft_buyout_used()).is_false()  # the draft is closed


func test_a_draft_after_a_no_breather_wave_is_reported_locked() -> void:
	var rc: RunController = _rc()
	_to_await(rc)
	assert_bool(rc.api.draft_actions_locked()).is_false()
	rc.sim.draft.reroll_locked = true  # what DraftSystem.open sets after a NO BREATHER wave (no such modifier in the slice)
	assert_bool(rc.api.draft_actions_locked()).is_true()
	rc.sim.add_scrap(1000)
	var log: GameSignalLog = GameSignalLog.new()
	log.attach()
	rc.api.reroll_draft(77)
	rc.step_frame(GameRunKit.DT)
	assert_array(log.first_args(&"command_rejected")).is_equal([77, Reason.Id.LOCKED_BY_EVENT])
	log.detach()


func test_a_crate_on_the_field_reports_its_progress_and_whether_it_is_contested() -> void:
	var rc: RunController = _rc()
	var w: SimWorld = rc.sim
	assert_bool(rc.api.crate_status().is_empty()).is_true()
	w.phase = GameState.Id.SPAWNING
	assert_bool(SalvageSystem.drop_crate(w, 0, false)).is_true()
	var status: Dictionary = rc.api.crate_status()
	var total: int = SalvageSystem.secure_ticks(w)
	assert_bool(status["contested"]).is_false()
	assert_int(status["ticks_total"]).is_equal(total)
	assert_int(status["ticks_left"]).is_equal(total)
	assert_int(status["life_left"]).is_equal(c.run.salvage_lifetime_ticks)
	assert_float(status["x"]).is_equal(w.salvage.crate_x)
	w.salvage.crate_progress = 300
	assert_int(rc.api.crate_status()["ticks_left"]).is_equal(total - 300)
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, w.salvage.crate_x + 0.5, w.salvage.crate_z)
	assert_bool(rc.api.crate_status()["contested"]).is_true()
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	assert_bool(rc.api.crate_status()["contested"]).is_false()
	w.salvage.crate_active = false
	assert_bool(rc.api.crate_status().is_empty()).is_true()


func test_the_boss_briefing_uses_the_key_convention_of_the_overlay_and_the_presets() -> void:
	var rc: RunController = _rc(2)
	var w: SimWorld = rc.sim
	assert_bool(rc.api.boss_brief().is_empty()).is_true()  # the next wave is not a boss wave
	w.wave = 4  # a debug write: the briefing describes the wave after the current one
	var brief: Dictionary = rc.api.boss_brief()
	var preset: FakeRunApi = FakeRunApi.new()
	FakeRunPresets.boss_brief(preset)
	assert_dict(brief).is_equal(preset.fake_boss_brief)
	assert_str(str(brief["id"])).is_equal("siege_hulk")
	assert_bool(c.strings.has(brief["name_key"])).is_true()
	assert_bool(c.strings.has(brief["banner_key"])).is_true()
	assert_bool(c.strings.has(brief["attack_key"])).is_true()  # approved lore: lore.threat.siege_hulk
	assert_bool(c.strings.has("boss.%s.answer" % brief["id"])).is_true()  # the overlay's fallback for the ANSWER line


func test_autoplay_takes_every_policy_name_and_an_unknown_name_does_nothing() -> void:
	for policy: int in PolicyBot.NAMES.size():
		assert_int(GameLaunch.autoplay_policy(PolicyBot.NAMES[policy])).is_equal(policy)
	assert_int(GameLaunch.autoplay_policy("balanced")).is_equal(PolicyBot.Policy.BALANCED)
	assert_int(GameLaunch.autoplay_policy("no_such_policy")).is_equal(PolicyBot.Policy.NONE)
	assert_int(GameLaunch.autoplay_policy("")).is_equal(PolicyBot.Policy.NONE)
	var rc: RunController = RunController.new()
	auto_free(rc)
	add_child(rc)
	var cfg: SimConfig = SimConfig.create(c, 1)
	GameLaunch.configure(cfg, rc, DebugArgs.parse(PackedStringArray(["--autoplay=balanced"])), 1)
	assert_int(rc.bot.policy).is_equal(PolicyBot.Policy.BALANCED)
	assert_bool(rc.bot.id_source.is_valid()).is_true()  # one id counter for the bot and the HUD
