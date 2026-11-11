extends GdUnitTestSuite
## Purchases change what the event stream shows, not just the labels (A10, A11): after the SMG the Warden's
## `shot_fired` cadence triples (6 per second, 10 ticks apart); each turret adds its own source (TURRET_0, TURRET_1)
## at 3 shots per second (20 ticks apart); the third turret is refused. `--scenario=hold24` keeps 24 enemies alive on
## the real sim, so there is always something to shoot. Buying goes through the HUD API, the controller and the sim.

const WINDOW: int = 900  ## ticks per measurement (15 s)

var _h: GameHarness
var _shots: IntegrationShotLog


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--scenario=hold24", "--seed=4"]), IntegrationKit.smg_from_wave_one)
	_h.game.set(&"sim_config_hook", IntegrationKit.rich)
	_h.boot()
	_shots = IntegrationShotLog.new()
	_shots.attach(_tick)


func after_test() -> void:
	_shots.detach()
	if _h != null:
		_h.dispose()
		_h = null


func _tick() -> int:
	return _h.rc().sim.tick


## Runs `WINDOW` ticks and returns the tick the window started after.
func _window() -> int:
	var start: int = _tick()
	_h.frames(WINDOW)
	return start


func _buy(id: StringName) -> void:
	var api: SimRunApi = _h.rc().api
	api.purchase_upgrade(api.next_command_id(), id)
	_h.frames(2)


func _warm_up() -> void:
	_h.frames(_h.content.mission.prepare_ticks + 400)  # the crowd has arrived
	assert_int(_h.rc().sim.alive_count()).is_greater_equal(15)


func test_the_smg_purchase_triples_the_warden_cadence_in_the_event_stream() -> void:
	_warm_up()
	var w0: int = _window()
	var pistol: Array[int] = _shots.ticks_of(DamageSource.Id.WARDEN, w0, w0 + WINDOW)
	assert_array(_shots.sources_in(w0, w0 + WINDOW)).is_equal([DamageSource.Id.WARDEN])  # no turret yet
	assert_int(_h.rc().api.magazine_size()).is_equal(12)
	_buy(&"smg_unlock")
	var bought: Array = _h.events_log.last_args(&"purchase_resolved")
	assert_bool(bought[1]).is_true()
	assert_int(bought[2]).is_equal(Reason.Id.OK)
	assert_array(_h.events_log.last_args(&"weapon_changed")).is_equal([&"smg"])
	assert_int(_h.rc().api.magazine_size()).is_equal(30)
	_h.frames(150)
	var w1: int = _window()
	var smg: Array[int] = _shots.ticks_of(DamageSource.Id.WARDEN, w1, w1 + WINDOW)
	# 2 shots a second with 12 rounds and a 75 tick reload is about 25 shots in 15 s; 6 a second with 30 and 96 is about 68
	assert_int(pistol.size()).is_between(22, 27)
	assert_int(smg.size()).is_between(60, 76)
	assert_float(float(smg.size()) / float(pistol.size())).is_greater(2.3)
	assert_int(IntegrationShotLog.min_gap(pistol)).is_between(29, 30)  # 2 per second = every 30 ticks
	assert_int(IntegrationShotLog.min_gap(smg)).is_between(9, 10)  # 6 per second = every 10 ticks
	assert_array(_shots.sources_in(w1, w1 + WINDOW)).is_equal([DamageSource.Id.WARDEN])  # still only the Warden


func test_each_turret_adds_its_own_shot_source_at_three_shots_a_second() -> void:
	_warm_up()
	_buy(&"auto_turret")
	assert_array(_h.events_log.last_args(&"turret_deployed")).is_equal([0])
	var a0: int = _window()
	assert_array(_shots.sources_in(a0, a0 + WINDOW)).is_equal([DamageSource.Id.WARDEN, DamageSource.Id.TURRET_0])
	var first: Array[int] = _shots.ticks_of(DamageSource.Id.TURRET_0, a0, a0 + WINDOW)
	assert_int(first.size()).is_between(30, 45)  # 3 per second is at most 45 in 15 s
	assert_int(IntegrationShotLog.min_gap(first)).is_between(19, 20)  # every 20 ticks, 19 after an idle spell
	_buy(&"auto_turret")
	assert_array(_h.events_log.last_args(&"turret_deployed")).is_equal([1])
	var b0: int = _window()
	assert_array(_shots.sources_in(b0, b0 + WINDOW)).is_equal([
		DamageSource.Id.WARDEN, DamageSource.Id.TURRET_0, DamageSource.Id.TURRET_1
	])
	var second: Array[int] = _shots.ticks_of(DamageSource.Id.TURRET_1, b0, b0 + WINDOW)
	assert_int(second.size()).is_between(30, 45)
	assert_int(IntegrationShotLog.min_gap(second)).is_between(19, 20)


func test_a_third_turret_is_refused_and_costs_nothing() -> void:
	_warm_up()
	_buy(&"auto_turret")
	_buy(&"auto_turret")
	var scrap: int = _h.rc().api.scrap()
	var levels: int = _h.rc().api.upgrade_level(&"auto_turret")
	assert_int(levels).is_equal(2)
	assert_int(_h.rc().api.purchase_block_reason(&"auto_turret")).is_equal(Reason.Id.MAX_LEVEL)
	var command_id: int = _h.rc().api.next_command_id()
	_h.rc().api.purchase_upgrade(command_id, &"auto_turret")
	_h.frames(2)
	assert_array(_h.events_log.last_args(&"purchase_resolved")).is_equal([command_id, false, Reason.Id.MAX_LEVEL])
	assert_int(_h.rc().api.upgrade_level(&"auto_turret")).is_equal(2)
	assert_int(_h.rc().sim.turrets.active_count()).is_equal(2)
	assert_int(_h.events_log.count(&"turret_deployed")).is_equal(2)
	assert_bool(_h.rc().api.scrap() >= scrap).is_true()  # kills only add Scrap; the refused buy took none


func test_the_same_purchase_command_id_twice_buys_once() -> void:
	_warm_up()
	var api: SimRunApi = _h.rc().api
	var command_id: int = api.next_command_id()
	var before: int = api.scrap()
	api.purchase_upgrade(command_id, &"damage")
	api.purchase_upgrade(command_id, &"damage")  # the double tap of a nervous thumb
	_h.frames(2)
	assert_int(api.upgrade_level(&"damage")).is_equal(1)
	assert_int(_h.events_log.count(&"upgrade_level_changed")).is_equal(1)
	assert_int(api.scrap()).is_greater_equal(before - 175)  # one price; kills only add Scrap
	assert_array(_h.events_log.last_args(&"purchase_resolved")).is_equal([command_id, false, Reason.Id.DUPLICATE_COMMAND])
