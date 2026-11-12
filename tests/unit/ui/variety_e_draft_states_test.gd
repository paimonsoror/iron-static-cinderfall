extends GdUnitTestSuite
## The draft screen's states (VARIETY_SPEC 11.1): a taken slot, four offers, a new offer, a refused command, High Contrast.

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


func test_a_taken_slot_is_dimmed_and_cannot_be_selected() -> void:
	_api.fake_draft_offer[0] = -1
	Events.draft_offered.emit(_api.fake_draft_ids)
	assert_bool(_o.cards[0].enabled).is_false()
	_o.cards[0].tap()
	assert_int(_o.selected_slot).is_equal(-1)
	assert_str(_o.cards[0].name_label.text).is_equal(Strings.t("draft.kept"))


func test_four_offers_make_narrow_cards_and_the_text_stays_at_least_30_px() -> void:
	var extra: int = TestContent.variety().directive_index(&"emp_capacitor")
	_api.fake_draft_offer.append(extra)
	_api.fake_draft_ids.append(&"emp_capacitor")
	Events.draft_offered.emit(_api.fake_draft_ids)
	await VarietyEKit.settle(get_tree())
	assert_int(_o.cards.size()).is_equal(4)
	for card: DirectiveCard in _o.cards:
		assert_float(card.size.x).is_less(270.0)
	assert_array(VarietyEKit.small_text(_o)).is_empty()


func test_a_new_offer_rebuilds_the_cards_and_clears_the_selection() -> void:
	_o.cards[0].tap()
	_api.fake_draft_ids = [&"hot_loads", &"cyclic_tuning", &"penetrator_cores"]
	var index: PackedInt32Array = PackedInt32Array()
	for id: StringName in _api.fake_draft_ids:
		index.append(TestContent.variety().directive_index(id))
	_api.fake_draft_offer = index
	Events.draft_offered.emit(_api.fake_draft_ids)
	assert_int(_o.selected_slot).is_equal(-1)
	assert_str(String(_o.cards[1].def.id)).is_equal("cyclic_tuning")
	assert_bool(_o.confirm_button.disabled).is_true()


func test_a_refused_command_shows_its_reason_in_the_notice_line() -> void:
	_api.fake_paused = true
	_api.fake_variety_paused = true
	_o.cards[1].tap()
	_o.confirm_button.pressed.emit()
	assert_object(_o.notice_label).is_not_null()
	assert_bool(_o.notice_label.visible).is_true()
	assert_str(_o.notice_label.text).is_equal(Strings.t("reason.paused"))


func test_high_contrast_thickens_the_rims_and_switches_the_theme() -> void:
	var normal_w: int = _border(_o.cards[1])
	assert_int(normal_w).is_equal(UiTheme.rim_width(false))
	Save.set_setting(&"high_contrast", true)
	assert_object(_o.theme).is_same(UiTheme.shared(true))
	assert_int(_border(_o.cards[1])).is_equal(UiTheme.rim_width(true))
	assert_int(_border(_o.cards[1])).is_greater(normal_w)
	assert_bool(_o.cards[0].rim_color.is_equal_approx(UiTheme.rim(&"warden_cyan", true))).is_true()
	assert_bool(_o.cards[1].name_label.get_theme_color(&"font_color").is_equal_approx(UiTheme.text_color(&"body", true))).is_true()
	assert_array(VarietyEKit.small_text(_o)).is_empty()


func _border(card: DirectiveCard) -> int:
	var sb: StyleBoxFlat = card.get_theme_stylebox(&"panel") as StyleBoxFlat
	return sb.border_width_left
