extends GdUnitTestSuite
## V4-U: the V3-I carry-overs. The first-run hints of the draft, the route and the corrupted offer on their own screens; the
## empty band between the battlefield and the weapon bar; the combat HUD ghosting through the overlay header; the weapon list of
## the draft build button; the carried-slot stat line of the salvage card; the boss ANSWER line naming only answers the run has.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = V4uKit.content()


func after_test() -> void:
	ScreensTestKit.fresh_save()
	RunSession.bind(null, null)


# --- hints on the choice screens ---


func test_the_first_draft_shows_its_hint_and_the_corrupted_one_once_per_profile() -> void:
	var overlay: DraftOverlay = VarietyEKit.overlay(self, "draft", VarietyEKit.api_for("draft")) as DraftOverlay  # the preset offers a corrupted card
	await VarietyEKit.settle(get_tree())
	assert_int(overlay.hint_lines.size()).is_equal(2)
	assert_str(overlay.hint_lines[0].label.text).is_equal(Strings.t("hint.draft"))
	assert_str(overlay.hint_lines[1].label.text).is_equal(Strings.t("hint.corrupted"))
	assert_bool(Save.has_seen_hint("hint.draft")).is_true()
	assert_bool(Save.has_seen_hint("hint.corrupted")).is_true()
	var again: DraftOverlay = VarietyEKit.overlay(self, "draft", VarietyEKit.api_for("draft")) as DraftOverlay
	await VarietyEKit.settle(get_tree())
	assert_int(again.hint_lines.size()).is_equal(0)  # once per profile


func test_a_later_draft_with_a_corrupted_offer_still_gets_the_corrupted_hint_alone() -> void:
	Save.mark_hint_seen("hint.draft")
	var overlay: DraftOverlay = VarietyEKit.overlay(self, "draft", VarietyEKit.api_for("draft")) as DraftOverlay
	await VarietyEKit.settle(get_tree())
	assert_int(overlay.hint_lines.size()).is_equal(1)
	assert_str(overlay.hint_lines[0].key).is_equal("hint.corrupted")


func test_a_draft_without_a_corrupted_card_has_no_corrupted_hint() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("draft")
	var ids: Array[StringName] = [&"hot_loads", &"cyclic_tuning", &"penetrator_cores"]
	api.fake_draft_ids = ids
	api.fake_draft_offer = PackedInt32Array([_cs.directive_index(&"hot_loads"), _cs.directive_index(&"cyclic_tuning"), _cs.directive_index(&"penetrator_cores")])
	var overlay: DraftOverlay = VarietyEKit.overlay(self, "draft", api) as DraftOverlay
	await VarietyEKit.settle(get_tree())
	assert_int(overlay.hint_lines.size()).is_equal(1)
	assert_str(overlay.hint_lines[0].key).is_equal("hint.draft")
	assert_bool(Save.has_seen_hint("hint.corrupted")).is_false()


func test_the_route_screen_shows_its_hint_once() -> void:
	var overlay: RouteOverlay = VarietyEKit.overlay(self, "route", VarietyEKit.api_for("route")) as RouteOverlay
	await VarietyEKit.settle(get_tree())
	assert_int(overlay.hint_lines.size()).is_equal(1)
	assert_str(overlay.hint_lines[0].label.text).is_equal(Strings.t("hint.route"))
	var again: RouteOverlay = VarietyEKit.overlay(self, "route", VarietyEKit.api_for("route")) as RouteOverlay
	await VarietyEKit.settle(get_tree())
	assert_int(again.hint_lines.size()).is_equal(0)


func test_a_hint_sits_in_the_information_band_in_view_and_is_one_readable_line() -> void:
	for view: Vector2 in VarietyEKit.SIZES:
		Save.profile.hints_seen = PackedStringArray()
		var overlay: DraftOverlay = VarietyEKit.overlay(self, "draft", VarietyEKit.api_for("draft"), view) as DraftOverlay
		await VarietyEKit.settle(get_tree())
		var compact: bool = view.y < RunOverlayBase.COMPACT_HEIGHT
		assert_int(overlay.hint_lines.size()).is_equal(2)
		for line: RunHintLine in overlay.hint_lines:
			if compact and line != overlay.hint_lines[0]:
				assert_bool(line.visible).is_false()  # a near-square window shows one hint at a time
				assert_bool(Save.has_seen_hint(line.key)).is_false()  # and the one it did not show waits for a later screen
				continue
			assert_bool(line.is_visible_in_tree()).is_true()
			assert_int(line.label.get_theme_font_size(&"font_size")).is_greater_equal(30)
			assert_int(line.label.get_line_count()).is_equal(1)
			assert_float(line.global_position.y + line.size.y).override_failure_message("%s at %s" % [line.key, view]).is_less(view.y * 0.5)
			assert_float(line.global_position.x + line.size.x).is_less_equal(view.x + 0.5)
		assert_bool(overlay.confirm_button.is_visible_in_tree()).is_true()
		assert_float(overlay.confirm_button.global_position.y + overlay.confirm_button.size.y).is_less_equal(view.y + 0.5)


func test_a_hint_without_text_or_already_seen_is_not_due() -> void:
	assert_bool(RunHintLine.due("hint.draft")).is_true()
	assert_bool(RunHintLine.due("hint.not_a_key")).is_false()
	Save.mark_hint_seen("hint.draft")
	assert_bool(RunHintLine.due("hint.draft")).is_false()


# --- the combat HUD does not ghost through the overlay ---


func test_the_dimming_layer_is_opaque_over_the_hud_bands_and_lighter_over_the_battlefield() -> void:
	for state: String in VarietyEKit.STATES:
		var overlay: RunOverlayBase = VarietyEKit.overlay(self, state, VarietyEKit.api_for(state))
		var tex: GradientTexture2D = overlay._scrim.texture
		for at: float in [0.0, 0.05, 0.12, 0.6, 0.8, 1.0]:
			assert_float(tex.gradient.sample(at).a).override_failure_message("%s scrim at %f" % [state, at]).is_equal(1.0)
		assert_float(tex.gradient.sample(0.38).a).is_less(0.9)  # the frozen battlefield still shows in the middle


# --- the empty band above the weapon bar ---


func test_the_weapon_row_starts_within_a_pad_of_the_top_of_its_band_on_every_height() -> void:
	for view: Vector2 in [VarietyEKit.SIZES[0], VarietyEKit.SIZES[1], VarietyEKit.SIZES[2], V4uKit.NARROW]:
		var hud: CombatHud = VarietyEKit.hud(self, VarietyEKit.api_for("combat2"), view)
		await VarietyEKit.settle(get_tree())
		var band_top: float = view.y - hud.bottom_band_px()
		var bar_top: float = hud.bottom.weapon_bar.global_position.y
		assert_float(bar_top - band_top).override_failure_message("empty strip of %f px at %s" % [bar_top - band_top, view]).is_less_equal(HudStyle.GAP * 2.0 + 1.0)
		var below: float = view.y - (hud.bottom.abilities.global_position.y + hud.bottom.abilities.size.y)
		assert_float(below).is_less_equal(HudStyle.GAP * 2.0 + 1.0)
		assert_float(hud.bottom_band_px()).is_less_equal(view.y * 0.26 + 0.01 if view.y > 1500.0 else 600.0)
	var tall: CombatHud = VarietyEKit.hud(self, VarietyEKit.api_for("combat2"), VarietyEKit.SIZES[1])
	assert_float(tall.bottom_band_px()).is_equal_approx(HudBottomPanel.variety_fit_px(), 0.01)  # not the 624 px of 26% of 2400


func test_the_legacy_hud_keeps_its_band() -> void:
	var legacy: CombatHud = CombatHud.new()
	V4uKit.host(self, Vector2(1080.0, 1920.0)).add_child(legacy)
	legacy.setup(FakeRunApi.new(), TestContent.baseline(), null)
	assert_float(legacy.bottom_band_px()).is_equal_approx(1920.0 * 0.23, 0.01)


# --- the weapon list of the build button ---


func test_the_build_button_lists_every_weapon_carried_in_full() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("draft")
	api.fake_weapon_slots = [
		{"id": &"pistol", "level": 1, "magazine": 12, "size": 12, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_READY, "ticks_left": 0},
		{"id": &"arc_projector", "level": 2, "magazine": 0, "size": 0, "heat": 0, "heat_cap": 100, "state": RunApi.SLOT_READY, "ticks_left": 0},
		{"id": &"scattergun", "level": 1, "magazine": 6, "size": 6, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_READY, "ticks_left": 0},
	]
	api.fake_build_tags = {&"arc": 4, &"tempo": 2, &"bullet": 2, &"blast": 1}
	var overlay: DraftOverlay = VarietyEKit.overlay(self, "draft", api) as DraftOverlay
	await VarietyEKit.settle(get_tree())
	var button: DraftBuildButton = overlay.build_button
	assert_str(button.weapons_label.text).is_equal("%s PISTOL  ARC PROJ.  SCATTER" % Strings.t("draft.weapons"))
	assert_bool(button.weapons_label.text.contains("...")).is_false()
	assert_int(button.weapons_label.get_line_count()).is_equal(1)
	assert_int(button.chips.size()).is_equal(DraftBuildButton.MAX_CHIPS)
	assert_float(button.size.y).is_greater_equal(132.0)
	assert_float(button.weapons_label.global_position.y + button.weapons_label.size.y).is_less_equal(button.global_position.y + button.size.y + 1.0)
	var font: Font = button.weapons_label.get_theme_font(&"font")
	var wanted: float = font.get_string_size(button.weapons_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button.weapons_label.get_theme_font_size(&"font_size")).x
	assert_float(wanted).is_less_equal(button.weapons_label.size.x + 1.0)  # nothing is cut


func test_the_compact_draft_line_wraps_instead_of_trimming() -> void:
	Save.mark_hint_seen("hint.draft")  # a first-run hint takes the build line's room on a near-square window (next test)
	Save.mark_hint_seen("hint.corrupted")
	var overlay: DraftOverlay = VarietyEKit.overlay(self, "draft", VarietyEKit.api_for("draft"), VarietyEKit.SIZES[2]) as DraftOverlay
	await VarietyEKit.settle(get_tree())
	assert_bool(overlay.build_info.visible).is_true()
	assert_bool(overlay.build_button.visible).is_false()
	assert_int(overlay.build_info.autowrap_mode).is_not_equal(TextServer.AUTOWRAP_OFF)
	assert_str(overlay.build_info.text).contains("ARC PROJ.")


func test_a_near_square_draft_gives_the_build_lines_room_to_the_first_hint_only() -> void:
	var overlay: DraftOverlay = VarietyEKit.overlay(self, "draft", VarietyEKit.api_for("draft"), VarietyEKit.SIZES[2]) as DraftOverlay
	await VarietyEKit.settle(get_tree())
	assert_int(overlay.hint_lines.size()).is_equal(2)
	assert_bool(overlay.hint_lines[0].visible).is_true()
	assert_bool(overlay.hint_lines[1].visible).is_false()
	assert_bool(overlay.build_info.visible).is_false()
	assert_float(overlay.confirm_button.global_position.y + overlay.confirm_button.size.y).is_less_equal(VarietyEKit.SIZES[2].y + 0.5)


# --- the salvage card ---


func test_a_carried_slot_shows_damage_and_rate_on_one_line() -> void:
	var overlay: SalvageOverlay = VarietyEKit.overlay(self, "salvage", VarietyEKit.api_for("salvage"), VarietyEKit.SIZES[1]) as SalvageOverlay
	await VarietyEKit.settle(get_tree())
	var pistol_panel: SalvageWeaponPanel = null
	for panel: SalvageWeaponPanel in overlay.slot_panels:
		if panel.weapon_id == &"pistol":
			pistol_panel = panel
	assert_object(pistol_panel).is_not_null()
	var def: WeaponDef = overlay._content.weapon(&"pistol")
	assert_str(pistol_panel.stats_label.text).is_equal(WeaponStats.brief(def, 1))
	assert_str(pistol_panel.stats_label.text).contains("DMG")
	assert_str(pistol_panel.stats_label.text).not_contains("RELOAD")
	assert_int(pistol_panel.stats_label.get_line_count()).is_equal(1)
	assert_str(WeaponStats.line(def, 1)).contains("RELOAD")  # the full line is still there for the long-press detail


# --- the boss ANSWER line ---


func _hulk() -> Dictionary:
	return {"id": &"siege_hulk", "name_key": "boss.siege_hulk.name", "variant": &"", "answer_key": "boss.siege_hulk.answer", "attack_key": "boss.siege_hulk.attack"}


func test_the_approved_answer_stays_while_its_weapon_is_not_gated_by_the_archive() -> void:
	var slice: ContentSet = TestContent.variety()  # the slice: the Arc Projector is in the crate pool of every run
	assert_str(BossBriefLines.line(_hulk(), "answer", slice)).is_equal(Strings.t("boss.siege_hulk.answer"))
	assert_str(BossBriefLines.line(_hulk(), "answer", slice)).contains("Arc Projector")


func test_an_answer_naming_a_weapon_the_run_cannot_have_gives_way_to_its_open_variant() -> void:
	assert_str(BossBriefLines.line(_hulk(), "answer", _cs)).is_equal(Strings.t("boss.siege_hulk.answer.open"))  # u_w_arc is not owned
	assert_str(Strings.t("boss.siege_hulk.answer.open")).not_contains("Arc Projector")
	Save.profile.unlocks.append("u_w_arc")
	assert_str(BossBriefLines.line(_hulk(), "answer", _cs)).is_equal(Strings.t("boss.siege_hulk.answer"))  # bought: the approved line


func test_the_plated_variant_needs_both_of_its_weapons_to_keep_the_approved_line() -> void:
	var brief: Dictionary = {"id": &"siege_hulk", "variant": &"hulk_plated", "answer_key": "boss.siege_hulk.answer"}
	assert_str(BossBriefLines.line(brief, "answer", _cs)).is_equal(Strings.t("boss.hulk_plated.answer.open"))
	Save.profile.unlocks.append("u_w_rail")
	assert_str(BossBriefLines.line(brief, "answer", _cs)).is_equal(Strings.t("boss.hulk_plated.answer.open"))  # the torch is still missing
	Save.profile.unlocks.append("u_w_torch")
	assert_str(BossBriefLines.line(brief, "answer", _cs)).is_equal(Strings.t("boss.hulk_plated.answer"))


func test_lines_without_a_weapon_and_the_attack_line_are_never_replaced() -> void:
	var lance: Dictionary = {"id": &"lance_platform", "variant": &"", "answer_key": "boss.lance_platform.answer"}
	assert_str(BossBriefLines.line(lance, "answer", _cs)).is_equal(Strings.t("boss.lance_platform.answer"))
	assert_str(BossBriefLines.line(_hulk(), "attack", _cs)).is_equal(Strings.t("boss.siege_hulk.attack"))
	assert_str(BossBriefLines.line({"id": &"no_such_boss"}, "answer", _cs)).is_equal("")


func test_the_boss_briefing_shows_the_line_the_run_can_use() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("boss_brief")
	api.fake_boss_brief = _hulk()
	var node: BossBriefOverlay = (load(VarietyEKit.BOSS) as PackedScene).instantiate() as BossBriefOverlay
	VarietyEKit.host(self, VarietyEKit.SIZES[1]).add_child(node)
	node.setup(api, _cs)
	assert_str(node.answer_label.text).is_equal(Strings.t("boss.siege_hulk.answer.open"))
