extends GdUnitTestSuite
## The ability bar: ready, active and cooling states, radial sweeps, one command per ready tap.

var _api: FakeRunApi
var _hud: CombatHud


func before_test() -> void:
	_api = FakeRunApi.new()
	_api.fake_phase = GameState.Id.SPAWNING
	_hud = CombatTestKit.make_hud(self, _api)


func _button(id: StringName) -> HudAbilityButton:
	return _hud.bottom.abilities.buttons[id]


func test_the_bar_has_three_buttons_named_from_the_string_table() -> void:
	assert_int(_hud.bottom.abilities.buttons.size()).is_equal(3)
	for id: StringName in Ids.ABILITIES:
		assert_str(_button(id).name_label.text).is_equal(Strings.t("ability.%s.name" % String(id)).to_upper())


func test_ready_state_shows_ready_and_a_tap_issues_one_activation_with_a_fresh_id() -> void:
	var b: HudAbilityButton = _button(&"emp")
	assert_int(b.state).is_equal(HudAbilityButton.State.READY)
	assert_str(b.state_label.text).is_equal(Strings.t("hud.ability.ready"))
	assert_bool(b.seconds_label.visible).is_false()
	b.pressed.emit()
	var calls: Array[Dictionary] = CombatTestKit.calls_of(_api, "activate_ability")
	assert_int(calls.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)
	var sent_id: StringName = calls[0]["id"]
	var command_id: int = calls[0]["command_id"]
	assert_str(String(sent_id)).is_equal("emp")
	assert_int(command_id).is_greater(0)
	assert_int(_api.next_command_id()).is_greater(command_id)


func test_active_state_shows_amber_text_seconds_and_a_draining_sweep() -> void:
	_api.fake_ability_active_total[&"shield"] = 480
	_api.fake_ability_active_left[&"shield"] = 240
	_hud.refresh()
	var b: HudAbilityButton = _button(&"shield")
	assert_int(b.state).is_equal(HudAbilityButton.State.ACTIVE)
	assert_str(b.state_label.text).is_equal(Strings.t("hud.ability.active"))
	assert_str(b.seconds_label.text).is_equal(Strings.tf("hud.seconds", [4]))
	assert_bool(b.seconds_label.visible).is_true()
	assert_float(b.radial.fraction).is_equal_approx(0.5, 0.001)
	assert_float(b.bar.fraction).is_equal_approx(0.5, 0.001)


func test_cooling_state_shows_seconds_and_a_sweep_of_the_remaining_time() -> void:
	_api.fake_ability_cooldown_total[&"emp"] = 2100
	_api.fake_ability_cooldown_left[&"emp"] = 525
	_hud.refresh()
	var b: HudAbilityButton = _button(&"emp")
	assert_int(b.state).is_equal(HudAbilityButton.State.COOLING)
	assert_str(b.state_label.text).is_equal(Strings.t("hud.ability.cooling"))
	assert_str(b.seconds_label.text).is_equal(Strings.tf("hud.seconds", [9]))  # 525 ticks = 8.75 s, rounded up
	assert_float(b.radial.fraction).is_equal_approx(0.25, 0.001)
	assert_float(b.bar.fraction).is_equal_approx(0.75, 0.001)


func test_a_tap_while_cooling_issues_no_command() -> void:
	_api.fake_ability_cooldown_left[&"overdrive"] = 1800
	_hud.refresh()
	_button(&"overdrive").pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_a_tap_while_active_issues_no_command() -> void:
	_api.fake_ability_active_left[&"shield"] = 100
	_hud.refresh()
	_button(&"shield").pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_a_cooldown_reported_only_by_the_block_reason_still_counts_as_cooling() -> void:
	_api.fake_ability_block[&"emp"] = Reason.Id.ON_COOLDOWN
	_hud.refresh()
	assert_int(_button(&"emp").state).is_equal(HudAbilityButton.State.COOLING)
	_button(&"emp").pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_buttons_stand_by_when_no_wave_is_running_and_issue_nothing() -> void:
	_api.fake_ability_block[&"emp"] = Reason.Id.WRONG_STATE
	_hud.refresh()
	var b: HudAbilityButton = _button(&"emp")
	assert_int(b.state).is_equal(HudAbilityButton.State.STANDBY)
	assert_str(b.state_label.text).is_equal(Strings.t("hud.ability.standby"))
	b.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_seconds_round_up_and_never_show_zero_while_time_is_left() -> void:
	assert_int(HudStyle.secs(0)).is_equal(0)
	assert_int(HudStyle.secs(1)).is_equal(1)
	assert_int(HudStyle.secs(60)).is_equal(1)
	assert_int(HudStyle.secs(61)).is_equal(2)
	assert_int(HudStyle.secs(2100)).is_equal(35)


func test_state_is_never_color_only_each_state_has_a_different_word() -> void:
	_api.fake_ability_cooldown_left[&"emp"] = 600
	_api.fake_ability_active_left[&"shield"] = 100
	_hud.refresh()
	var words: Dictionary = {}
	for id: StringName in Ids.ABILITIES:
		words[_button(id).state_label.text] = true
	assert_int(words.size()).is_equal(3)  # COOLING, ACTIVE, READY


func test_ability_signals_pulse_and_shake_without_issuing_commands() -> void:
	_api.fake_ability_block[&"emp"] = Reason.Id.OK
	Events.ability_activated.emit(&"emp")
	Events.ability_rejected.emit(&"emp", Reason.Id.ON_COOLDOWN)
	await CombatTestKit.settle(get_tree(), 2)
	assert_int(_api.calls.size()).is_equal(0)
	assert_bool(is_instance_valid(_button(&"emp"))).is_true()
