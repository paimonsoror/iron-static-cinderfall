extends GdUnitTestSuite
## V1-S: SimWorld with the variety contracts (VARIETY_SPEC 13.2): the new state fields, the awaiting rule of step(),
## the spawn caps, the new commands and their refusals, and that the stubs change nothing about a run.

var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()


func _world(run_seed: int = 1) -> SimWorld:
	return SimWorld.new(SimConfig.create(c, run_seed))


func _events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


func test_a_variety_world_has_every_state_and_the_larger_store() -> void:
	var w: SimWorld = _world()
	assert_int(w.enemies.capacity).is_equal(50 + 40 + 8)
	assert_int(w.ext.capacity).is_equal(w.enemies.capacity)
	assert_int(w.draft.stacks.size()).is_equal(c.directives.size())
	assert_int(w.events_state.charges.size()).is_equal(c.events.size())
	assert_int(w.stats.kills_by_type.size()).is_equal(Ids.ENEMIES.size())
	assert_int(w.stats.damage_by_source.size()).is_equal(DamageSource.COUNT)
	assert_int(w.combat.damage_by_source.size()).is_equal(DamageSource.COUNT)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(c.weapons[0].magazine)
	assert_object(w.mods).is_not_null()
	assert_object(w.salvage).is_not_null()
	assert_object(w.hazards).is_not_null()
	assert_object(w.boss).is_not_null()


func test_the_plan_is_generated_from_the_run_data() -> void:
	# V2-A replaced the V1-S stub (the legacy waves as a one-option plan): the plan now follows data/run.json.
	var w: SimWorld = _world()
	assert_object(w.plan).is_not_null()
	assert_int(w.plan.wave_count()).is_equal(c.run.waves.size())
	for n: int in range(1, c.run.waves.size() + 1):
		var normal: bool = c.run.wave_slot(n).kind == WaveSlotDef.Kind.NORMAL
		assert_int(w.plan.wave(n).options.size()).is_equal(2 if normal else 1)
		assert_int(w.plan.option(n).total_count()).is_greater(0)


func test_building_a_world_draws_from_no_stream() -> void:
	var w: SimWorld = _world(7)
	var h: StateHasher = StateHasher.new()
	w.rng.hash_into(h)
	var empty: StateHasher = StateHasher.new()
	SimRng.new(7).hash_into(empty)
	assert_str(h.finish()).is_equal(empty.finish())  # no stream was created, so no dice were rolled


func test_step_holds_the_tick_while_awaiting_a_choice() -> void:
	var w: SimWorld = _world()
	for _n: int in 5:
		w.step()
	assert_int(w.tick).is_equal(5)
	w.phase_state.awaiting = PhaseState.Await.DRAFT  # debug write: PhaseSystem sets it once V2-A lands
	var frozen: String = w.state_hash()
	for _n: int in 600:
		w.step()
	assert_int(w.tick).is_equal(5)
	assert_str(w.state_hash()).is_equal(frozen)  # thinking time changes nothing
	w.submit(SimCommand.skip_draft(1))
	w.step()
	assert_int(w.tick).is_equal(6)  # one tick to apply the command
	assert_int(w.command_log.entries.size()).is_equal(1)
	assert_int(w.command_log.entries[0].tick).is_equal(6)
	w.step()
	assert_int(w.tick).is_equal(6)  # still awaiting: stopped again
	w.phase_state.awaiting = PhaseState.Await.NONE
	w.step()
	assert_int(w.tick).is_equal(7)


func test_awaiting_and_act_are_hashed() -> void:
	var w: SimWorld = _world()
	var base: String = w.state_hash()
	w.phase_state.awaiting = PhaseState.Await.ROUTE
	var awaiting: String = w.state_hash()
	assert_str(awaiting).is_not_equal(base)
	w.phase_state.awaiting = PhaseState.Await.NONE
	w.phase_state.act = 2
	assert_str(w.state_hash()).is_not_equal(base)
	w.phase_state.act = 1
	w.phase_state.breather = true
	assert_str(w.state_hash()).is_not_equal(base)


func test_the_state_hash_covers_every_new_state() -> void:
	var seen: Dictionary[String, bool] = {_world().state_hash(): true}
	for variant: int in 9:
		var w: SimWorld = _world()
		match variant:
			0:
				w.mods.w_dmg_mul = 1.8
			1:
				w.arsenal.active = 1
			2:
				w.draft.free_rerolls = 1
			3:
				w.salvage.crates_secured = 1
			4:
				w.ext.burn_ticks[3] = 60
			5:
				w.hazards.next_seq = 9
			6:
				w.events_state.charges[0] = 2
			7:
				w.boss.phase = 1
			8:
				w.plan.chosen[1] = 1
		var digest: String = w.state_hash()
		assert_bool(seen.has(digest)).override_failure_message("state %d is not in the hash" % variant).is_false()
		seen[digest] = true


func test_minis_stop_at_the_swarm_cap_and_do_not_use_bodied_room() -> void:
	var w: SimWorld = _world()
	for n: int in 40:
		assert_int(w.spawn_enemy(Ids.EN_MOTE, 5.0, float(n) * 0.1)).is_greater_equal(0)
	assert_int(w.spawn_enemy(Ids.EN_MOTE, 5.0, 0.0)).is_equal(-1)  # swarm_cap 40
	assert_int(w.spawn_enemy(Ids.EN_SHARD, 5.0, 0.0)).is_equal(-1)  # shards share the mini cap
	assert_bool(w.ext.has_flag(0, EnemyExtState.F_MINI)).is_true()
	for n: int in 50:
		assert_int(w.spawn_enemy(Ids.EN_SKITTER, 6.0, float(n) * 0.1)).is_greater_equal(0)
	assert_int(w.alive_count()).is_equal(90)  # 50 bodied + 40 minis on screen


func test_the_type_cap_and_the_bodied_cap() -> void:
	var w: SimWorld = _world()
	assert_int(w.spawn_enemy(Ids.EN_HULK, 5.0, 0.0)).is_greater_equal(0)
	assert_int(w.spawn_enemy(Ids.EN_HULK, 5.0, 1.0)).is_greater_equal(0)
	assert_int(w.spawn_enemy(Ids.EN_HULK, 5.0, 2.0)).is_equal(-1)  # alive_cap 2
	for n: int in 20:
		assert_int(w.spawn_enemy(Ids.EN_BURSTER, 6.0, float(n) * 0.1)).is_greater_equal(0)
	assert_int(w.spawn_enemy(Ids.EN_BURSTER, 6.0, 0.0)).is_equal(-1)  # alive_cap 20
	for n: int in 24:
		assert_int(w.spawn_enemy(Ids.EN_HOLLOW, 7.0, float(n) * 0.1)).is_greater_equal(0)
	assert_int(w.spawn_enemy(Ids.EN_HOLLOW, 7.0, 0.0)).is_equal(-1)  # alive_cap 24
	var room: int = (c.mission.enemy_cap + 8) - w.alive_count()
	for n: int in room:
		assert_int(w.spawn_enemy(Ids.EN_SKITTER, 8.0, float(n) * 0.1)).is_greater_equal(0)
	assert_int(w.spawn_enemy(Ids.EN_SKITTER, 8.0, 0.0)).is_equal(-1)  # bodied rows: enemy_cap + 8, as before
	assert_int(w.spawn_enemy(Ids.EN_MOTE, 8.0, 0.0)).is_greater_equal(0)  # minis have their own room


func test_elites_stop_at_the_elite_cap() -> void:
	var w: SimWorld = _world()
	for n: int in c.run.max_elites_alive:
		var i: int = w.spawn_enemy(Ids.EN_SKITTER, 5.0, float(n), 1 << n)
		assert_int(i).is_greater_equal(0)
		assert_bool(w.ext.is_elite(i)).is_true()
		assert_int(w.ext.affix_mask[i]).is_equal(1 << n)
	assert_int(EliteSystem.alive_elites(w)).is_equal(4)
	assert_int(w.spawn_enemy(Ids.EN_SKITTER, 5.0, 9.0, 1)).is_equal(-1)
	var plain: int = w.spawn_enemy(Ids.EN_SKITTER, 5.0, 9.0)
	assert_int(plain).is_greater_equal(0)  # a normal body still enters
	assert_bool(w.ext.is_elite(plain)).is_false()
	w.kill_enemy(0, DamageSource.Id.WARDEN)
	var again: int = w.spawn_enemy(Ids.EN_SKITTER, 5.0, 9.5, 2)
	assert_int(again).is_greater_equal(0)  # room again after a kill; the row was reset, then marked
	assert_int(w.ext.affix_mask[again]).is_equal(2)


func test_a_kill_pays_scrap_once_and_counts_by_source() -> void:
	var w: SimWorld = _world()
	var i: int = w.spawn_enemy(Ids.EN_BURSTER, 5.0, 0.0)
	w.kill_enemy(i, DamageSource.Id.HAZARD)
	w.kill_enemy(i, DamageSource.Id.HAZARD)
	assert_int(w.scrap).is_equal(c.enemies[Ids.EN_BURSTER].scrap)
	assert_int(w.stats.kills_by_type[Ids.EN_BURSTER]).is_equal(1)
	assert_int(_events_of(w, SimEventKind.Id.ENEMY_KILLED).size()).is_equal(1)


func test_every_new_command_is_answered_and_logged() -> void:
	var w: SimWorld = _world()
	var cmds: Array[SimCommand] = [
		SimCommand.pick_directive(1, 0), SimCommand.skip_draft(2), SimCommand.reroll(3), SimCommand.buy_out(4, 1),
		SimCommand.patch_core(5), SimCommand.pick_route(6, 1), SimCommand.salvage(7, 0, 9), SimCommand.swap_weapon(8, 1),
		SimCommand.call_event(9, 0), SimCommand.call_event(10, 99),
	]
	var want: Array[int] = [
		Reason.Id.NOT_AWAITING, Reason.Id.NOT_AWAITING, Reason.Id.NOT_AWAITING, Reason.Id.NOT_AWAITING,
		Reason.Id.NOT_AWAITING, Reason.Id.NOT_AWAITING, Reason.Id.NOT_AWAITING, Reason.Id.WRONG_STATE,
		Reason.Id.WRONG_STATE, Reason.Id.UNKNOWN_ID,
	]
	for cmd: SimCommand in cmds:
		w.submit(cmd)
	w.step()
	var rejected: Array[SimEvent] = _events_of(w, SimEventKind.Id.COMMAND_REJECTED)
	assert_int(rejected.size()).is_equal(cmds.size())
	for n: int in cmds.size():
		assert_int(rejected[n].a).is_equal(cmds[n].command_id)
		assert_int(rejected[n].b).is_equal(want[n])
	assert_int(w.command_log.entries.size()).is_equal(cmds.size())
	w.submit(SimCommand.swap_weapon(8, 1))  # the same id again
	w.step()
	var all: Array[SimEvent] = _events_of(w, SimEventKind.Id.COMMAND_REJECTED)
	assert_int(all[all.size() - 1].b).is_equal(Reason.Id.DUPLICATE_COMMAND)


func test_command_constructors() -> void:
	assert_int(SimCommand.pick_directive(1, 2).kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)
	assert_int(SimCommand.pick_directive(1, 2).arg).is_equal(2)
	assert_int(SimCommand.buy_out(1, 1).arg).is_equal(1)
	assert_int(SimCommand.pick_route(1, 1).kind).is_equal(SimCommand.Kind.PICK_ROUTE)
	var s: SimCommand = SimCommand.salvage(4, 1, SalvageSystem.ACTION_LEVEL_UP)
	assert_int(s.kind).is_equal(SimCommand.Kind.SALVAGE)
	assert_int(s.arg).is_equal(1 * 16 + 8)
	assert_int(SimCommand.salvage(4, 0, SalvageSystem.ACTION_SCRAP).arg).is_equal(9)
	assert_int(SimCommand.swap_weapon(5, 1).kind).is_equal(SimCommand.Kind.SWAP_WEAPON)
	assert_int(SimCommand.call_event(6, 3).arg).is_equal(3)
	assert_int(SimCommand.reroll(7).command_id).is_equal(7)
	assert_int(SimCommand.skip_draft(8).tick).is_equal(-1)


func test_the_stubs_leave_a_run_deterministic_and_replayable() -> void:
	var a: SimWorld = _world(11)
	var b: SimWorld = _world(11)
	var bot_a: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	var bot_b: PolicyBot = PolicyBot.new(PolicyBot.Policy.GREEDY)
	for _n: int in 1500:
		bot_a.act(a)
		a.step()
		a.events.drain()
		bot_b.act(b)
		b.step()
		b.events.drain()
	assert_int(a.wave).is_greater_equal(1)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.events.event_hash).is_equal(b.events.event_hash)
	var replayed: SimWorld = Replay.run(SimConfig.create(c, 11), a.command_log, 1500)
	assert_str(replayed.state_hash()).is_equal(a.state_hash())
	var other: SimWorld = _world(12)
	for _n: int in 1500:
		other.step()
		other.events.drain()
	assert_str(other.state_hash()).is_not_equal(a.state_hash())  # another seed, another run


func test_the_new_bot_policies_submit_nothing_yet() -> void:
	var w: SimWorld = _world()
	for policy: int in [PolicyBot.Policy.RANDOM, PolicyBot.Policy.BALANCED, PolicyBot.Policy.RISK]:
		var bot: PolicyBot = PolicyBot.new(policy)
		for _n: int in 30:
			bot.act(w)
			w.step()
		assert_int(bot.commands_submitted).is_equal(0)
	assert_int(w.command_log.entries.size()).is_equal(0)


func test_set_core_max_clamps_and_reports() -> void:
	var w: SimWorld = _world()
	w.set_core_max(700.0)
	assert_float(w.core_max_hp).is_equal(700.0)
	assert_float(w.core_hp).is_equal(700.0)
	var changed: Array[SimEvent] = _events_of(w, SimEventKind.Id.CORE_CHANGED)
	assert_float(changed[changed.size() - 1].g).is_equal(700.0)
	w.set_core_max(1150.0)
	assert_float(w.core_hp).is_equal(700.0)  # raising the maximum does not repair
	w.set_core_max(-5.0)
	assert_float(w.core_max_hp).is_equal(1.0)


func test_summary_and_config_carry_the_variety_fields() -> void:
	var cfg: SimConfig = SimConfig.create(c, 3)
	assert_int(cfg.kit_index).is_equal(0)
	assert_bool(cfg.daily).is_false()
	assert_bool(cfg.has_unlock("u_w_lmg")).is_false()
	cfg.unlocked = PackedStringArray(["u_w_lmg"])
	assert_bool(cfg.has_unlock("u_w_lmg")).is_true()
	cfg.unlocked = PackedStringArray()
	cfg.daily = true
	assert_bool(cfg.has_unlock("u_w_rail")).is_true()
	var w: SimWorld = SimWorld.new(cfg)
	for _n: int in 400:
		w.step()
	var s: RunSummary = w.summary("t-3")
	assert_int(s.act_reached).is_equal(1)
	assert_int(s.combat_ticks).is_equal(400 - c.mission.prepare_ticks + 1)
	assert_int(s.directives.size()).is_equal(c.directives.size())
	assert_array(Array(s.weapons)).is_equal([0, -1, -1])
	assert_int(s.damage_by_source.size()).is_equal(DamageSource.COUNT)
	assert_int(s.core_damage_by_type.size()).is_equal(Ids.ENEMIES.size())
	assert_int(s.kills_by_type.size()).is_equal(Ids.ENEMIES.size())


func test_world_snapshot_captures_and_reapplies_the_variety_states() -> void:
	var w: SimWorld = _world(5)
	w.draft.free_rerolls = 2
	w.mods.w_dmg_mul = 1.8
	w.arsenal.slot_weapon[1] = Ids.WP_ARC_PROJECTOR
	w.events_state.charges[0] = 3
	w.plan.chosen[2] = 0
	var doc: Dictionary = JSON.parse_string(JSON.stringify(WorldSnapshot.capture(w)))
	var fresh: SimWorld = _world(5)
	assert_str(fresh.state_hash()).is_not_equal(w.state_hash())
	assert_bool(WorldSnapshot.restore(fresh, doc)).is_true()  # V2-D: the snapshot is complete (was false for the stub)
	assert_str(fresh.state_hash()).is_equal(w.state_hash())  # at tick 0 the variety states are the whole difference
	assert_bool(WorldSnapshot.restore(fresh, {"version": 99})).is_false()
