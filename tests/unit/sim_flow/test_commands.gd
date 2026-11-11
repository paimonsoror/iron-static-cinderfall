extends GdUnitTestSuite
## CommandSystem: submission order, logging, idempotency, the one-purchase-per-upgrade-per-tick guard (A10).


func _rich_world(phase_id: int = GameState.Id.SPAWNING, wave_number: int = 1) -> SimWorld:
	var w: SimWorld = FlowKit.in_phase(phase_id, wave_number)
	w.add_scrap(5000)
	return w


func test_submitted_commands_wait_for_the_next_tick() -> void:
	var w: SimWorld = _rich_world()
	w.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	assert_int(w.command_queue.size()).is_equal(1)
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)
	assert_int(w.command_log.entries.size()).is_equal(0)
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	assert_int(w.command_queue.size()).is_equal(0)


func test_commands_apply_in_submission_order_and_are_logged_with_their_tick() -> void:
	var w: SimWorld = _rich_world()
	var first: SimCommand = SimCommand.purchase(1, Ids.UP_FIRE_RATE)
	var second: SimCommand = SimCommand.ability(2, Ids.AB_SHIELD)
	var third: SimCommand = SimCommand.purchase(3, Ids.UP_DAMAGE)
	w.submit(first)
	w.submit(second)
	w.submit(third)
	w.step()
	var entries: Array[SimCommand] = w.command_log.entries
	assert_int(entries.size()).is_equal(3)
	assert_int(entries[0].command_id).is_equal(1)
	assert_int(entries[1].command_id).is_equal(2)
	assert_int(entries[2].command_id).is_equal(3)
	for cmd: SimCommand in entries:
		assert_int(cmd.tick).is_equal(1)
	assert_int(first.tick).is_equal(1)
	var order: PackedInt32Array = PackedInt32Array()
	for e: SimEvent in w.events.peek():
		if e.kind == SimEventKind.Id.PURCHASE_RESOLVED or e.kind == SimEventKind.Id.ABILITY_ACTIVATED:
			order.append(e.a if e.kind == SimEventKind.Id.PURCHASE_RESOLVED else e.b)
	assert_array(order).is_equal(PackedInt32Array([1, 2, 3]))
	w.submit(SimCommand.purchase(4, Ids.UP_ARMOR_PIERCING))
	w.step()
	assert_int(w.command_log.entries[3].tick).is_equal(2)


func test_same_command_id_twice_buys_once_and_answers_duplicate_once() -> void:
	var w: SimWorld = _rich_world()
	w.submit(SimCommand.purchase(5, Ids.UP_DAMAGE))
	w.submit(SimCommand.purchase(5, Ids.UP_DAMAGE))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	assert_int(w.scrap).is_equal(5000 - 175)
	var resolved: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PURCHASE_RESOLVED)
	assert_int(resolved.size()).is_equal(2)
	assert_int(resolved[0].b).is_equal(Reason.Id.OK)
	assert_int(resolved[1].b).is_equal(Reason.Id.DUPLICATE_COMMAND)
	assert_int(resolved[1].a).is_equal(5)


func test_a_repeated_id_on_a_later_tick_is_still_a_duplicate() -> void:
	var w: SimWorld = _rich_world()
	w.submit(SimCommand.purchase(5, Ids.UP_DAMAGE))
	w.step()
	w.submit(SimCommand.purchase(5, Ids.UP_DAMAGE))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	var resolved: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PURCHASE_RESOLVED)
	assert_int(resolved[resolved.size() - 1].b).is_equal(Reason.Id.DUPLICATE_COMMAND)


func test_two_ids_for_the_same_upgrade_in_one_tick_buy_once() -> void:
	var w: SimWorld = _rich_world()
	w.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	w.submit(SimCommand.purchase(2, Ids.UP_DAMAGE))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	assert_int(w.scrap).is_equal(5000 - 175)
	var resolved: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PURCHASE_RESOLVED)
	assert_int(resolved.size()).is_equal(2)
	assert_int(resolved[1].a).is_equal(2)
	assert_int(resolved[1].b).is_equal(Reason.Id.DUPLICATE_COMMAND)


func test_the_same_upgrade_can_be_bought_again_on_the_next_tick() -> void:
	var w: SimWorld = _rich_world()
	w.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	w.step()
	w.submit(SimCommand.purchase(2, Ids.UP_DAMAGE))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(2)
	assert_int(w.scrap).is_equal(5000 - 175 - 298)


func test_different_upgrades_in_one_tick_both_buy() -> void:
	var w: SimWorld = _rich_world()
	w.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	w.submit(SimCommand.purchase(2, Ids.UP_FIRE_RATE))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	assert_int(w.upgrade_levels[Ids.UP_FIRE_RATE]).is_equal(1)
	assert_int(w.scrap).is_equal(5000 - 175 - 150)


func test_rejected_commands_are_logged_and_answered() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	w.submit(SimCommand.purchase(2, 99))
	w.step()
	assert_int(w.command_log.entries.size()).is_equal(2)
	var resolved: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PURCHASE_RESOLVED)
	assert_int(resolved[0].b).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_int(resolved[1].b).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(w.scrap).is_equal(0)


func test_a_repeated_ability_command_activates_once() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.submit(SimCommand.ability(7, Ids.AB_SHIELD))
	w.submit(SimCommand.ability(7, Ids.AB_SHIELD))
	w.step()
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ACTIVATED)).is_equal(1)
	var rejected: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.ABILITY_REJECTED)
	assert_int(rejected.size()).is_equal(1)
	assert_int(rejected[0].a).is_equal(Ids.AB_SHIELD)
	assert_int(rejected[0].b).is_equal(Reason.Id.DUPLICATE_COMMAND)
	assert_float(rejected[0].f).is_equal(7.0)
	assert_float(w.shield_hp).is_equal(100.0)


func test_skip_command_ends_the_intermission_at_the_next_tick() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	w.submit(SimCommand.skip(9))
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.wave).is_equal(2)
	assert_int(w.command_log.entries[0].kind).is_equal(SimCommand.Kind.SKIP_INTERMISSION)
	assert_int(w.command_log.entries[0].tick).is_equal(1)


func test_skip_command_outside_the_intermission_changes_nothing() -> void:
	var w: SimWorld = FlowKit.world()
	w.submit(SimCommand.skip(9))
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	assert_int(w.wave).is_equal(0)
	assert_int(w.phase_ticks_left).is_equal(179)
	assert_int(w.command_log.entries.size()).is_equal(1)


func test_ids_that_are_not_positive_are_not_deduplicated() -> void:
	var w: SimWorld = _rich_world()
	w.submit(SimCommand.purchase(0, Ids.UP_DAMAGE))
	w.step()
	w.submit(SimCommand.purchase(0, Ids.UP_DAMAGE))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(2)
	assert_bool(w.phase_state.has_seen(0)).is_false()


func test_unknown_command_kind_is_logged_and_does_nothing() -> void:
	var w: SimWorld = _rich_world()
	var odd: SimCommand = SimCommand.new()
	odd.command_id = 3
	odd.kind = 99
	w.submit(odd)
	var before_scrap: int = w.scrap
	w.step()
	assert_int(w.scrap).is_equal(before_scrap)
	assert_int(w.command_log.entries.size()).is_equal(1)
	assert_int(FlowKit.count(w, SimEventKind.Id.PURCHASE_RESOLVED)).is_equal(0)


func test_log_dicts_replay_to_the_same_state_and_events() -> void:
	var a: SimWorld = _rich_world(GameState.Id.SPAWNING, 2)
	a.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	a.submit(SimCommand.purchase(2, Ids.UP_DAMAGE))
	a.submit(SimCommand.purchase(1, Ids.UP_FIRE_RATE))
	a.step()
	a.submit(SimCommand.ability(3, Ids.AB_EMP))
	a.submit(SimCommand.purchase(4, Ids.UP_SMG))
	a.step()
	FlowKit.step_n(a, 2)
	a.submit(SimCommand.ability(5, Ids.AB_EMP))
	a.submit(SimCommand.purchase(6, Ids.UP_AUTO_TURRET))
	a.step()
	var rows: Array[Dictionary] = a.command_log.to_dicts()
	assert_int(rows.size()).is_equal(7)
	var replayed: CommandLog = CommandLog.from_dicts(rows)
	var b: SimWorld = _rich_world(GameState.Id.SPAWNING, 2)
	for t: int in range(1, a.tick + 1):
		for cmd: SimCommand in replayed.entries:
			if cmd.tick == t:
				b.submit(cmd)
		b.step()
	assert_str(b.state_hash()).is_equal(a.state_hash())
	assert_int(b.events.event_hash).is_equal(a.events.event_hash)
