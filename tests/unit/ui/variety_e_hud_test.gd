extends GdUnitTestSuite
## The variety combat HUD (VARIETY_SPEC 11.4): the weapon bar, the swap tap, the swap hint and the call buttons.

var _api: FakeRunApi
var _hud: CombatHud


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_api = VarietyEKit.api_for("combat2")
	_hud = VarietyEKit.hud(self, _api)


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _bar() -> HudWeaponBar:
	return _hud.bottom.weapon_bar


func test_the_band_is_as_tall_as_its_rows_need_never_past_26_percent_and_holds_the_weapon_bar_instead_of_the_tab() -> void:
	await VarietyEKit.settle(get_tree())
	assert_bool(_hud.variety.active).is_true()
	assert_float(_hud.bottom_band_px()).is_equal_approx(HudBottomPanel.variety_fit_px(), 0.01)  # V4-U: no empty strip above the bar
	assert_float(_hud.bottom_band_px()).is_less_equal(1920.0 * 0.26)
	assert_bool(_hud.bottom.tab_button.visible).is_false()
	assert_bool(_hud.bottom.ammo.visible).is_false()
	assert_bool(_bar().visible).is_true()
	_api.fake_phase = GameState.Id.INTERMISSION
	Events.intermission_started.emit(2, 480)  # no drawer opens (there is none since V5-A): the band stays as it is
	assert_bool(_hud.bottom.tab_button.visible).is_false()
	assert_bool(_bar().visible).is_true()


func test_a_near_square_screen_keeps_both_rows_in_the_band() -> void:
	var hud: CombatHud = VarietyEKit.hud(self, _api, VarietyEKit.SIZES[2])
	assert_float(hud.bottom_band_px()).is_greater_equal(HudBottomPanel.variety_min_px())


func test_the_cards_show_slot_name_level_and_the_feed() -> void:
	await VarietyEKit.settle(get_tree())
	assert_int(_bar().cards.size()).is_equal(2)
	var active: HudWeaponCard = _bar().cards[0]
	var holstered: HudWeaponCard = _bar().cards[1]
	assert_str(active.name_label.text).is_equal("1 %s" % Strings.t("weapon.arc_projector.short"))
	assert_str(active.status_label.text).is_equal(Strings.tf("hud.weapon.heat_pct", [56]))
	assert_bool(active.bar.visible).is_true()
	assert_float(active.bar.fraction).is_equal_approx(0.56, 0.001)
	assert_int(active.marks.level).is_equal(2)
	assert_bool(active.active).is_true()
	assert_str(holstered.name_label.text).is_equal("2 %s" % Strings.t("weapon.smg.short"))
	assert_str(holstered.status_label.text).is_equal(Strings.tf("hud.ammo.mag", [30, 30]))
	assert_bool(holstered.bar.visible).is_false()
	assert_bool(holstered.active).is_false()


func test_the_active_card_is_wider_than_the_holstered_one_and_the_row_fits() -> void:
	await VarietyEKit.settle(get_tree())
	var a: Rect2 = VarietyEKit.rect(_bar().cards[0])
	var h: Rect2 = VarietyEKit.rect(_bar().cards[1])
	assert_float(a.size.x).is_greater(h.size.x)
	assert_float(a.size.x).is_equal_approx(398.0, 6.0)
	assert_float(h.size.x).is_equal_approx(298.0, 6.0)
	assert_float(a.size.y).is_equal_approx(150.0, 0.5)
	assert_float(_bar().strike.size.x).is_equal_approx(150.0, 0.5)
	assert_float(_bar().vent.size.y).is_equal_approx(150.0, 0.5)
	assert_float(VarietyEKit.rect(_bar().vent).end.x).is_less_equal(1080.0 - 24.0 + 1.0)
	assert_bool(a.intersects(h)).is_false()


func test_tapping_the_holstered_card_issues_swap_weapon_and_the_active_card_nothing() -> void:
	_bar().cards[0].pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)
	_bar().cards[1].pressed.emit()
	var swaps: Array[Dictionary] = VarietyEKit.calls_of(_api, "swap_weapon")
	assert_int(swaps.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)
	var slot: int = swaps[0]["arg"]
	var command_id: int = swaps[0]["command_id"]
	assert_int(slot).is_equal(1)
	assert_int(command_id).is_greater(0)
	_hud.refresh()
	assert_bool(_bar().cards[1].active).is_true()  # the fake moved fake_active_slot
	assert_bool(_bar().cards[0].active).is_false()


func test_reloading_and_venting_show_a_word_and_a_moving_bar() -> void:
	_api.fake_weapon_slots[1]["state"] = RunApi.SLOT_RELOADING
	_api.fake_weapon_slots[1]["ticks_left"] = 100
	_hud.refresh()
	var card: HudWeaponCard = _bar().cards[1]
	assert_str(card.status_label.text).is_equal(Strings.t("hud.weapon.reloading"))
	assert_bool(card.bar.visible).is_true()
	assert_float(card.bar.fraction).is_equal_approx(0.0, 0.01)
	_api.fake_weapon_slots[1]["ticks_left"] = 25
	_hud.refresh()
	assert_float(card.bar.fraction).is_equal_approx(0.75, 0.01)
	_api.fake_weapon_slots[0]["state"] = RunApi.SLOT_VENTING
	_api.fake_weapon_slots[0]["ticks_left"] = 150
	_hud.refresh()
	assert_str(_bar().cards[0].status_label.text).is_equal(Strings.t("hud.weapon.venting"))


func test_the_active_card_hints_a_swap_while_it_reloads_and_the_other_is_ready() -> void:
	assert_bool(_bar().cards[0].hinting).is_false()
	_api.fake_weapon_slots[0]["state"] = RunApi.SLOT_VENTING
	_api.fake_weapon_slots[0]["ticks_left"] = 100
	_hud.refresh()
	assert_bool(_bar().cards[0].hinting).is_true()
	assert_bool(_bar().cards[1].hinting).is_false()
	await VarietyEKit.settle(get_tree(), 6)
	assert_float(_bar().cards[0].modulate.a).is_less(1.0)  # the pulse runs
	_api.fake_weapon_slots[1]["state"] = RunApi.SLOT_RELOADING
	_hud.refresh()
	assert_bool(_bar().cards[0].hinting).is_false()  # nothing to swap to


func test_reduced_flash_holds_the_hint_steady() -> void:
	Save.set_setting(&"reduced_flash", true)
	_api.fake_weapon_slots[0]["state"] = RunApi.SLOT_VENTING
	_api.fake_weapon_slots[0]["ticks_left"] = 100
	_hud.refresh()
	assert_bool(_bar().cards[0].hinting).is_true()
	await VarietyEKit.settle(get_tree(), 6)
	assert_float(_bar().cards[0].modulate.a).is_equal(1.0)


func test_strike_shows_its_charges_and_a_tap_issues_call_event() -> void:
	var strike: HudCallButton = _bar().strike
	assert_bool(strike.ready_now).is_true()
	assert_str(strike.value_label.text).is_equal(Strings.tf("hud.call.charges", [2]))
	assert_str(strike.name_label.text).is_equal(Strings.t("hud.call.strike"))
	strike.pressed.emit()
	var calls: Array[Dictionary] = VarietyEKit.calls_of(_api, "call_event")
	assert_int(calls.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)
	var id: StringName = calls[0]["id"]
	assert_str(String(id)).is_equal("deadfall_strike")


func test_a_vent_the_api_would_refuse_is_dim_shows_its_price_and_sends_nothing() -> void:
	var vent: HudCallButton = _bar().vent
	assert_bool(vent.ready_now).is_false()
	assert_str(vent.value_label.text).is_equal(Strings.tf("hud.call.vent_price", [8]))
	vent.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)
	_api.fake_call_block[&"core_vent"] = Reason.Id.OK
	_hud.refresh()
	vent.pressed.emit()
	assert_int(VarietyEKit.calls_of(_api, "call_event").size()).is_equal(1)


func test_freight_appears_with_signal_hijack_and_the_cards_make_room() -> void:
	await VarietyEKit.settle(get_tree())
	assert_bool(_bar().freight.visible).is_false()
	var before: float = _bar().cards[0].size.x
	_api.fake_directive_stacks[&"signal_hijack"] = 1
	_api.fake_event_charges[&"freight_call"] = 1
	_api.fake_call_block[&"freight_call"] = Reason.Id.OK
	_hud.refresh()
	await VarietyEKit.settle(get_tree())
	assert_bool(_bar().freight.visible).is_true()
	assert_float(_bar().cards[0].size.x).is_less(before)
	_bar().freight.pressed.emit()
	var calls: Array[Dictionary] = VarietyEKit.calls_of(_api, "call_event")
	var id: StringName = calls[0]["id"]
	assert_str(String(id)).is_equal("freight_call")
