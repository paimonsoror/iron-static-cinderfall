extends GdUnitTestSuite
## V3-I: the intermission of a generated run with every system real (PhaseSystem and PhaseAwaits of V2-A, DraftSystem of
## V2-B, SalvageSystem of V2-C, CommandSystem): the whole chain SALVAGE -> DRAFT -> ROUTE or BOSS_BRIEF -> breather,
## answered only through SimCommands. The chain used to stop after a resolved crate (SimWorld.step returns while an
## await is held, so nothing noticed that the offer was empty); CommandSystem.apply_queued now moves it on.

## What crate 1 holds on a new profile (act I crates hold tier 2 and 3 weapons; seeds 1 to 3 of these tests give the SMG).
const CRATE_ONE: int = Ids.WP_SMG


## The `none` answer to the current await, one command and one step. Returns the await that was answered.
func _answer(w: SimWorld, command_id: int, route: int = 0) -> int:
	var kind: int = w.phase_state.awaiting
	match kind:
		PhaseState.Await.SALVAGE:
			w.submit(SimCommand.salvage(command_id, 0, SalvageSystem.ACTION_SCRAP))
		PhaseState.Await.DRAFT:
			w.submit(SimCommand.skip_draft(command_id))
		PhaseState.Await.ROUTE:
			w.submit(SimCommand.pick_route(command_id, route))
		PhaseState.Await.BOSS_BRIEF:
			w.submit(SimCommand.skip(command_id))
	w.step()
	return kind


## Clears waves (VarietyAKit.run_to_await kills everything) and answers until `waves` waves are cleared and the first
## await after that clear is up.
func _to_clear_of(w: SimWorld, waves: int) -> void:
	var command_id: int = 1000
	for _n: int in 40:
		assert_bool(VarietyAKit.run_to_await(w)).is_true()
		if w.waves_completed >= waves:
			return
		command_id += 1
		_answer(w, command_id)


func test_after_wave_one_the_draft_comes_first_and_its_pick_opens_the_route_in_the_same_step() -> void:
	var w: SimWorld = VarietyAKit.world(1)
	_to_clear_of(w, 1)
	assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	assert_bool(w.draft.open).is_true()
	assert_int(w.draft.offer.size()).is_equal(3)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.DRAFT_OFFERED).size()).is_equal(1)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.ROUTE_OFFERED).size()).is_equal(0)
	var tick: int = w.tick
	w.submit(SimCommand.pick_directive(1, 0))
	w.step()
	assert_int(w.tick).is_equal(tick + 1)
	assert_bool(w.draft.open).is_false()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.ROUTE)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.ROUTE_OFFERED).size()).is_equal(1)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.DIRECTIVE_PICKED).size()).is_equal(1)
	w.submit(SimCommand.pick_route(2, 1))
	w.step()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	assert_bool(w.phase_state.breather).is_true()
	for _n: int in w.content.mission.breather_ticks:
		w.step()
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.wave).is_equal(2)
	assert_int(w.nav.sched_due.size()).is_equal(w.plan.wave(2).options[1].total_count())


func test_resolving_the_guaranteed_crate_moves_on_to_the_draft_in_the_same_step() -> void:
	var w: SimWorld = VarietyAKit.world(1)
	_to_clear_of(w, 2)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.SALVAGE)  # the guaranteed crate after wave 2
	assert_int(w.stats.crates_secured).is_equal(1)
	assert_array(Array(w.salvage.offer)).is_equal([CRATE_ONE])  # act I crates hold tier 2 and 3 weapons
	assert_bool(w.draft.open).is_false()
	var tick: int = w.tick
	w.submit(SimCommand.salvage(1, 0, SalvageSystem.ACTION_SLOT_1))
	w.step()
	assert_int(w.tick).is_equal(tick + 1)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(CRATE_ONE)
	assert_bool(w.salvage.offer.is_empty()).is_true()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)  # not stuck on an empty SALVAGE
	assert_bool(w.draft.open).is_true()
	var changed: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.AWAIT_CHANGED)
	assert_int(changed[changed.size() - 1].a).is_equal(PhaseState.Await.DRAFT)
	assert_int(changed[changed.size() - 1].b).is_equal(PhaseState.Await.SALVAGE)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.COMMAND_REJECTED).size()).is_equal(0)
	for _n: int in 30:
		w.step()
	assert_int(w.tick).is_equal(tick + 1)  # and the draft holds the tick again


func test_a_refused_salvage_command_leaves_the_crate_on_offer() -> void:
	var w: SimWorld = VarietyAKit.world(1)
	_to_clear_of(w, 2)
	w.submit(SimCommand.salvage(1, 3, SalvageSystem.ACTION_SCRAP))  # the crate has one weapon: choice 3 does not exist
	w.step()
	var refused: Array[SimEvent] = VarietyAKit.events_of(w, SimEventKind.Id.COMMAND_REJECTED)
	assert_int(refused[refused.size() - 1].b).is_equal(Reason.Id.INVALID_CHOICE)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.SALVAGE)
	assert_array(Array(w.salvage.offer)).is_equal([CRATE_ONE])


func test_two_banked_crates_are_offered_one_after_the_other_and_then_the_draft() -> void:
	var w: SimWorld = VarietyAKit.world(1)
	_to_clear_of(w, 1)
	_answer(w, 1)  # the draft
	_answer(w, 2)  # the route
	# a crate secured during wave 2 (banked by hand: the field crate needs twelve quiet seconds)
	w.salvage.banked.append(0)
	for k: int in SalvageState.ITEMS_PER_CRATE:
		w.salvage.banked_items.append(Ids.WP_SMG if k == 0 else -1)
	assert_bool(VarietyAKit.run_to_await(w)).is_true()
	assert_int(w.waves_completed).is_equal(2)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.SALVAGE)
	assert_array(Array(w.salvage.offer)).is_equal([Ids.WP_SMG])
	w.submit(SimCommand.salvage(3, 0, SalvageSystem.ACTION_SLOT_1))
	w.step()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.SALVAGE)  # the guaranteed crate is next
	assert_int(w.salvage.offer.size()).is_equal(1)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(Ids.WP_SMG)
	w.submit(SimCommand.salvage(4, 0, SalvageSystem.ACTION_SCRAP))
	w.step()
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	assert_bool(w.salvage.banked.is_empty()).is_true()


func test_the_awaits_of_a_whole_slice_run_come_in_the_order_of_the_spec() -> void:
	var w: SimWorld = VarietyAKit.world(2, VarietyAKit.act_one_content())
	var order: Array[int] = []
	var at_wave: Array[int] = []
	var command_id: int = 0
	for _n: int in 40:
		if not VarietyAKit.run_to_await(w):
			break
		command_id += 1
		at_wave.append(w.waves_completed)
		order.append(_answer(w, command_id))
	var a: Dictionary = {"s": PhaseState.Await.SALVAGE, "d": PhaseState.Await.DRAFT, "r": PhaseState.Await.ROUTE, "b": PhaseState.Await.BOSS_BRIEF}
	assert_array(order).is_equal([a["d"], a["r"], a["s"], a["d"], a["r"], a["d"], a["r"], a["d"], a["b"]])
	assert_array(at_wave).is_equal([1, 1, 2, 2, 2, 3, 3, 4, 4])
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)  # no await after the boss wave
	assert_int(w.waves_completed).is_equal(5)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.RUN_FINISHED).size()).is_equal(1)


func test_the_awaits_of_the_fifteen_wave_run_cross_two_act_boundaries() -> void:
	# The whole game (V5-A): act I as above; a boss kill of act I and II banks a boss crate, so the intermission after
	# waves 5 and 10 starts with a SALVAGE; then draft and route up to the briefing of the next boss; wave 15 ends the run.
	var w: SimWorld = VarietyAKit.world(2)
	var order: Array[int] = []
	var at_wave: Array[int] = []
	var acts: Array[int] = []
	var command_id: int = 0
	for _n: int in 80:
		if not VarietyAKit.run_to_await(w):
			break
		command_id += 1
		at_wave.append(w.waves_completed)
		acts.append(w.phase_state.act)
		order.append(_answer(w, command_id))
	var s: int = PhaseState.Await.SALVAGE
	var d: int = PhaseState.Await.DRAFT
	var r: int = PhaseState.Await.ROUTE
	var b: int = PhaseState.Await.BOSS_BRIEF
	var later_act: Array[int] = [s, d, r, d, r, d, r, d, r, d, b]
	assert_array(order).is_equal([d, r, s, d, r, d, r, d, b] + later_act + later_act)
	assert_array(at_wave).is_equal([1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14])
	assert_array(acts.slice(0, 12)).is_equal([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])  # the act changes when wave 6 starts
	assert_int(acts[acts.size() - 1]).is_equal(3)
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(w.waves_completed).is_equal(15)
	assert_int(w.stats.act_reached).is_equal(3)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
	assert_int(VarietyAKit.events_of(w, SimEventKind.Id.RUN_FINISHED).size()).is_equal(1)
	assert_array(Array(w.stats.boss_ids)).is_equal(Array(w.plan.boss_ids))  # one boss per act spawned, the plan's


func test_the_route_reward_is_paid_at_the_wave_clear_before_the_first_await() -> void:
	# a wave-2 option that pays Scrap (rw_scrap, 120 in act I) on some seed of the fixture
	var reward_index: int = VarietyAKit.content().run.reward_index(&"rw_scrap")
	for run_seed: int in range(1, 30):
		var w: SimWorld = VarietyAKit.world(run_seed)
		var pick: int = -1
		for k: int in w.plan.wave(2).options.size():
			if w.plan.wave(2).options[k].reward_index == reward_index:
				pick = k
		if pick < 0:
			continue
		_to_clear_of(w, 1)
		_answer(w, 1)
		_answer(w, 2, pick)
		assert_int(w.plan.chosen[1]).is_equal(pick)
		w.events.drain()
		assert_bool(VarietyAKit.run_to_await(w)).is_true()
		var cleared_at: int = -1
		var paid_at: int = -1
		var await_at: int = -1
		var events: Array[SimEvent] = w.events.peek()
		for i: int in events.size():
			var e: SimEvent = events[i]
			if e.kind == SimEventKind.Id.WAVE_CLEARED and e.a == 2:
				cleared_at = i
			elif cleared_at >= 0 and paid_at < 0 and e.kind == SimEventKind.Id.SCRAP_CHANGED and e.b == 120:
				paid_at = i
			elif cleared_at >= 0 and await_at < 0 and e.kind == SimEventKind.Id.AWAIT_CHANGED:
				await_at = i
		assert_int(cleared_at).is_greater_equal(0)
		assert_int(paid_at).is_greater(cleared_at)
		assert_int(await_at).is_greater(paid_at)
		return
	assert_bool(false).override_failure_message("no seed below 30 offers rw_scrap before wave 2").is_true()


func test_the_modifier_of_the_chosen_route_holds_for_its_wave_only() -> void:
	var modifier: int = VarietyAKit.content().run.modifier_index(&"mod_volatile")
	for run_seed: int in range(1, 30):
		var w: SimWorld = VarietyAKit.world(run_seed)
		var hot: int = -1
		for k: int in w.plan.wave(2).options.size():
			if w.plan.wave(2).options[k].modifier_index == modifier:
				hot = k
		var plain: int = -1
		for k: int in w.plan.wave(3).options.size():
			if w.plan.wave(3).options[k].modifier_index < 0:
				plain = k
		if hot < 0 or plain < 0:
			continue
		_to_clear_of(w, 1)
		assert_bool(w.mods.has_flag(&"volatile_skitters")).is_false()
		_answer(w, 1)
		_answer(w, 2, hot)
		for _n: int in w.content.mission.breather_ticks:
			w.step()
		assert_int(w.wave).is_equal(2)
		assert_bool(w.mods.has_flag(&"volatile_skitters")).is_true()  # set at the wave start
		_to_clear_of(w, 2)
		for _k: int in 3:  # the crate, the draft, the route of wave 3
			_answer(w, 10 + w.tick, plain)
		for _n: int in w.content.mission.breather_ticks:
			w.step()
		assert_int(w.wave).is_equal(3)
		assert_bool(w.mods.has_flag(&"volatile_skitters")).is_false()  # gone with the next wave
		return
	assert_bool(false).override_failure_message("no seed below 30 has a volatile wave 2 and a plain wave 3").is_true()
