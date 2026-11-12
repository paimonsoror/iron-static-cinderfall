extends GdUnitTestSuite
## AudioEventRouter: timed sounds (heartbeat, intermission ticks), pause mirroring, wiring hygiene and the tables.

var _events: AudioTestEvents
var _dir: AudioDirector


func before_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	_events = auto_free(AudioTestEvents.new())
	add_child(_events)
	_dir = AudioTestKit.make_routed(self, _events)


func after_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	Sfx.apply_settings()


func _count(id: StringName) -> int:
	var n: int = 0
	for played: StringName in _dir.recent_ids:
		if played == id:
			n += 1
	return n


func test_the_heartbeat_starts_below_25_percent_and_repeats_until_the_core_recovers() -> void:
	_events.core_changed.emit(300.0, 1000.0)
	assert_int(_count(&"core_low")).is_equal(0)
	_events.core_changed.emit(249.0, 1000.0)
	assert_int(_count(&"core_low")).is_equal(1)
	_events.core_changed.emit(200.0, 1000.0)  # already low: no second immediate beat
	assert_int(_count(&"core_low")).is_equal(1)
	_dir.advance(1.0)
	assert_int(_count(&"core_low")).is_equal(1)
	_dir.advance(0.2)
	assert_int(_count(&"core_low")).is_equal(2)
	_events.core_changed.emit(600.0, 1000.0)
	_dir.advance(5.0)
	assert_int(_count(&"core_low")).is_equal(2)


func test_a_dead_core_stops_the_heartbeat() -> void:
	_events.core_changed.emit(100.0, 1000.0)
	_events.core_changed.emit(0.0, 1000.0)
	_dir.advance(3.0)
	assert_int(_count(&"core_low")).is_equal(1)


func test_the_intermission_ticks_at_3_2_and_1_seconds_left_only() -> void:
	_events.intermission_started.emit(1, 480)  # 8 s at 60 ticks per second
	assert_float(_dir.router.intermission_left).is_equal_approx(8.0, 0.0001)
	_dir.advance(4.9)
	assert_int(_count(&"intermission_tick")).is_equal(0)
	_dir.advance(0.2)  # 2.9 s left: crossed 3
	assert_int(_count(&"intermission_tick")).is_equal(1)
	_dir.advance(1.0)  # 1.9: crossed 2
	assert_int(_count(&"intermission_tick")).is_equal(2)
	_dir.advance(1.0)  # 0.9: crossed 1
	assert_int(_count(&"intermission_tick")).is_equal(3)
	_dir.advance(5.0)
	assert_int(_count(&"intermission_tick")).is_equal(3)
	assert_float(_dir.router.intermission_left).is_equal(-1.0)


func test_continue_cancels_the_intermission_countdown() -> void:
	_events.intermission_started.emit(2, 480)
	_dir.advance(4.0)
	_events.wave_started.emit(3)
	_dir.advance(6.0)
	assert_int(_count(&"intermission_tick")).is_equal(0)


func test_timers_freeze_while_paused() -> void:
	_events.intermission_started.emit(1, 480)
	_events.core_changed.emit(100.0, 1000.0)
	_dir.pause_all()
	var before: float = _dir.router.intermission_left
	_dir.advance(10.0)
	assert_float(_dir.router.intermission_left).is_equal(before)
	_dir.resume_all()
	_dir.advance(1.0)
	assert_float(_dir.router.intermission_left).is_equal_approx(before - 1.0, 0.0001)


func test_the_paused_state_pauses_and_resumes_the_audio() -> void:
	_events.state_changed.emit(GameState.Id.SPAWNING, GameState.Id.PAUSED)
	assert_bool(_dir.is_paused()).is_true()
	_events.state_changed.emit(GameState.Id.PAUSED, GameState.Id.SPAWNING)
	assert_bool(_dir.is_paused()).is_false()


func test_leaving_the_run_for_a_menu_stops_the_beds_even_from_pause() -> void:
	_events.run_started.emit("r", 1)
	assert_bool(_dir.is_ambience_wanted()).is_true()
	_events.state_changed.emit(GameState.Id.SPAWNING, GameState.Id.PAUSED)
	_events.state_changed.emit(GameState.Id.PAUSED, GameState.Id.MENU)
	assert_bool(_dir.is_paused()).is_false()
	assert_bool(_dir.is_ambience_wanted()).is_false()


func test_bind_is_idempotent_and_unbind_leaves_no_connections() -> void:
	var router: AudioEventRouter = _dir.router
	assert_bool(router.is_bound()).is_true()
	for sig: StringName in router.signal_names():
		assert_int(_events.get_signal_connection_list(sig).size()).override_failure_message(String(sig)).is_equal(1)
	router.bind(_events, _dir)
	router.bind(_events, _dir)
	for sig: StringName in router.signal_names():
		assert_int(_events.get_signal_connection_list(sig).size()).override_failure_message(String(sig)).is_equal(1)
	router.unbind()
	assert_bool(router.is_bound()).is_false()
	for sig: StringName in router.signal_names():
		assert_int(_events.get_signal_connection_list(sig).size()).override_failure_message(String(sig)).is_equal(0)
	_events.enemy_killed.emit(1, 0)
	assert_int(_dir.started_total).is_equal(0)


func test_every_signal_the_router_uses_exists_on_events_with_the_same_arguments() -> void:
	var router: AudioEventRouter = AudioEventRouter.new()
	var args_of: Dictionary[StringName, int] = {}
	for entry: Dictionary in Events.get_signal_list():
		var sig_name: StringName = entry["name"]
		var args: Array = entry["args"]
		args_of[sig_name] = args.size()
	for sig: StringName in router.signal_names():
		assert_bool(args_of.has(sig)).override_failure_message("Events has no signal %s" % String(sig)).is_true()
		assert_int(args_of[sig]).override_failure_message("argument count of %s" % String(sig)).is_equal(router.handler_for(sig).get_argument_count())


func test_the_real_events_bus_binds_and_unbinds_cleanly() -> void:
	var router: AudioEventRouter = AudioEventRouter.new()
	var before: int = Events.get_signal_connection_list(&"enemy_killed").size()
	router.bind(Events, _dir)
	assert_int(Events.get_signal_connection_list(&"enemy_killed").size()).is_equal(before + 1)
	router.unbind()
	assert_int(Events.get_signal_connection_list(&"enemy_killed").size()).is_equal(before)


func test_the_tables_only_name_known_enemies_abilities_and_sounds() -> void:
	for kind: StringName in AudioEventRouter.ARMORED_KINDS + AudioEventRouter.HEAVY_CORE_KINDS + AudioEventRouter.LIGHT_CORE_KINDS:
		assert_bool(Ids.ENEMIES.has(kind)).override_failure_message("unknown enemy %s" % String(kind)).is_true()
	assert_bool(Ids.ENEMIES.has(AudioEventRouter.BOSS_KIND)).is_true()
	assert_bool(Ids.WEAPONS.has(AudioEventRouter.SMG_ID)).is_true()
	for kind: StringName in AudioEventRouter.DEATH_SOUNDS:
		assert_bool(Ids.ENEMIES.has(kind)).is_true()
		var sound: StringName = AudioEventRouter.DEATH_SOUNDS[kind]
		assert_bool(AudioCatalog.has_sound(sound)).is_true()
	assert_int(AudioEventRouter.DEATH_SOUNDS.size()).is_equal(Ids.LEGACY_ENEMY_COUNT)
	for ability: StringName in AudioEventRouter.ABILITY_START_SOUNDS:
		assert_bool(Ids.ABILITIES.has(ability)).is_true()
		var started: StringName = AudioEventRouter.ABILITY_START_SOUNDS[ability]
		assert_bool(AudioCatalog.has_sound(started)).is_true()
	for ability: StringName in AudioEventRouter.ABILITY_END_SOUNDS:
		assert_bool(Ids.ABILITIES.has(ability)).is_true()
		var ended: StringName = AudioEventRouter.ABILITY_END_SOUNDS[ability]
		assert_bool(AudioCatalog.has_sound(ended)).is_true()
	assert_float(AudioEventRouter.TICKS_PER_SECOND).is_equal(60.0)
