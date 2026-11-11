extends GdUnitTestSuite
## RunController: ticks the sim, drains events into Events in order, rejects commands while paused (ARCH 7.3, A13).

const EXPECTED_SIGNALS: Dictionary = {
	SimEventKind.Id.WAVE_STARTED: [&"wave_started"],
	SimEventKind.Id.WAVE_CLEARED: [&"wave_cleared"],
	SimEventKind.Id.INTERMISSION_STARTED: [&"intermission_started"],
	SimEventKind.Id.ENEMY_SPAWNED: [&"enemy_spawned"],
	SimEventKind.Id.BOSS_SPAWNED: [&"boss_spawned"],
	SimEventKind.Id.SHOT_FIRED: [&"shot_fired"],
	SimEventKind.Id.ENEMY_DAMAGED: [&"enemy_damaged"],
	SimEventKind.Id.ENEMY_KILLED: [&"enemy_killed", &"enemy_died_at"],
	SimEventKind.Id.SCRAP_CHANGED: [&"scrap_changed"],
	SimEventKind.Id.CORE_HIT: [&"core_hit"],
	SimEventKind.Id.CORE_CHANGED: [&"core_changed"],
	SimEventKind.Id.SHIELD_CHANGED: [&"shield_changed"],
	SimEventKind.Id.PURCHASE_RESOLVED: [&"purchase_resolved"],
	SimEventKind.Id.UPGRADE_LEVEL_CHANGED: [&"upgrade_level_changed"],
	SimEventKind.Id.WEAPON_CHANGED: [&"weapon_changed"],
	SimEventKind.Id.TURRET_DEPLOYED: [&"turret_deployed"],
	SimEventKind.Id.RELOAD_STARTED: [&"reload_started"],
	SimEventKind.Id.RELOAD_FINISHED: [&"reload_finished"],
	SimEventKind.Id.ABILITY_ACTIVATED: [&"ability_activated"],
	SimEventKind.Id.ABILITY_ENDED: [&"ability_ended"],
	SimEventKind.Id.ABILITY_REJECTED: [&"ability_rejected"],
	SimEventKind.Id.ENEMY_STUNNED: [&"enemy_stunned"],
	SimEventKind.Id.ENEMY_STUCK: [&"enemy_stuck"],
	SimEventKind.Id.RUN_FINISHED: [&"run_finished"],
}

var _log: GameSignalLog
var _phases: Array[Vector2i] = []


func before_test() -> void:
	GameRunKit.fresh_save()
	_log = GameSignalLog.new()
	_log.attach()
	_phases.clear()


func after_test() -> void:
	_log.detach()
	GameRunKit.reset_save()


func _on_phase(previous: int, current: int) -> void:
	_phases.append(Vector2i(previous, current))


func test_start_announces_the_run_and_creates_the_sim() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config(5), null, "run-x")
	assert_object(rc.sim).is_not_null()
	assert_str(rc.run_id).is_equal("run-x")
	assert_array(_log.first_args(&"run_started")).is_equal(["run-x", 5])
	assert_int(rc.sim.tick).is_equal(0)


func test_a_60_fps_frame_runs_one_tick_and_a_30_fps_frame_two() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	assert_int(rc.step_frame(1.0 / 60.0)).is_equal(1)
	assert_int(rc.step_frame(1.0 / 30.0)).is_equal(2)
	assert_int(rc.sim.tick).is_equal(3)
	assert_int(rc.last_frame_ticks).is_equal(2)


func test_events_arrive_on_events_in_the_order_the_sim_pushed_them() -> void:
	var cfg: SimConfig = GameRunKit.config(7, true)
	cfg.debug_start_scrap = 400
	var shadow_cfg: SimConfig = GameRunKit.config(7, true)
	shadow_cfg.debug_start_scrap = 400
	var rc: RunController = GameRunKit.controller(self, cfg)
	var shadow: SimWorld = SimWorld.new(shadow_cfg)
	rc.api.purchase_upgrade(1, &"damage")
	shadow.submit(SimCommand.purchase(1, Ids.UP_DAMAGE))
	var kinds: Array[int] = []
	shadow.events.drain()  # the controller already announced whatever the sim pushed while it was built
	_log.clear()
	for f: int in 4000:
		rc.step_frame(GameRunKit.DT)
		shadow.step()
		for e: SimEvent in shadow.events.drain():
			kinds.append(e.kind)
	var want: Array[StringName] = []
	for kind: int in kinds:
		if EXPECTED_SIGNALS.has(kind):
			var names: Array = EXPECTED_SIGNALS[kind]
			for n: StringName in names:
				want.append(n)
	for needed: int in [SimEventKind.Id.WAVE_STARTED, SimEventKind.Id.ENEMY_SPAWNED, SimEventKind.Id.SHOT_FIRED, SimEventKind.Id.ENEMY_KILLED, SimEventKind.Id.SCRAP_CHANGED, SimEventKind.Id.PURCHASE_RESOLVED, SimEventKind.Id.WAVE_CLEARED]:
		assert_bool(kinds.has(needed)).is_true()  # a real stretch of play, not an empty one
	var got: Array[StringName] = []
	for n: StringName in _log.names():
		if n != &"profile_changed":  # the reward grant is not a sim event
			got.append(n)
	assert_array(got).is_equal(want)
	assert_str(rc.sim.state_hash()).is_equal(shadow.state_hash())


func test_phase_changes_are_reported_in_order_and_not_as_gameplay_signals() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	rc.phase_changed.connect(_on_phase)
	GameRunKit.frames(rc, rc.sim.content.mission.prepare_ticks + 2)
	assert_array(_phases).is_equal([Vector2i(GameState.Id.PREPARING, GameState.Id.SPAWNING)])
	assert_int(_log.count(&"state_changed")).is_equal(0)  # Game owns the application-level signal
	assert_int(_log.count(&"wave_started")).is_equal(1)


func test_paused_runs_zero_ticks() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	GameRunKit.frames(rc, 10)
	rc.api.pause()
	assert_bool(rc.api.is_paused()).is_true()
	assert_int(GameRunKit.frames(rc, 120)).is_equal(0)
	assert_int(rc.sim.tick).is_equal(10)
	rc.api.resume()
	assert_int(GameRunKit.frames(rc, 5)).is_equal(5)
	assert_int(rc.sim.tick).is_equal(15)


func test_pausing_for_600_frames_leaves_the_state_hash_and_every_cooldown_unchanged() -> void:
	var cfg: SimConfig = GameRunKit.config(3)
	var rc: RunController = GameRunKit.controller(self, cfg)
	GameRunKit.frames(rc, rc.sim.content.mission.prepare_ticks + 30)  # now in combat
	assert_int(rc.sim.phase).is_equal(GameState.Id.SPAWNING)
	rc.api.activate_ability(rc.api.next_command_id(), &"emp")
	rc.api.activate_ability(rc.api.next_command_id(), &"shield")
	GameRunKit.frames(rc, 3)
	assert_int(rc.sim.abilities.cooldown_left[Ids.AB_EMP]).is_greater(0)
	assert_int(rc.sim.abilities.active_left[Ids.AB_SHIELD]).is_greater(0)
	var hash_before: String = rc.sim.state_hash()
	var cooldowns: PackedInt32Array = rc.sim.abilities.cooldown_left.duplicate()
	var actives: PackedInt32Array = rc.sim.abilities.active_left.duplicate()
	var tick_before: int = rc.sim.tick
	rc.set_paused(true)
	GameRunKit.frames(rc, 600)
	assert_str(rc.sim.state_hash()).is_equal(hash_before)
	assert_int(rc.sim.tick).is_equal(tick_before)
	assert_array(rc.sim.abilities.cooldown_left).is_equal(cooldowns)
	assert_array(rc.sim.abilities.active_left).is_equal(actives)
	rc.set_paused(false)
	GameRunKit.frames(rc, 1)
	assert_int(rc.sim.tick).is_equal(tick_before + 1)


func test_a_purchase_while_paused_is_rejected_and_never_reaches_the_sim() -> void:
	var cfg: SimConfig = GameRunKit.config()
	cfg.debug_start_scrap = 500
	var rc: RunController = GameRunKit.controller(self, cfg)
	rc.set_paused(true)
	var hash_before: String = rc.sim.state_hash()
	rc.api.purchase_upgrade(41, &"damage")
	assert_array(_log.last_args(&"purchase_resolved")).is_equal([41, false, Reason.Id.PAUSED])
	assert_int(rc.sim.command_queue.size()).is_equal(0)
	assert_str(rc.sim.state_hash()).is_equal(hash_before)
	rc.set_paused(false)
	GameRunKit.frames(rc, 3)
	assert_int(rc.sim.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)
	assert_int(rc.sim.command_log.entries.size()).is_equal(0)


func test_an_ability_while_paused_is_rejected_and_never_reaches_the_sim() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	GameRunKit.frames(rc, rc.sim.content.mission.prepare_ticks + 5)
	rc.set_paused(true)
	rc.api.activate_ability(52, &"emp")
	assert_array(_log.last_args(&"ability_rejected")).is_equal([&"emp", Reason.Id.PAUSED])
	assert_int(rc.sim.command_queue.size()).is_equal(0)
	rc.api.skip_intermission()
	assert_int(rc.sim.command_queue.size()).is_equal(0)


func test_unknown_ids_and_commands_after_the_end_are_rejected_without_a_sim_command() -> void:
	var cfg: SimConfig = GameRunKit.config(1, true, 1)
	var rc: RunController = GameRunKit.controller(self, cfg)
	rc.api.purchase_upgrade(60, &"nonsense")
	assert_array(_log.last_args(&"purchase_resolved")).is_equal([60, false, Reason.Id.UNKNOWN_ID])
	assert_int(GameRunKit.run_to_end(rc, 60000)).is_greater(0)
	rc.api.purchase_upgrade(61, &"damage")
	assert_array(_log.last_args(&"purchase_resolved")).is_equal([61, false, Reason.Id.WRONG_STATE])
	assert_int(rc.sim.command_queue.size()).is_equal(0)


func test_a_command_through_the_api_is_applied_once_on_the_next_tick() -> void:
	var cfg: SimConfig = GameRunKit.config()
	cfg.debug_start_scrap = 500
	var rc: RunController = GameRunKit.controller(self, cfg)
	rc.api.purchase_upgrade(70, &"damage")
	assert_int(rc.sim.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)
	GameRunKit.frames(rc, 1)
	assert_int(rc.sim.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	assert_array(_log.last_args(&"purchase_resolved")).is_equal([70, true, Reason.Id.OK])
	assert_array(_log.last_args(&"upgrade_level_changed")).is_equal([&"damage", 1])


func test_pausing_is_refused_after_the_run_ended() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config(1, true, 1))
	assert_int(GameRunKit.run_to_end(rc, 60000)).is_greater(0)
	rc.set_paused(true)
	assert_bool(rc.paused).is_false()


func test_stop_frees_the_sim_and_a_second_stop_is_harmless() -> void:
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config())
	rc.stop()
	assert_object(rc.sim).is_null()
	assert_int(rc.step_frame(1.0)).is_equal(0)
	rc.stop()


func test_the_view_is_bound_while_running_and_unbound_after_stop() -> void:
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate() as BattleView
	auto_free(view)
	add_child(view)
	view.setup(TestContent.baseline())
	var before: int = GameSignalLog.events_connection_count()
	var rc: RunController = GameRunKit.controller(self, GameRunKit.config(), view)
	assert_int(GameSignalLog.events_connection_count()).is_greater(before)
	GameRunKit.frames(rc, 5)
	rc.stop()
	assert_int(GameSignalLog.events_connection_count()).is_equal(before)
