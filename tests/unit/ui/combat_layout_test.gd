extends GdUnitTestSuite
## Layout rules: touch targets, the two bands, safe-area margins, no overlaps, no missing text.

var _api: FakeRunApi


func before_test() -> void:
	_api = FakeRunApi.new()
	_api.fake_phase = GameState.Id.SPAWNING
	_api.set_scrap(1000)


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


## Opens everything that can be open: the drawer, the intermission panel and a hint.
func _open_everything(hud: CombatHud) -> void:
	_api.fake_phase = GameState.Id.INTERMISSION
	_api.fake_phase_ticks_left = 300
	Events.intermission_started.emit(2, 480)
	Events.hint_requested.emit("hint.intermission")
	hud.refresh()


func _assert_touch_targets(hud: CombatHud) -> void:
	var seen: int = 0
	for b: BaseButton in CombatTestKit.buttons(hud):
		var min_size: Vector2 = b.get_combined_minimum_size()
		assert_float(min_size.x).is_greater_equal(132.0)
		assert_float(min_size.y).is_greater_equal(132.0)
		if b.is_visible_in_tree():
			seen += 1
			assert_float(b.size.x).is_greater_equal(132.0)
			assert_float(b.size.y).is_greater_equal(132.0)
	assert_int(seen).is_greater_equal(11)  # pause, tab, 3 abilities, 5 cards, continue


func test_every_interactive_control_is_at_least_132_by_132() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api)
	_open_everything(hud)
	await CombatTestKit.wait(get_tree(), 0.35)
	_assert_touch_targets(hud)


func test_touch_targets_hold_on_a_near_square_screen() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api, Vector2(1080.0, 1120.0))
	_open_everything(hud)
	await CombatTestKit.wait(get_tree(), 0.35)
	_assert_touch_targets(hud)
	assert_float(hud.top_band_px() + hud.bottom_band_px()).is_less(1120.0)


func test_the_bands_are_11_and_23_percent_of_a_tall_screen() -> void:
	for h: float in [1920.0, 2400.0]:
		var hud: CombatHud = CombatTestKit.make_hud(self, _api, Vector2(1080.0, h))
		assert_float(hud.top_band_px()).is_equal_approx(h * 0.11, 0.01)
		assert_float(hud.bottom_band_px()).is_equal_approx(h * 0.23, 0.01)


func test_the_bands_never_get_too_thin_for_the_touch_rows() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api, Vector2(1080.0, 1120.0))
	assert_float(hud.top_band_px()).is_greater_equal(148.0)
	assert_float(hud.bottom_band_px()).is_greater_equal(300.0)


func test_a_safe_area_inset_moves_the_top_bar_down_by_that_much() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api)
	await CombatTestKit.settle(get_tree())
	var before: float = hud.top_bar.pause_button.global_position.y
	var band_before: float = hud.top_band_px()
	hud.set_safe_margins(Vector4(0.0, 72.0, 0.0, 0.0))
	await CombatTestKit.settle(get_tree())
	assert_float(hud.top_bar.pause_button.global_position.y - before).is_equal_approx(72.0, 0.5)
	assert_float(hud.top_band_px() - band_before).is_equal_approx(72.0, 0.01)


func test_a_bottom_inset_grows_the_bottom_band_and_keeps_the_rows_inside() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api)
	hud.set_safe_margins(Vector4(0.0, 0.0, 0.0, 60.0))
	await CombatTestKit.settle(get_tree())
	var band_top: float = hud.size.y - hud.bottom_band_px()
	var low: Control = hud.bottom.abilities
	assert_float(_rect(low).end.y).is_less_equal(hud.size.y - 60.0 + 0.5)
	assert_float(_rect(hud.bottom.tab_button).position.y).is_greater_equal(band_top)


func test_a_side_inset_pulls_the_content_in() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api)
	hud.set_safe_margins(Vector4(40.0, 0.0, 40.0, 0.0))
	await CombatTestKit.settle(get_tree())
	assert_float(hud.top_bar.pause_button.global_position.x).is_equal_approx(64.0, 0.5)
	assert_float(_rect(hud.bottom.abilities).end.x).is_equal_approx(1080.0 - 64.0, 0.5)


func test_nothing_overlaps_with_everything_open() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api)
	_open_everything(hud)
	await CombatTestKit.wait(get_tree(), 0.35)
	var top_edge: float = hud.top_band_px()
	var bottom_edge: float = hud.size.y - hud.bottom_band_px()
	var stack: Array[Control] = [hud.drawer, hud.intermission]
	for c: Control in stack:
		assert_bool(c.visible).is_true()
		assert_float(_rect(c).position.y).is_greater_equal(top_edge)
		assert_float(_rect(c).end.y).is_less_equal(bottom_edge + 0.5)
	assert_bool(_rect(hud.drawer).intersects(_rect(hud.intermission))).is_false()
	assert_bool(_rect(hud.bottom.tab_button).intersects(_rect(hud.bottom.ammo))).is_false()
	assert_bool(_rect(hud.bottom.tab_button).intersects(_rect(hud.bottom.abilities))).is_false()
	assert_bool(_rect(hud.bottom.ammo).intersects(_rect(hud.bottom.abilities))).is_false()
	var ids: Array[StringName] = [&"emp", &"shield", &"overdrive"]
	for i: int in 2:
		var a: Rect2 = _rect(hud.bottom.abilities.buttons[ids[i]])
		var b: Rect2 = _rect(hud.bottom.abilities.buttons[ids[i + 1]])
		assert_bool(a.intersects(b)).is_false()
	var prev: Rect2 = Rect2()
	for id: StringName in Ids.UPGRADES:
		var r: Rect2 = _rect(hud.drawer.cards[id])
		if prev.size != Vector2.ZERO:
			assert_bool(prev.intersects(r)).is_false()
		assert_float(r.end.x).is_less_equal(1080.0)
		prev = r


func test_the_hud_issues_no_command_by_itself() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api)
	for n: int in 6:
		CombatTestKit.drive(hud, _api, n)
		hud.refresh()
	await CombatTestKit.settle(get_tree())
	assert_int(_api.calls.size()).is_equal(0)


func test_no_label_shows_a_missing_string_key_in_any_state() -> void:
	var hud: CombatHud = CombatTestKit.make_hud(self, _api)
	for n: int in 6:
		CombatTestKit.drive(hud, _api, n)
		hud.refresh()
		for l: Label in CombatTestKit.labels(hud):
			assert_bool(l.text.begins_with("#") and l.text.ends_with("#")).is_false()
	for key: String in ["hud.wave", "hud.tab", "hud.strip", "hint.tap_upgrades", "hint.core_hit", "hint.intermission"]:
		assert_bool(Content.db.strings.has(key)).is_true()
