extends GdUnitTestSuite
## Layout rules of the variety screens at 1080x1920, 1080x2400 and 1080x1120: every control at least 132 px, text at least 30 px,
## no missing string, everything inside the screen and the safe area, every choice control in the lower 60% of a tall screen.

var _api: FakeRunApi


func before_test() -> void:
	ScreensTestKit.fresh_save()


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _screen(state: String, size: Vector2) -> RunOverlayBase:
	_api = VarietyEKit.api_for(state)
	var o: RunOverlayBase = VarietyEKit.overlay(self, state, _api, size)
	await VarietyEKit.settle(get_tree(), 5)
	return o


func _controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for n: Node in VarietyEKit.nodes_of(root, BaseButton):
		var c: Control = n as Control
		if c.is_visible_in_tree():
			out.append(c)
	for n: Node in VarietyEKit.nodes_of(root, RunSelectable):
		var c: Control = n as Control
		if c.is_visible_in_tree():
			out.append(c)
	return out


func _check_size(size: Vector2) -> void:
	for state: String in VarietyEKit.STATES:
		var o: RunOverlayBase = await _screen(state, size)
		var label: String = "%s at %s" % [state, size]
		assert_array(VarietyEKit.small_touch(o)).override_failure_message("small touch: " + label).is_empty()
		assert_array(VarietyEKit.small_text(o)).override_failure_message("small text: " + label).is_empty()
		assert_array(VarietyEKit.bad_texts(o)).override_failure_message("bad text: " + label).is_empty()
		assert_int(_controls(o).size()).is_greater_equal(1)
		for c: Control in _controls(o):
			var r: Rect2 = VarietyEKit.rect(c)
			assert_float(r.position.x).override_failure_message("left edge: %s %s" % [label, c.get_path()]).is_greater_equal(0.0)
			assert_float(r.end.x).override_failure_message("right edge: %s %s" % [label, c.get_path()]).is_less_equal(size.x + 0.5)
			assert_float(r.position.y).override_failure_message("top edge: %s %s" % [label, c.get_path()]).is_greater_equal(0.0)
			assert_float(r.end.y).override_failure_message("bottom edge: %s %s" % [label, c.get_path()]).is_less_equal(size.y + 0.5)


func test_every_screen_has_132_px_controls_and_30_px_text_at_1080x1920() -> void:
	await _check_size(VarietyEKit.SIZES[0])


func test_every_screen_has_132_px_controls_and_30_px_text_at_1080x2400() -> void:
	await _check_size(VarietyEKit.SIZES[1])


func test_every_screen_has_132_px_controls_and_30_px_text_at_1080x1120() -> void:
	await _check_size(VarietyEKit.SIZES[2])


func test_every_choice_control_is_in_the_lower_60_percent_of_a_tall_screen() -> void:
	for size: Vector2 in [VarietyEKit.SIZES[0], VarietyEKit.SIZES[1]]:
		for state: String in VarietyEKit.STATES:
			var o: RunOverlayBase = await _screen(state, size)
			for c: Control in _controls(o):
				var top: float = VarietyEKit.rect(c).position.y
				assert_float(top).override_failure_message("%s at %s: %s starts at %f" % [state, size, c.get_path(), top]).is_greater_equal(size.y * 0.4)


func test_the_overlays_keep_inside_the_safe_area() -> void:
	var safe: Vector4 = Vector4(40.0, 72.0, 40.0, 60.0)
	for state: String in VarietyEKit.STATES:
		_api = VarietyEKit.api_for(state)
		var o: RunOverlayBase = VarietyEKit.overlay(self, state, _api, VarietyEKit.SIZES[0])
		o.set_safe_margins(safe)
		await VarietyEKit.settle(get_tree(), 5)
		var first: Control = o.header.get_child(0) as Control
		assert_float(VarietyEKit.rect(first).position.y).is_greater_equal(safe.y)
		assert_float(VarietyEKit.rect(first).position.x).is_greater_equal(safe.x)
		for c: Control in _controls(o):
			var r: Rect2 = VarietyEKit.rect(c)
			assert_float(r.end.y).override_failure_message("%s %s" % [state, c.get_path()]).is_less_equal(1920.0 - safe.w + 0.5)
			assert_float(r.end.x).is_less_equal(1080.0 - safe.z + 0.5)
			assert_float(r.position.x).is_greater_equal(safe.x - 0.5)


func test_the_four_offer_draft_keeps_132_px_controls_and_30_px_text() -> void:
	_api = VarietyEKit.api_for("draft")
	_api.fake_draft_offer.append(TestContent.variety().directive_index(&"emp_capacitor"))
	_api.fake_draft_ids.append(&"emp_capacitor")
	var o: RunOverlayBase = VarietyEKit.overlay(self, "draft", _api, VarietyEKit.SIZES[0])
	await VarietyEKit.settle(get_tree(), 5)
	assert_array(VarietyEKit.small_touch(o)).is_empty()
	assert_array(VarietyEKit.small_text(o)).is_empty()


func test_a_selection_with_buyouts_open_keeps_132_px_controls() -> void:
	var o: DraftOverlay = await _screen("draft", VarietyEKit.SIZES[0]) as DraftOverlay
	o.cards[1].tap()
	await VarietyEKit.settle(get_tree())
	assert_array(VarietyEKit.small_touch(o)).is_empty()
	assert_array(VarietyEKit.small_text(o)).is_empty()


func test_the_boss_crate_and_the_empty_slot_keep_132_px_controls() -> void:
	_api = VarietyEKit.api_for("salvage")
	_api.fake_salvage_offer = {"weapons": [&"arc_projector", &"rail_lance"], "tiers": [5, 5], "level_up_slot": [0, -1], "boss": true, "scrap_value": 120}
	_api.fake_weapon_slots.append({"id": &"", "level": 0, "magazine": 0, "size": 0, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_EMPTY, "ticks_left": 0})
	var o: RunOverlayBase = VarietyEKit.overlay(self, "salvage", _api, VarietyEKit.SIZES[0])
	await VarietyEKit.settle(get_tree(), 5)
	assert_array(VarietyEKit.small_touch(o)).is_empty()
	assert_array(VarietyEKit.small_text(o)).is_empty()
	assert_array(VarietyEKit.bad_texts(o)).is_empty()


func test_high_contrast_keeps_the_screens_legible() -> void:
	Save.set_setting(&"high_contrast", true)
	for state: String in VarietyEKit.STATES:
		var o: RunOverlayBase = await _screen(state, VarietyEKit.SIZES[0])
		assert_object(o.theme).is_same(UiTheme.shared(true))
		assert_array(VarietyEKit.small_touch(o)).is_empty()
		assert_array(VarietyEKit.small_text(o)).is_empty()


# --- the HUD ---


func _hud_check(size: Vector2) -> void:
	_api = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, _api, size)
	await VarietyEKit.settle(get_tree(), 5)
	assert_array(VarietyEKit.small_touch(hud)).override_failure_message("small touch at %s" % size).is_empty()
	assert_array(VarietyEKit.small_text(hud)).override_failure_message("small text at %s" % size).is_empty()
	assert_array(VarietyEKit.bad_texts(hud)).is_empty()
	var band_top: float = size.y - hud.bottom_band_px()
	var bar: Rect2 = VarietyEKit.rect(hud.bottom.weapon_bar)
	var abilities: Rect2 = VarietyEKit.rect(hud.bottom.abilities)
	assert_float(bar.position.y).is_greater_equal(band_top - 0.5)
	assert_bool(bar.intersects(abilities)).is_false()
	assert_float(abilities.end.y).is_less_equal(size.y + 0.5)
	assert_float(bar.end.x).is_less_equal(size.x + 0.5)


func test_the_variety_hud_has_132_px_controls_and_30_px_text_at_1080x1920() -> void:
	await _hud_check(VarietyEKit.SIZES[0])


func test_the_variety_hud_has_132_px_controls_and_30_px_text_at_1080x2400() -> void:
	await _hud_check(VarietyEKit.SIZES[1])


func test_the_variety_hud_has_132_px_controls_and_30_px_text_at_1080x1120() -> void:
	await _hud_check(VarietyEKit.SIZES[2])


func test_the_variety_hud_with_freight_and_three_weapons_keeps_its_rules() -> void:
	_api = VarietyEKit.api_for("combat2")
	_api.fake_directive_stacks[&"signal_hijack"] = 1
	_api.fake_weapon_slots.append({"id": &"lmg", "level": 1, "magazine": 150, "size": 150, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_READY, "ticks_left": 0})
	var hud: CombatHud = VarietyEKit.hud(self, _api)
	await VarietyEKit.settle(get_tree(), 5)
	assert_int(hud.bottom.weapon_bar.cards.size()).is_equal(3)
	assert_array(VarietyEKit.small_touch(hud)).is_empty()
	assert_array(VarietyEKit.small_text(hud)).is_empty()
	var last: Rect2 = VarietyEKit.rect(hud.bottom.weapon_bar.freight)
	assert_float(last.end.x).is_less_equal(1080.0)
