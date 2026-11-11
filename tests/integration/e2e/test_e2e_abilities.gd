extends GdUnitTestSuite
## Ability taps through the HUD API, the controller, the sim and the event stream (A12, A13): a tap on cooldown, while
## active, outside a combat phase or while paused is rejected with the right reason, starts nothing and never restarts
## a cooldown. Boosted damage and an invulnerable core keep a baseline run alive without purchases.

var _h: GameHarness


func before_test() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--autoplay=none", "--seed=11"]), IntegrationKit.two_waves)
	_h.game.set(&"sim_config_hook", IntegrationKit.boost)
	_h.boot()


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


## Taps `id` once and runs two frames. Returns the last `ability_rejected` reason of that tap, or -1 when it started.
func _tap(id: StringName) -> int:
	var api: SimRunApi = _h.rc().api
	var rejected_before: int = _h.events_log.count(&"ability_rejected")
	api.activate_ability(api.next_command_id(), id)
	_h.frames(2)
	if _h.events_log.count(&"ability_rejected") == rejected_before:
		return -1
	var args: Array = _h.events_log.last_args(&"ability_rejected")
	var rejected_id: StringName = args[0]
	assert_str(String(rejected_id)).is_equal(String(id))
	var reason: int = args[1]
	return reason


func _in_combat() -> void:
	assert_int(IntegrationKit.run_to_phase(_h, GameState.Id.SPAWNING, 2000)).is_greater_equal(0)
	_h.frames(60)


func test_a_tap_outside_a_combat_phase_is_refused_for_every_ability() -> void:
	for id: StringName in Ids.ABILITIES:  # PREPARING
		assert_int(_tap(id)).is_equal(Reason.Id.WRONG_STATE)
	assert_int(IntegrationKit.run_to_phase(_h, GameState.Id.INTERMISSION, 9000)).is_greater_equal(0)
	for id: StringName in Ids.ABILITIES:
		assert_int(_tap(id)).is_equal(Reason.Id.WRONG_STATE)
	assert_int(_h.events_log.count(&"ability_activated")).is_equal(0)
	for id: StringName in Ids.ABILITIES:
		assert_int(_h.rc().api.ability_cooldown_left(id)).is_equal(0)  # a refusal starts no cooldown


func test_emp_taps_on_cooldown_are_refused_and_never_restart_the_cooldown() -> void:
	_in_combat()
	assert_int(_tap(&"emp")).is_equal(-1)
	assert_int(_h.events_log.count(&"ability_activated")).is_equal(1)
	assert_array(_h.events_log.last_args(&"ability_activated")).is_equal([&"emp"])
	var total: int = _h.rc().api.ability_cooldown_total(&"emp")
	var left: int = _h.rc().api.ability_cooldown_left(&"emp")
	assert_int(left).is_between(total - 3, total)
	_h.frames(300)
	var later: int = _h.rc().api.ability_cooldown_left(&"emp")
	assert_int(later).is_equal(left - 300)
	assert_int(_tap(&"emp")).is_equal(Reason.Id.ON_COOLDOWN)
	assert_int(_h.rc().api.ability_cooldown_left(&"emp")).is_equal(later - 2)  # it kept counting down
	assert_int(_h.events_log.count(&"ability_activated")).is_equal(1)


func test_shield_is_refused_while_active_then_on_cooldown_after_it_ended() -> void:
	_in_combat()
	assert_int(_tap(&"shield")).is_equal(-1)
	assert_float(_h.rc().api.shield_hp()).is_equal(_h.rc().api.shield_max())
	assert_int(_tap(&"shield")).is_equal(Reason.Id.ALREADY_ACTIVE)
	assert_int(_h.events_log.count(&"ability_activated")).is_equal(1)
	var guard: int = 0
	while _h.rc().api.ability_active_left(&"shield") > 0 and guard < 1000:
		_h.frames(1)
		guard += 1
	assert_int(_h.events_log.count(&"ability_ended")).is_equal(1)
	assert_int(_h.rc().api.ability_cooldown_left(&"shield")).is_greater(0)  # the cooldown starts when it ends
	var left: int = _h.rc().api.ability_cooldown_left(&"shield")
	assert_int(_tap(&"shield")).is_equal(Reason.Id.ON_COOLDOWN)
	assert_int(_h.rc().api.ability_cooldown_left(&"shield")).is_equal(left - 2)
	assert_int(_h.events_log.count(&"ability_activated")).is_equal(1)


func test_overdrive_is_refused_while_active_then_on_cooldown_after_it_ended() -> void:
	_in_combat()
	assert_int(_tap(&"overdrive")).is_equal(-1)
	assert_int(_tap(&"overdrive")).is_equal(Reason.Id.ALREADY_ACTIVE)
	var guard: int = 0
	while _h.rc().api.ability_active_left(&"overdrive") > 0 and guard < 1000:
		_h.frames(1)
		guard += 1
	assert_int(_h.events_log.count(&"ability_ended")).is_equal(1)
	var left: int = _h.rc().api.ability_cooldown_left(&"overdrive")
	assert_int(left).is_greater(0)
	assert_int(_tap(&"overdrive")).is_equal(Reason.Id.ON_COOLDOWN)
	assert_int(_h.rc().api.ability_cooldown_left(&"overdrive")).is_equal(left - 2)


func test_taps_while_paused_are_refused_with_paused_and_leave_everything_alone() -> void:
	_in_combat()
	assert_int(_tap(&"overdrive")).is_equal(-1)  # a live timer to compare
	_h.hud().pause_requested.emit()
	var before: Dictionary = IntegrationKit.frozen_state(_h.rc())
	for id: StringName in Ids.ABILITIES:
		var api: SimRunApi = _h.rc().api
		api.activate_ability(api.next_command_id(), id)
		assert_array(_h.events_log.last_args(&"ability_rejected")).is_equal([id, Reason.Id.PAUSED])
	_h.frames(120)
	assert_dict(IntegrationKit.frozen_state(_h.rc())).is_equal(before)
	assert_int(_h.rc().sim.command_queue.size()).is_equal(0)
	_h.call_game(&"resume_run")
	assert_int(_tap(&"emp")).is_equal(-1)  # after RESUME the same tap works
	assert_int(_tap(&"shield")).is_equal(-1)


func test_the_same_command_id_twice_activates_once() -> void:
	_in_combat()
	var api: SimRunApi = _h.rc().api
	var command_id: int = api.next_command_id()
	api.activate_ability(command_id, &"shield")
	api.activate_ability(command_id, &"shield")  # a double tap that carried one id
	_h.frames(2)
	assert_int(_h.events_log.count(&"ability_activated")).is_equal(1)
	assert_array(_h.events_log.last_args(&"ability_rejected")).is_equal([&"shield", Reason.Id.DUPLICATE_COMMAND])
