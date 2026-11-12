extends GdUnitTestSuite
## The draft screen (VARIETY_SPEC 11.1): the three cards, the two-tap rule, the five commands and their arguments, the staged
## buy-out, the corrupted price line, the long-press detail, the build list, High Contrast.

var _api: FakeRunApi
var _o: DraftOverlay


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_api = VarietyEKit.api_for("draft")
	_o = VarietyEKit.overlay(self, "draft", _api) as DraftOverlay


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _name(slot: int) -> String:
	return Strings.t(_o.cards[slot].def.name_key)


func test_three_cards_show_the_offer_with_rarity_name_and_stack_counter() -> void:
	assert_int(_o.cards.size()).is_equal(3)
	var want: Array[String] = ["incendiary_tips", "hot_loads", "glass_cannon"]
	var rarity: Array[String] = ["rare", "common", "corrupted"]
	for i: int in 3:
		assert_str(String(_o.cards[i].def.id)).is_equal(want[i])
		assert_str(_o.cards[i].name_label.text).is_equal(Strings.t("directive.%s.name" % want[i]))
		assert_str(_o.cards[i].rarity_label.text).is_equal(Strings.t("directive.rarity.%s" % rarity[i]))
		assert_str(_o.cards[i].desc_label.text).is_equal(Strings.t("directive.%s.desc" % want[i]))
	assert_str(_o.cards[1].stack_label.text).is_equal(Strings.tf("directive.stacks", [2, 3, 5]))
	assert_str(_o.cards[0].stack_label.text).is_equal(Strings.tf("directive.stacks", [0, 1, 3]))
	assert_str(_o.cards[2].stack_label.text).is_equal(Strings.t("directive.new"))
	assert_str(_o.cards[1].tag_labels[0].text).is_equal(Strings.t("tag.bullet"))


func test_a_tap_selects_a_card_and_sends_nothing() -> void:
	assert_bool(_o.confirm_button.disabled).is_true()
	assert_str(_o.confirm_button.text).is_equal(Strings.t("draft.confirm_none"))
	_o.cards[1].tap()
	assert_int(_o.selected_slot).is_equal(1)
	assert_bool(_o.cards[1].selected).is_true()
	assert_bool(_o.cards[0].selected).is_false()
	assert_bool(_o.confirm_button.disabled).is_false()
	assert_str(_o.confirm_button.text).is_equal(Strings.tf("draft.confirm", [_name(1)]))
	assert_int(_api.calls.size()).is_equal(0)


func test_confirm_without_a_selection_sends_nothing() -> void:
	_o.confirm_button.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_confirm_sends_pick_directive_for_the_selected_slot() -> void:
	_o.cards[2].tap()
	_o.confirm_button.pressed.emit()
	var picks: Array[Dictionary] = VarietyEKit.calls_of(_api, "pick_directive")
	assert_int(picks.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)
	var slot: int = picks[0]["arg"]
	var id: StringName = picks[0]["id"]
	var command_id: int = picks[0]["command_id"]
	assert_int(slot).is_equal(2)
	assert_str(String(id)).is_equal("glass_cannon")
	assert_int(command_id).is_greater(0)


func test_skip_is_a_selection_and_confirm_sends_skip_draft() -> void:
	_o.skip_button.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)
	assert_int(_o.selected_slot).is_equal(DraftOverlay.SKIP)
	assert_str(_o.confirm_button.text).is_equal(Strings.tf("draft.confirm", [Strings.tf("draft.skip", [60])]))
	_o.confirm_button.pressed.emit()
	assert_int(VarietyEKit.calls_of(_api, "skip_draft").size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)


func test_reroll_and_patch_send_their_commands_with_fresh_ids() -> void:
	assert_str(_o.reroll_button.text).is_equal(Strings.tf("draft.reroll", [60]))
	assert_str(_o.patch_button.text).is_equal(Strings.tf("draft.patch", [10, 180]))
	assert_str(_o.skip_button.text).is_equal(Strings.tf("draft.skip", [60]))
	_o.reroll_button.pressed.emit()
	_o.patch_button.pressed.emit()
	var rerolls: Array[Dictionary] = VarietyEKit.calls_of(_api, "reroll_draft")
	var patches: Array[Dictionary] = VarietyEKit.calls_of(_api, "patch_core")
	assert_int(rerolls.size()).is_equal(1)
	assert_int(patches.size()).is_equal(1)
	var first: int = rerolls[0]["command_id"]
	var second: int = patches[0]["command_id"]
	assert_int(second).is_not_equal(first)


func test_a_free_reroll_shows_free_and_sends_even_with_no_scrap() -> void:
	_api.fake_free_rerolls = 1
	_api.set_scrap(0)
	_o.refresh()
	assert_str(_o.reroll_button.text).is_equal(Strings.t("draft.reroll_free"))
	_o.reroll_button.pressed.emit()
	assert_int(VarietyEKit.calls_of(_api, "reroll_draft").size()).is_equal(1)


func test_a_reroll_or_patch_the_player_cannot_afford_sends_nothing() -> void:
	_api.set_scrap(10)
	_o.reroll_button.pressed.emit()
	_o.patch_button.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_buyout_buttons_appear_only_after_a_selection_and_only_on_the_other_cards() -> void:
	for card: DirectiveCard in _o.cards:
		assert_bool(card.buyout_button.visible).is_false()
	_o.cards[1].tap()
	assert_bool(_o.cards[0].buyout_button.visible).is_true()
	assert_bool(_o.cards[1].buyout_button.visible).is_false()
	assert_bool(_o.cards[2].buyout_button.visible).is_true()
	assert_str(_o.cards[2].buyout_button.text).is_equal(Strings.tf("draft.buyout", [250]))


func test_a_staged_buyout_is_sent_before_the_pick_when_confirmed() -> void:
	_o.cards[1].tap()
	_o.cards[2].buyout_button.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)
	assert_int(_o.buyout_slot).is_equal(2)
	assert_str(_o.confirm_button.text).is_equal(Strings.tf("draft.confirm_both", [_name(1), _name(2)]))
	_o.confirm_button.pressed.emit()
	assert_int(_api.calls.size()).is_equal(2)
	var first: Dictionary = _api.calls[0]
	var second: Dictionary = _api.calls[1]
	var first_cmd: String = first["cmd"]
	var second_cmd: String = second["cmd"]
	var first_arg: int = first["arg"]
	var second_arg: int = second["arg"]
	var first_id: int = first["command_id"]
	var second_id: int = second["command_id"]
	assert_str(first_cmd).is_equal("buy_out")
	assert_int(first_arg).is_equal(2)
	assert_str(second_cmd).is_equal("pick_directive")
	assert_int(second_arg).is_equal(1)
	assert_int(second_id).is_not_equal(first_id)


func test_selecting_the_staged_buyout_card_drops_the_buyout() -> void:
	_o.cards[1].tap()
	_o.cards[2].buyout_button.pressed.emit()
	_o.cards[2].tap()
	assert_int(_o.buyout_slot).is_equal(-1)
	assert_int(_o.selected_slot).is_equal(2)


func test_a_corrupted_card_prints_its_price_as_large_as_its_gain_on_a_red_frame() -> void:
	var card: DirectiveCard = _o.cards[2]
	assert_object(card.price_label).is_not_null()
	assert_str(card.price_label.text).is_equal(Strings.t("directive.glass_cannon.price"))
	assert_int(card.price_label.get_theme_font_size(&"font_size")).is_greater_equal(card.desc_label.get_theme_font_size(&"font_size"))
	assert_int(card.price_label.get_theme_font_size(&"font_size")).is_greater_equal(34)
	assert_bool(card.rim_color.is_equal_approx(RunUi.rarity_rim(DirectiveDef.Rarity.CORRUPTED))).is_true()
	assert_bool(_o.corrupted_label.visible).is_true()
	assert_str(_o.corrupted_label.text).is_equal(Strings.t("draft.corrupted.tag"))
	assert_object(_o.cards[0].price_label).is_null()
	assert_object(_o.cards[1].price_label).is_null()


func test_every_corrupted_directive_of_the_content_has_a_price_string() -> void:
	var seen: int = 0
	for def: DirectiveDef in TestContent.variety().directives:
		if def.rarity == DirectiveDef.Rarity.CORRUPTED:
			seen += 1
			assert_bool(RunUi.has_key("directive.%s.price" % String(def.id))).is_true()
	assert_int(seen).is_greater(0)
	for id: String in ["glass_cannon", "open_gate", "overclocked_core", "chorus_handshake", "unstable_munitions", "borrowed_time", "static_pact", "single_point", "the_tally"]:
		assert_bool(RunUi.has_key("directive.%s.price" % id)).is_true()


func test_a_long_press_shows_the_rules_and_what_it_works_with_and_commits_nothing() -> void:
	_o.cards[0].long_press()
	var panel: RunDetailPanel = _o.modal as RunDetailPanel
	assert_object(panel).is_not_null()
	assert_str(panel.title_label.text).is_equal(_name(0))
	assert_str(panel.body_label.text).is_equal(Strings.t("directive.incendiary_tips.desc"))
	assert_int(panel.extra_labels.size()).is_equal(1)
	assert_str(panel.extra_labels[0].text).is_equal(Strings.tf("directive.works_with", ["SMG, %s" % Strings.t("directive.hot_loads.name")]))
	assert_int(_api.calls.size()).is_equal(0)
	assert_int(_o.selected_slot).is_equal(-1)
	panel.close_button.pressed.emit()
	assert_object(_o.modal).is_null()


func test_a_corrupted_long_press_repeats_the_price() -> void:
	_o.cards[2].long_press()
	var panel: RunDetailPanel = _o.modal as RunDetailPanel
	assert_str(panel.extra_labels[0].text).contains(Strings.t("directive.glass_cannon.price"))


func test_the_build_button_opens_the_build_list_of_directives_and_weapons_held() -> void:
	_o.build_button.pressed.emit()
	var list: BuildList = _o.modal as BuildList
	assert_object(list).is_not_null()
	assert_int(list.weapon_rows.size()).is_equal(2)
	assert_int(list.directive_rows.size()).is_equal(2)
	assert_str(list.directive_rows[0].text).is_equal(Strings.t("directive.hot_loads.name"))
	list.close_button.pressed.emit()
	assert_object(_o.modal).is_null()
	assert_int(_api.calls.size()).is_equal(0)
