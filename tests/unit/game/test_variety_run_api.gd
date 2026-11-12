extends GdUnitTestSuite
## V2-D: the variety members of SimRunApi (VARIETY_SPEC 13.4) read the live sim, the new commands reach it as
## SimCommands, the launch fields come from the profile and the debug arguments, and the back gesture pauses on a
## choice. The sim systems behind the queries are stubs in this wave: the tests put the state in place by hand.

var c: ContentSet
var _log: GameSignalLog


func before_test() -> void:
	GameRunKit.fresh_save()
	c = TestContent.variety()
	_log = GameSignalLog.new()
	_log.attach()


func after_test() -> void:
	_log.detach()
	GameRunKit.reset_save()


func _rc(run_seed: int = 1) -> RunController:
	return GameRunKit.controller(self, SimConfig.create(c, run_seed), null, "v-%d" % run_seed)


func _last_command(rc: RunController) -> SimCommand:
	return rc.sim.command_log.entries[rc.sim.command_log.entries.size() - 1]


func test_every_variety_command_reaches_the_sim_with_its_kind_and_argument() -> void:
	var rc: RunController = _rc()
	var api: SimRunApi = rc.api
	var event_index: int = c.event_index(&"deadfall_strike")
	assert_int(event_index).is_greater_equal(0)
	var sends: Array[Callable] = [
		func() -> void: api.pick_directive(101, 2),
		func() -> void: api.skip_draft(102),
		func() -> void: api.reroll_draft(103),
		func() -> void: api.buy_out(104, 1),
		func() -> void: api.patch_core(105),
		func() -> void: api.pick_route(106, 1),
		func() -> void: api.resolve_salvage(107, 1, RunApi.SALVAGE_SCRAP),
		func() -> void: api.swap_weapon(108, 1),
		func() -> void: api.call_event(109, &"deadfall_strike"),
	]
	var expected: Array[Vector2i] = [
		Vector2i(SimCommand.Kind.PICK_DIRECTIVE, 2), Vector2i(SimCommand.Kind.SKIP_DRAFT, 0),
		Vector2i(SimCommand.Kind.REROLL, 0), Vector2i(SimCommand.Kind.BUY_OUT, 1), Vector2i(SimCommand.Kind.PATCH_CORE, 0),
		Vector2i(SimCommand.Kind.PICK_ROUTE, 1), Vector2i(SimCommand.Kind.SALVAGE, 16 + 9),
		Vector2i(SimCommand.Kind.SWAP_WEAPON, 1), Vector2i(SimCommand.Kind.CALL_EVENT, event_index),
	]
	for i: int in sends.size():
		sends[i].call()
		rc.step_frame(GameRunKit.DT)
		var cmd: SimCommand = _last_command(rc)
		assert_int(cmd.command_id).is_equal(101 + i)
		assert_int(cmd.kind).is_equal(expected[i].x)
		assert_int(cmd.arg).is_equal(expected[i].y)
	assert_int(rc.sim.command_log.entries.size()).is_equal(sends.size())


func test_a_variety_command_is_refused_while_paused_after_the_end_and_for_an_unknown_id() -> void:
	var rc: RunController = _rc()
	rc.set_paused(true)
	rc.api.pick_directive(7, 0)
	assert_array(_log.first_args(&"command_rejected")).is_equal([7, Reason.Id.PAUSED])
	rc.set_paused(false)
	_log.clear()
	rc.api.call_event(8, &"no_such_event")
	assert_array(_log.first_args(&"command_rejected")).is_equal([8, Reason.Id.UNKNOWN_ID])
	rc.step_frame(GameRunKit.DT)
	assert_int(rc.sim.command_log.entries.size()).is_equal(0)  # neither reached the sim
	var unbound: SimRunApi = SimRunApi.new()
	unbound.pick_route(1, 0)  # no controller: no crash
	unbound.call_event(2, &"deadfall_strike")
	unbound.continue_run()


func test_continue_run_is_the_intermission_skip() -> void:
	var rc: RunController = GameRunKit.controller(self, VarietyDKit.config(c, 2, 2), null, "v-2")
	assert_int(VarietyDKit.play_until_cleared(rc, 1, 20000)).is_greater(0)
	assert_int(rc.sim.phase).is_equal(GameState.Id.INTERMISSION)
	for _n: int in 6:  # the draft and the route are answered first: a pending choice cannot be skipped
		if rc.api.awaiting() == RunApi.AWAIT_NONE:
			break
		VarietyDKit.play_frame(rc)
	assert_int(rc.sim.wave).is_equal(1)  # the breather
	rc.api.continue_run()
	rc.step_frame(GameRunKit.DT)
	assert_int(_last_command(rc).kind).is_equal(SimCommand.Kind.SKIP_INTERMISSION)
	assert_int(rc.sim.wave).is_equal(2)


func test_the_await_the_act_and_the_draft_queries_read_the_sim() -> void:
	var rc: RunController = _rc()
	var api: SimRunApi = rc.api
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_NONE)
	assert_int(api.act()).is_equal(1)
	assert_int(api.act_count()).is_equal(c.run.acts.size())
	assert_int(api.draft_offer().size()).is_equal(0)
	assert_int(api.run_seed()).is_equal(1)
	rc.sim.phase_state.awaiting = PhaseState.Await.DRAFT
	rc.sim.phase_state.act = 2
	rc.sim.draft.open = true
	rc.sim.draft.offer = PackedInt32Array([3, -1, 5])
	rc.sim.draft.free_rerolls = 2
	rc.sim.draft.stacks[c.directive_index(&"hot_loads")] = 2
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_DRAFT)
	assert_int(api.act()).is_equal(2)
	assert_array(Array(api.draft_offer())).is_equal([3, -1, 5])
	assert_int(api.free_rerolls()).is_equal(2)
	assert_int(api.directive_stacks(&"hot_loads")).is_equal(2)
	assert_int(api.directive_stacks(&"no_such_directive")).is_equal(0)
	assert_int(api.draft_reroll_cost()).is_equal(DraftSystem.reroll_cost(rc.sim))
	assert_int(api.draft_buyout_cost()).is_equal(DraftSystem.buyout_cost(rc.sim))
	assert_int(api.patch_cost()).is_equal(DraftSystem.patch_cost(rc.sim))
	assert_int(typeof(api.build_tags())).is_equal(TYPE_DICTIONARY)
	rc.sim.draft.open = false
	assert_int(api.draft_offer().size()).is_equal(0)  # a closed draft offers nothing


func test_the_route_options_describe_the_next_wave_of_the_plan() -> void:
	var rc: RunController = _rc()
	var api: SimRunApi = rc.api
	var plan: RunPlan = rc.sim.plan
	var first: PlannedWave = plan.wave(1)
	assert_int(api.route_option_count()).is_equal(first.options.size())
	var option: Dictionary = api.route_option(0)
	var total: int = 0
	for g: SpawnGroupDef in first.options[0].groups:
		total += g.count
	assert_int(option["total"]).is_equal(total)
	var counts: Dictionary = option["counts"]
	var summed: int = 0
	for enemy_id: StringName in counts:
		assert_object(c.enemy(enemy_id)).is_not_null()
		var n: int = counts[enemy_id]
		summed += n
	assert_int(summed).is_equal(total)
	for key: String in ["pack", "name_key", "modifier", "modifier_key", "elites", "hot", "reward", "reward_key", "reward_amount"]:
		assert_bool(option.has(key)).override_failure_message(key).is_true()
	assert_dict(api.route_option(99)).is_empty()
	# an option that names a pack, a modifier and a reward shows them
	var o: RouteOption = first.options[0]
	o.pack_index = 0
	o.modifier_index = 0
	o.reward_index = c.run.reward_index(&"rw_scrap")
	o.hot = true
	var named: Dictionary = api.route_option(0)
	assert_str(str(named["pack"])).is_equal(String(c.run.packs[0].id))
	assert_str(str(named["name_key"])).is_equal(c.run.packs[0].name_key)
	assert_str(str(named["modifier"])).is_equal(String(c.run.modifiers[0].id))
	assert_str(str(named["reward"])).is_equal("rw_scrap")
	assert_int(named["reward_amount"]).is_equal(roundi(c.run.route_rewards[o.reward_index].ops[0].amount(first.act)))
	assert_bool(named["hot"]).is_true()
	# a boss wave has no route, it has a briefing
	assert_dict(api.boss_brief()).is_empty()
	first.is_boss = true
	plan.boss_ids = PackedInt32Array([c.bosses[0].enemy_index])
	assert_int(api.route_option_count()).is_equal(0)
	var brief: Dictionary = api.boss_brief()
	assert_str(str(brief["id"])).is_equal(String(c.bosses[0].id))
	assert_str(str(brief["name_key"])).is_equal(c.bosses[0].name_key)
	assert_str(str(brief["banner_key"])).is_equal(c.bosses[0].banner_key)
	assert_str(str(brief["variant"])).is_equal("")


func test_the_weapon_slots_and_the_salvage_offer() -> void:
	var rc: RunController = _rc()
	var api: SimRunApi = rc.api
	assert_int(api.weapon_slot_count()).is_equal(rc.sim.arsenal.slot_count)
	assert_int(api.active_slot()).is_equal(0)
	var slot0: Dictionary = api.weapon_slot(0)
	assert_str(str(slot0["id"])).is_equal(String(c.weapons[0].id))
	assert_int(slot0["magazine"]).is_equal(rc.sim.warden.magazine)
	assert_int(slot0["size"]).is_equal(c.weapons[0].magazine)
	assert_int(slot0["state"]).is_equal(RunApi.SLOT_READY)
	var empty: Dictionary = api.weapon_slot(1)
	assert_int(empty["state"]).is_equal(RunApi.SLOT_EMPTY)
	assert_str(str(empty["id"])).is_equal("")
	assert_dict(api.weapon_slot(7)).is_empty()
	rc.sim.warden.reload_ticks_left = 33
	assert_int(api.weapon_slot(0)["state"]).is_equal(RunApi.SLOT_RELOADING)
	assert_int(api.weapon_slot(0)["ticks_left"]).is_equal(33)
	rc.sim.arsenal.slot_weapon[1] = Ids.WP_ARC_PROJECTOR
	rc.sim.arsenal.slot_heat[1] = 40
	var arc: Dictionary = api.weapon_slot(1)
	assert_str(str(arc["id"])).is_equal(String(c.weapons[Ids.WP_ARC_PROJECTOR].id))
	assert_int(arc["heat"]).is_equal(40)
	assert_int(arc["heat_cap"]).is_equal(c.weapons[Ids.WP_ARC_PROJECTOR].heat_cap)
	assert_dict(api.salvage_offer()).is_empty()
	rc.sim.salvage.offer = PackedInt32Array([Ids.WP_ARC_PROJECTOR, 1])
	rc.sim.salvage.offer_boss = true
	var offer: Dictionary = api.salvage_offer()
	assert_array(offer["weapons"]).is_equal([c.weapons[Ids.WP_ARC_PROJECTOR].id, c.weapons[1].id])
	assert_array(offer["level_up_slot"]).is_equal([1, -1])  # the arc projector is carried in slot 1
	assert_array(offer["tiers"]).is_equal([c.weapons[Ids.WP_ARC_PROJECTOR].tier, c.weapons[1].tier])
	assert_bool(offer["boss"]).is_true()
	assert_int(offer["scrap_value"]).is_equal(SalvageSystem.scrap_value(rc.sim))


func test_the_event_and_the_boss_queries() -> void:
	var rc: RunController = _rc()
	var api: SimRunApi = rc.api
	var strike: int = c.event_index(&"deadfall_strike")
	assert_int(api.event_charges(&"deadfall_strike")).is_equal(rc.sim.events_state.charges[strike])
	rc.sim.events_state.charges[strike] = 2
	assert_int(api.event_charges(&"deadfall_strike")).is_equal(2)
	assert_int(api.event_charges(&"no_such_event")).is_equal(0)
	assert_int(api.call_block_reason(&"no_such_event")).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(api.call_block_reason(&"deadfall_strike")).is_equal(EventSystem.block_reason(rc.sim, strike))
	rc.set_paused(true)
	assert_int(api.call_block_reason(&"deadfall_strike")).is_equal(Reason.Id.PAUSED)
	rc.set_paused(false)
	assert_int(api.active_events().size()).is_equal(0)
	var es: EventState = rc.sim.events_state
	es.a_event.append(strike)
	es.a_phase.append(EventState.PH_WARN)
	es.a_ticks_left.append(50)
	es.a_x.append(1.5)
	es.a_z.append(-2.0)
	var rows: Array[Dictionary] = api.active_events()
	assert_int(rows.size()).is_equal(1)
	assert_str(str(rows[0]["id"])).is_equal("deadfall_strike")
	assert_int(rows[0]["phase"]).is_equal(0)
	assert_int(rows[0]["ticks_left"]).is_equal(50)
	assert_int(rows[0]["ticks_total"]).is_equal(c.events[strike].warn_ticks)
	assert_float(rows[0]["x"]).is_equal(1.5)
	assert_int(api.boss_phase()).is_equal(0)
	assert_int(api.boss_phase_count()).is_equal(1)
	rc.sim.boss.boss_id = 12
	rc.sim.boss.phase = 2
	rc.sim.boss.phase_count = 3
	assert_int(api.boss_phase()).is_equal(2)
	assert_int(api.boss_phase_count()).is_equal(3)


func test_the_legacy_content_keeps_the_base_answers() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config(1))
	var api: SimRunApi = rc.api
	assert_int(api.wave_count()).is_equal(rc.sim.content.waves.size())
	assert_int(api.act_count()).is_equal(1)
	assert_int(api.route_option_count()).is_equal(0)
	assert_dict(api.route_option(0)).is_empty()
	assert_dict(api.boss_brief()).is_empty()
	assert_dict(api.salvage_offer()).is_empty()
	assert_int(api.weapon_slot_count()).is_equal(1)
	assert_str(str(api.weapon_slot(0)["id"])).is_equal("pistol")
	assert_int(api.draft_reroll_cost()).is_equal(0)
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_NONE)
	assert_int(api.run_seed()).is_equal(1)


func test_the_launch_takes_the_kit_the_unlocks_and_the_daily_flag_from_the_profile_and_the_arguments() -> void:
	var cfg: SimConfig = SimConfig.create(c, 1)
	GameRunFlow.apply_launch(cfg, c)
	assert_int(cfg.unlocked.size()).is_equal(0)
	assert_bool(cfg.daily).is_false()
	Save.profile.unlocks = PackedStringArray(["u_w_rail", "u_from_a_newer_build", "u_w_lmg"])
	GameRunFlow.apply_launch(cfg, c)
	assert_array(Array(cfg.unlocked)).is_equal(["u_w_lmg", "u_w_rail"])  # sorted; an id this content does not know is ignored
	assert_bool(cfg.has_unlock("u_w_lmg")).is_true()
	var all: DebugArgs = DebugArgs.parse(PackedStringArray(["--unlock=all", "--daily", "--kit=k_standard"]))
	GameRunFlow.apply_launch(cfg, c, all)
	assert_int(cfg.unlocked.size()).is_equal(c.unlocks.size())
	assert_bool(cfg.daily).is_true()
	assert_int(cfg.kit_index).is_equal(0)
	var none: DebugArgs = DebugArgs.parse(PackedStringArray(["--unlock=none"]))
	GameRunFlow.apply_launch(cfg, c, none)
	assert_int(cfg.unlocked.size()).is_equal(0)
	assert_bool(cfg.daily).is_false()
	var some: DebugArgs = DebugArgs.parse(PackedStringArray(["--unlock=u_w_torch,u_bogus"]))
	GameRunFlow.apply_launch(cfg, c, some)
	assert_array(Array(cfg.unlocked)).is_equal(["u_w_torch"])
	# the legacy content has no unlocks and no kits: nothing to take
	var legacy: SimConfig = SimConfig.create(TestContent.baseline(), 1)
	GameRunFlow.apply_launch(legacy, legacy.content, all)
	assert_int(legacy.unlocked.size()).is_equal(0)
	assert_int(legacy.kit_index).is_equal(0)


func test_back_on_a_choice_pauses_and_never_dismisses() -> void:
	for state: int in [GameState.Id.PREPARING, GameState.Id.SPAWNING, GameState.Id.CLEARING, GameState.Id.INTERMISSION]:
		assert_int(BackPolicy.decide(state, false, false, true)).is_equal(BackPolicy.Action.PAUSE)
		assert_int(BackPolicy.decide(state, true, false, true)).is_equal(BackPolicy.Action.PAUSE)  # not CLOSE_DRAWER
		assert_int(BackPolicy.decide(state, true, false, false)).is_equal(BackPolicy.Action.CLOSE_DRAWER)
		assert_int(BackPolicy.decide(state, true, false)).is_equal(BackPolicy.Action.CLOSE_DRAWER)  # the old call
	assert_int(BackPolicy.decide(GameState.Id.PAUSED, false, false, true)).is_equal(BackPolicy.Action.RESUME)
	assert_int(BackPolicy.decide(GameState.Id.INTERMISSION, false, true, true)).is_equal(BackPolicy.Action.CLOSE_OVERLAY)
	var rc: RunController = _rc()
	assert_bool(GameRunFlow.choice_open(rc)).is_false()
	assert_bool(GameRunFlow.choice_open(null)).is_false()
	rc.sim.phase_state.awaiting = PhaseState.Await.ROUTE
	assert_bool(GameRunFlow.choice_open(rc)).is_true()


func test_the_choice_overlays_follow_the_await_and_leave_with_the_run() -> void:
	var rc: RunController = _rc()
	var layer: Control = Control.new()
	auto_free(layer)
	add_child(layer)
	var connections: int = Events.await_changed.get_connections().size()
	var overlays: GameChoiceOverlays = GameChoiceOverlays.new()
	rc.add_child(overlays)
	overlays.setup(rc.api, c, layer)
	assert_object(overlays.overlay).is_null()
	Events.await_changed.emit(RunApi.AWAIT_DRAFT)
	assert_object(overlays.overlay as DraftOverlay).is_not_null()
	assert_int(layer.get_child_count()).is_equal(1)
	Events.await_changed.emit(RunApi.AWAIT_ROUTE)
	assert_object(overlays.overlay as RouteOverlay).is_not_null()
	assert_int(layer.get_child_count()).is_equal(1)  # the draft overlay left the tree at once
	Events.await_changed.emit(RunApi.AWAIT_SALVAGE)
	assert_object(overlays.overlay as SalvageOverlay).is_not_null()
	Events.await_changed.emit(RunApi.AWAIT_BOSS_BRIEF)
	assert_object(overlays.overlay as BossBriefOverlay).is_not_null()
	Events.await_changed.emit(RunApi.AWAIT_NONE)
	assert_object(overlays.overlay).is_null()
	assert_int(layer.get_child_count()).is_equal(0)
	# a resumed run can start inside a choice: `sync` shows it without a signal
	rc.sim.phase_state.awaiting = PhaseState.Await.DRAFT
	overlays.sync()
	assert_object(overlays.overlay as DraftOverlay).is_not_null()
	overlays.sync()
	assert_int(layer.get_child_count()).is_equal(1)
	rc.remove_child(overlays)  # the run goes: the overlay and the connection go with it
	overlays.free()
	assert_int(layer.get_child_count()).is_equal(0)
	assert_int(Events.await_changed.get_connections().size()).is_equal(connections)
	await get_tree().process_frame
