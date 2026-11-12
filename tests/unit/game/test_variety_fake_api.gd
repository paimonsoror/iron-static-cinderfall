extends GdUnitTestSuite
## V1-S: FakeRunApi mirrors every RunApi addition of the variety milestone (VARIETY_SPEC 13.4): commands are recorded
## with their argument and emit the signal a successful command causes; FakeRunPresets fills the sandbox states.

var api: FakeRunApi
var _log: GameSignalLog
var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()
	api = FakeRunApi.new()
	_log = GameSignalLog.new()
	_log.attach()


func after_test() -> void:
	_log.detach()


func _last_call() -> Dictionary:
	return api.calls[api.calls.size() - 1]


func test_draft_commands_are_recorded_and_emit() -> void:
	FakeRunPresets.draft(api, c)
	api.clear_calls()
	_log.clear()
	api.pick_directive(11, 2)
	assert_str(str(_last_call()["cmd"])).is_equal("pick_directive")
	assert_int(_last_call()["command_id"]).is_equal(11)
	assert_int(_last_call()["arg"]).is_equal(2)
	assert_str(str(_last_call()["id"])).is_equal("glass_cannon")
	assert_array(_log.first_args(&"directive_picked")).is_equal([&"glass_cannon", 1])
	api.buy_out(12, 1)
	assert_array(_log.last_args(&"directive_picked")).is_equal([&"hot_loads", 3])  # 2 held in the preset
	api.reroll_draft(13)
	assert_int(_log.count(&"draft_offered")).is_equal(1)
	api.skip_draft(14)
	api.patch_core(15)
	var names: Array[String] = []
	for row: Dictionary in api.calls:
		names.append(str(row["cmd"]))
	assert_array(names).is_equal(["pick_directive", "buy_out", "reroll_draft", "skip_draft", "patch_core"])


func test_route_salvage_swap_and_call_commands() -> void:
	FakeRunPresets.combat2(api)
	api.clear_calls()
	_log.clear()
	api.pick_route(21, 1)
	assert_array(_log.first_args(&"route_picked")).is_equal([1])
	api.resolve_salvage(22, 1, RunApi.SALVAGE_LEVEL_UP)
	assert_int(_last_call()["arg"]).is_equal(24)
	api.swap_weapon(23, 1)
	assert_int(api.active_slot()).is_equal(1)
	assert_array(_log.first_args(&"weapon_swapped")).is_equal([1, &"smg"])
	api.swap_weapon(24, 5)
	assert_array(_log.last_args(&"command_rejected")).is_equal([24, Reason.Id.INVALID_CHOICE])
	api.call_event(25, &"deadfall_strike")
	assert_str(str(_log.last_args(&"event_warned")[0])).is_equal("deadfall_strike")
	api.call_event(26, &"core_vent")
	assert_array(_log.last_args(&"command_rejected")).is_equal([26, Reason.Id.WRONG_STATE])
	api.call_event(27, &"nope")
	assert_array(_log.last_args(&"command_rejected")).is_equal([27, Reason.Id.UNKNOWN_ID])
	api.continue_run()
	assert_str(str(_last_call()["cmd"])).is_equal("continue_run")


func test_a_paused_fake_refuses_the_variety_commands() -> void:
	FakeRunPresets.draft(api, c)
	api.pause()
	_log.clear()
	api.pick_directive(31, 0)
	api.swap_weapon(32, 1)
	api.call_event(33, &"deadfall_strike")
	assert_int(_log.count(&"command_rejected")).is_equal(3)
	assert_array(_log.first_args(&"command_rejected")).is_equal([31, Reason.Id.PAUSED])
	assert_int(_log.count(&"directive_picked") + _log.count(&"weapon_swapped") + _log.count(&"event_warned")).is_equal(0)
	assert_int(api.active_slot()).is_equal(0)
	api.resume()
	api.pick_directive(34, 0)
	assert_int(_log.count(&"directive_picked")).is_equal(1)


func test_the_draft_preset() -> void:
	FakeRunPresets.draft(api, c)
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_DRAFT)
	assert_int(api.phase()).is_equal(GameState.Id.INTERMISSION)
	var offer: PackedInt32Array = api.draft_offer()
	assert_int(offer.size()).is_equal(3)
	assert_str(str(c.directives[offer[0]].id)).is_equal("incendiary_tips")
	assert_int(c.directives[offer[2]].rarity).is_equal(DirectiveDef.Rarity.CORRUPTED)
	assert_int(api.draft_reroll_cost()).is_equal(60)
	api.fake_free_rerolls = 1
	assert_int(api.draft_reroll_cost()).is_equal(0)
	assert_int(api.directive_stacks(&"hot_loads")).is_equal(2)
	var tags: Dictionary = api.build_tags()
	assert_int(tags[&"bullet"]).is_equal(2)
	assert_array(_log.last_args(&"await_changed")).is_equal([RunApi.AWAIT_DRAFT])
	assert_int(_log.count(&"draft_offered")).is_equal(1)


func test_the_route_boss_and_salvage_presets() -> void:
	FakeRunPresets.route(api)
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_ROUTE)
	assert_int(api.route_option_count()).is_equal(2)
	var hot: Dictionary = api.route_option(1)
	assert_bool(hot["hot"]).is_true()
	assert_str(str(hot["modifier"])).is_equal("mod_volatile")
	assert_bool(c.strings.has(str(hot["name_key"]))).is_true()
	assert_bool(c.strings.has(str(hot["reward_key"]))).is_true()
	assert_bool(api.route_option(0)["hot"]).is_false()
	assert_bool(api.route_option(2).is_empty()).is_true()
	FakeRunPresets.boss_brief(api)
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_BOSS_BRIEF)
	assert_bool(c.strings.has(str(api.boss_brief()["name_key"]))).is_true()
	FakeRunPresets.salvage(api)
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_SALVAGE)
	var crate: Dictionary = api.salvage_offer()
	var crate_weapons: Array = crate["weapons"]
	assert_array(crate_weapons).is_equal([&"arc_projector"])
	assert_int(api.weapon_slot_count()).is_equal(2)
	assert_int(_log.count(&"salvage_offered")).is_equal(1)


func test_the_combat2_preset_and_unknown_states() -> void:
	assert_bool(FakeRunPresets.apply(api, c, "combat2")).is_true()
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_NONE)
	assert_int(api.weapon_slot_count()).is_equal(2)
	var active: Dictionary = api.weapon_slot(api.active_slot())
	assert_str(str(active["id"])).is_equal("arc_projector")
	assert_int(active["heat_cap"]).is_equal(100)
	assert_int(api.event_charges(&"deadfall_strike")).is_equal(2)
	assert_int(api.call_block_reason(&"deadfall_strike")).is_equal(Reason.Id.OK)
	assert_int(api.active_events().size()).is_equal(1)
	assert_array(_log.last_args(&"charges_changed")).is_equal([&"deadfall_strike", 2])
	assert_bool(FakeRunPresets.apply(api, c, "nonsense")).is_false()
	var legacy: ContentSet = TestContent.baseline()
	for state: String in FakeRunPresets.STATES:
		assert_bool(FakeRunPresets.apply(FakeRunApi.new(), legacy, state)).is_true()  # legacy content too
