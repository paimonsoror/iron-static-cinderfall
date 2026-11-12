extends GdUnitTestSuite
## Touch input on the choice panels (VARIETY_SPEC 11.1): a tap selects, a press held for half a second opens the detail and
## swallows the release (so the choice underneath is not selected), a pointer that leaves cancels the press.

var _api: FakeRunApi
var _o: DraftOverlay


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_api = VarietyEKit.api_for("draft")
	_o = VarietyEKit.overlay(self, "draft", _api) as DraftOverlay


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _click(pressed: bool) -> InputEventMouseButton:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e


func test_a_press_and_release_is_a_tap_that_selects_and_sends_nothing() -> void:
	var card: DirectiveCard = _o.cards[1]
	card._gui_input(_click(true))
	assert_int(_o.selected_slot).is_equal(-1)  # nothing happens on the press itself
	card._gui_input(_click(false))
	assert_int(_o.selected_slot).is_equal(1)
	assert_int(_api.calls.size()).is_equal(0)


func test_a_press_held_for_half_a_second_opens_the_detail_and_the_release_selects_nothing() -> void:
	var card: DirectiveCard = _o.cards[2]
	card._gui_input(_click(true))
	await get_tree().create_timer(RunSelectable.LONG_PRESS_SECONDS + 0.25).timeout
	assert_object(_o.modal).is_not_null()
	card._gui_input(_click(false))
	assert_int(_o.selected_slot).is_equal(-1)
	assert_int(_api.calls.size()).is_equal(0)


func test_a_pointer_that_leaves_cancels_the_press() -> void:
	var card: DirectiveCard = _o.cards[0]
	card._gui_input(_click(true))
	card.mouse_exited.emit()
	await get_tree().create_timer(RunSelectable.LONG_PRESS_SECONDS + 0.25).timeout
	assert_object(_o.modal).is_null()
	card._gui_input(_click(false))
	assert_int(_o.selected_slot).is_equal(-1)


func test_an_information_only_panel_shows_its_detail_but_never_selects() -> void:
	var o: SalvageOverlay = VarietyEKit.overlay(self, "salvage", VarietyEKit.api_for("salvage")) as SalvageOverlay
	var panel: SalvageWeaponPanel = o.new_panels[0]
	assert_bool(panel.selectable).is_false()
	panel._gui_input(_click(true))
	panel._gui_input(_click(false))
	assert_bool(panel.selected).is_false()
	panel.long_press()
	assert_object(o.modal).is_not_null()


func test_a_taken_card_ignores_every_press() -> void:
	_api.fake_draft_offer[0] = -1
	Events.draft_offered.emit(_api.fake_draft_ids)
	var card: DirectiveCard = _o.cards[0]
	card._gui_input(_click(true))
	card._gui_input(_click(false))
	card.long_press()
	assert_int(_o.selected_slot).is_equal(-1)
	assert_object(_o.modal).is_null()
