extends GdUnitTestSuite
## GameEventRelay: every SimEventKind maps to its Events signal with the right payload (ARCH 6.3 -> 7.1).

var _log: GameSignalLog
var _relay: GameEventRelay


func before_test() -> void:
	_log = GameSignalLog.new()
	_log.attach()
	_relay = GameEventRelay.new(TestContent.baseline())


func after_test() -> void:
	_log.detach()


func _ev(kind: int, a: int = 0, b: int = 0, f: float = 0.0, g: float = 0.0) -> SimEvent:
	var e: SimEvent = SimEvent.new()
	e.kind = kind
	e.a = a
	e.b = b
	e.f = f
	e.g = g
	return e


func _send(kind: int, a: int = 0, b: int = 0, f: float = 0.0, g: float = 0.0) -> bool:
	return _relay.relay(_ev(kind, a, b, f, g))


func test_every_kind_is_either_relayed_or_deliberately_not() -> void:
	var local_only: Array[int] = [SimEventKind.Id.PHASE_CHANGED, SimEventKind.Id.RUN_FINISHED]
	for kind: int in SimEventKind.Id.values():
		_log.clear()
		var relayed: bool = _send(kind)
		if local_only.has(kind) or GameEventRelay.NO_SIGNAL.has(kind):
			assert_bool(relayed).is_false()
			assert_int(_log.rows.size()).is_equal(0)
		else:
			assert_bool(relayed).is_true()
			assert_int(_log.rows.size()).is_greater(0)


func test_wave_events() -> void:
	_send(SimEventKind.Id.WAVE_STARTED, 3, 28)
	_send(SimEventKind.Id.WAVE_CLEARED, 3)
	_send(SimEventKind.Id.INTERMISSION_STARTED, 3, 480)
	assert_array(_log.first_args(&"wave_started")).is_equal([3])
	assert_array(_log.first_args(&"wave_cleared")).is_equal([3])
	assert_array(_log.first_args(&"intermission_started")).is_equal([3, 480])


func test_spawn_events_map_the_type_index_to_the_enemy_id() -> void:
	_send(SimEventKind.Id.ENEMY_SPAWNED, 41, Ids.EN_RUSHER, 5.0, -3.0)
	_send(SimEventKind.Id.BOSS_SPAWNED, 42, Ids.EN_HULK)
	assert_array(_log.first_args(&"enemy_spawned")).is_equal([41, &"rusher"])
	assert_array(_log.first_args(&"boss_spawned")).is_equal([42, &"siege_hulk"])


func test_shot_and_damage_events() -> void:
	_send(SimEventKind.Id.SHOT_FIRED, DamageSource.Id.TURRET_1, 17)
	_send(SimEventKind.Id.ENEMY_DAMAGED, 17, DamageSource.Id.WARDEN, 22.0, 23.0)
	assert_array(_log.first_args(&"shot_fired")).is_equal([DamageSource.Id.TURRET_1, 17])
	assert_array(_log.first_args(&"enemy_damaged")).is_equal([17, 22.0, DamageSource.Id.WARDEN])


func test_a_kill_emits_killed_then_died_at_with_the_kind_and_scrap_of_the_spawned_enemy() -> void:
	var scrap: int = TestContent.baseline().enemies[Ids.EN_HOLLOW].scrap
	_send(SimEventKind.Id.ENEMY_SPAWNED, 9, Ids.EN_HOLLOW, 1.0, 2.0)
	_log.clear()
	_send(SimEventKind.Id.ENEMY_KILLED, 9, DamageSource.Id.TURRET_0, 4.5, -6.5)
	assert_array(_log.names()).is_equal([&"enemy_killed", &"enemy_died_at"])
	assert_array(_log.first_args(&"enemy_killed")).is_equal([9, DamageSource.Id.TURRET_0])
	assert_array(_log.first_args(&"enemy_died_at")).is_equal([9, &"hollow_warden", 4.5, -6.5, scrap])
	assert_int(_relay.tracked_count()).is_equal(0)  # the id is forgotten once it died


func test_a_kill_of_an_enemy_the_relay_never_saw_still_emits_with_an_empty_kind() -> void:
	_send(SimEventKind.Id.ENEMY_KILLED, 77, DamageSource.Id.WARDEN, 1.0, 1.0)
	assert_array(_log.first_args(&"enemy_died_at")).is_equal([77, &"", 1.0, 1.0, 0])


func test_core_and_shield_and_scrap_events() -> void:
	_send(SimEventKind.Id.CORE_HIT, 5, Ids.EN_SKITTER, 12.0, 3.0)
	_send(SimEventKind.Id.CORE_CHANGED, 0, 0, 988.0, 1000.0)
	_send(SimEventKind.Id.SHIELD_CHANGED, 0, 0, 60.0, 100.0)
	_send(SimEventKind.Id.SCRAP_CHANGED, 245, 25)
	assert_array(_log.first_args(&"core_hit")).is_equal([5, &"skitter", 12.0, 3.0])
	assert_array(_log.first_args(&"core_changed")).is_equal([988.0, 1000.0])
	assert_array(_log.first_args(&"shield_changed")).is_equal([60.0, 100.0])
	assert_array(_log.first_args(&"scrap_changed")).is_equal([245])


func test_purchase_events() -> void:
	_send(SimEventKind.Id.PURCHASE_RESOLVED, 12, Reason.Id.OK, 1.0)
	_send(SimEventKind.Id.PURCHASE_RESOLVED, 13, Reason.Id.INSUFFICIENT_SCRAP, 0.0)
	_send(SimEventKind.Id.UPGRADE_LEVEL_CHANGED, Ids.UP_FIRE_RATE, 2)
	_send(SimEventKind.Id.WEAPON_CHANGED, 1)
	_send(SimEventKind.Id.TURRET_DEPLOYED, 1)
	assert_array(_log.first_args(&"purchase_resolved")).is_equal([12, true, Reason.Id.OK])
	assert_array(_log.last_args(&"purchase_resolved")).is_equal([13, false, Reason.Id.INSUFFICIENT_SCRAP])
	assert_array(_log.first_args(&"upgrade_level_changed")).is_equal([&"fire_rate", 2])
	assert_array(_log.first_args(&"weapon_changed")).is_equal([&"smg"])
	assert_array(_log.first_args(&"turret_deployed")).is_equal([1])


func test_reload_and_ability_events() -> void:
	_send(SimEventKind.Id.RELOAD_STARTED, 75)
	_send(SimEventKind.Id.RELOAD_FINISHED)
	_send(SimEventKind.Id.ABILITY_ACTIVATED, Ids.AB_SHIELD, 4)
	_send(SimEventKind.Id.ABILITY_ENDED, Ids.AB_SHIELD)
	_send(SimEventKind.Id.ABILITY_REJECTED, Ids.AB_EMP, Reason.Id.ON_COOLDOWN, 8.0)
	_send(SimEventKind.Id.ENEMY_STUNNED, 30, 180)
	_send(SimEventKind.Id.ENEMY_STUCK, 31, 1)
	assert_array(_log.first_args(&"reload_started")).is_equal([75])
	assert_int(_log.count(&"reload_finished")).is_equal(1)
	assert_array(_log.first_args(&"ability_activated")).is_equal([&"shield"])
	assert_array(_log.first_args(&"ability_ended")).is_equal([&"shield"])
	assert_array(_log.first_args(&"ability_rejected")).is_equal([&"emp", Reason.Id.ON_COOLDOWN])
	assert_array(_log.first_args(&"enemy_stunned")).is_equal([30, 180])
	assert_array(_log.first_args(&"enemy_stuck")).is_equal([31])


func test_out_of_range_indices_become_empty_ids_instead_of_crashing() -> void:
	_send(SimEventKind.Id.ENEMY_SPAWNED, 1, 99)
	_send(SimEventKind.Id.UPGRADE_LEVEL_CHANGED, -1, 1)
	_send(SimEventKind.Id.ABILITY_ACTIVATED, 7, 0)
	assert_array(_log.first_args(&"enemy_spawned")).is_equal([1, &""])
	assert_array(_log.first_args(&"upgrade_level_changed")).is_equal([&"", 1])
	assert_array(_log.first_args(&"ability_activated")).is_equal([&""])
