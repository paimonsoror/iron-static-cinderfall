extends GdUnitTestSuite
## AudioEventRouter: which Events signal makes which sound. A fake source node stands in for `Events`.

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


func _last() -> StringName:
	return _dir.recent_ids.back() if not _dir.recent_ids.is_empty() else &""


func test_enemy_killed_of_a_hulk_is_death_boss() -> void:
	_events.enemy_spawned.emit(7, &"siege_hulk")
	_events.enemy_killed.emit(7, DamageSource.Id.WARDEN)
	assert_array(_dir.recent_ids).is_equal([&"death_boss"])


func test_deaths_by_class() -> void:
	_events.enemy_spawned.emit(1, &"skitter")
	_events.enemy_spawned.emit(2, &"rusher")
	_events.enemy_spawned.emit(3, &"hollow_warden")
	_events.enemy_killed.emit(1, 0)
	_events.enemy_killed.emit(2, 0)
	_events.enemy_killed.emit(3, 0)
	assert_array(_dir.recent_ids).is_equal([&"death_small", &"death_small", &"death_heavy"])


func test_a_death_of_an_unknown_enemy_is_the_small_burst_and_ids_are_forgotten_after_the_kill() -> void:
	_events.enemy_killed.emit(99, 0)
	assert_array(_dir.recent_ids).is_equal([&"death_small"])
	_events.enemy_spawned.emit(5, &"siege_hulk")
	_events.enemy_killed.emit(5, 0)
	_events.enemy_spawned.emit(5, &"skitter")  # the store reuses ids
	_events.enemy_killed.emit(5, 0)
	assert_array(_dir.recent_ids).is_equal([&"death_small", &"death_boss", &"death_small"])


func test_hits_use_the_dull_sound_for_armored_kinds_and_the_bright_one_for_ceramic() -> void:
	_events.enemy_spawned.emit(1, &"skitter")
	_events.enemy_spawned.emit(2, &"hollow_warden")
	_events.enemy_spawned.emit(3, &"rusher")
	_events.enemy_damaged.emit(1, 20.0, 0)
	assert_array(_dir.recent_ids).is_equal([&"hit_ceramic"])
	_events.enemy_damaged.emit(2, 20.0, 0)
	_events.enemy_damaged.emit(3, 20.0, 0)
	assert_array(_dir.recent_ids).is_equal([&"hit_ceramic", &"hit_armor", &"hit_armor"])
	_events.enemy_damaged.emit(2, 0.0, 0)  # nothing got through: no hit sound
	assert_int(_dir.started_total).is_equal(3)


func test_shots_follow_the_weapon_and_turrets_have_their_own_sound() -> void:
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_that(_last()).is_equal(&"shot_pistol")
	_events.weapon_changed.emit(&"smg")
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_that(_last()).is_equal(&"shot_smg")
	_events.shot_fired.emit(DamageSource.Id.TURRET_0, 1)
	assert_that(_last()).is_equal(&"shot_turret")
	_events.shot_fired.emit(DamageSource.Id.TURRET_1, 1)
	assert_that(_last()).is_equal(&"shot_turret")
	_events.run_started.emit("r", 1)  # a new run starts with the pistol again
	_events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_that(_last()).is_equal(&"shot_pistol")


func test_core_hits_light_heavy_and_the_hulk_stomp() -> void:
	_events.core_hit.emit(1, &"skitter", 12.0, 0.0)
	assert_array(_dir.recent_ids).is_equal([&"core_hit_light"])
	_events.core_hit.emit(2, &"hollow_warden", 30.0, 0.0)
	assert_that(_last()).is_equal(&"core_hit_heavy")
	_events.core_hit.emit(3, &"siege_hulk", 0.0, 90.0)
	assert_array(_dir.recent_ids).is_equal([&"core_hit_light", &"core_hit_heavy", &"boss_stomp", &"core_hit_heavy"])
	_events.core_hit.emit(4, &"future_kind", 5.0, 0.0)
	assert_that(_last()).is_equal(&"core_hit_light")
	_events.core_hit.emit(5, &"future_kind", 50.0, 0.0)
	assert_that(_last()).is_equal(&"core_hit_heavy")


func test_abilities_reload_and_waves() -> void:
	_events.ability_activated.emit(&"emp")
	_events.ability_activated.emit(&"shield")
	_events.ability_activated.emit(&"overdrive")
	_events.ability_ended.emit(&"emp")  # no sound for the end of the EMP
	_events.ability_ended.emit(&"shield")
	_events.ability_ended.emit(&"overdrive")
	_events.reload_started.emit(90)
	_events.reload_finished.emit()
	_events.wave_started.emit(2)
	_events.wave_cleared.emit(2)
	assert_array(_dir.recent_ids).is_equal([
		&"emp", &"shield_up", &"overdrive_on", &"shield_break", &"overdrive_off",
		&"reload_start", &"reload_done", &"wave_start", &"wave_clear",
	])


func test_boss_spawn_plays_the_stinger_and_raises_the_drone_to_full() -> void:
	_events.boss_spawned.emit(3, &"siege_hulk")
	assert_array(_dir.recent_ids).is_equal([&"boss_stinger"])
	assert_float(_dir.intensity()).is_equal(1.0)
	_events.enemy_killed.emit(3, 0)
	assert_that(_last()).is_equal(&"death_boss")  # the boss kind was learned from boss_spawned too


func test_victory_and_defeat_stingers_and_the_beds_stop() -> void:
	_events.run_started.emit("r", 1)
	assert_bool(_dir.is_ambience_wanted()).is_true()
	_events.run_finished.emit(RunResult.Id.VICTORY, "r")
	assert_that(_last()).is_equal(&"victory")
	assert_bool(_dir.is_ambience_wanted()).is_false()
	_events.run_started.emit("r2", 2)
	_events.run_finished.emit(RunResult.Id.DEFEAT, "r2")
	assert_that(_last()).is_equal(&"defeat")
	var before: int = _dir.started_total
	_events.run_finished.emit(RunResult.Id.ABANDONED, "r3")
	assert_int(_dir.started_total).is_equal(before)


func test_the_drone_level_follows_the_wave_number() -> void:
	assert_float(AudioEventRouter.intensity_for_wave(1)).is_equal_approx(0.2, 0.0001)
	assert_float(AudioEventRouter.intensity_for_wave(5)).is_equal(1.0)
	assert_float(AudioEventRouter.intensity_for_wave(9)).is_equal(1.0)
	assert_float(AudioEventRouter.intensity_for_wave(0)).is_equal(0.0)
	_events.wave_started.emit(3)
	assert_float(_dir.intensity()).is_equal_approx(0.6, 0.0001)
	_events.intermission_started.emit(3, 480)
	assert_float(_dir.intensity()).is_equal_approx(AudioEventRouter.INTERMISSION_INTENSITY, 0.0001)
	_events.wave_started.emit(4)
	assert_float(_dir.intensity()).is_equal_approx(0.8, 0.0001)
