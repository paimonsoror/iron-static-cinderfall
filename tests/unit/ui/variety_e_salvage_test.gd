extends GdUnitTestSuite
## The salvage screen (VARIETY_SPEC 11.3): the recovered weapon against the carried ones, REPLACE / TAKE / LEVEL UP / SCRAP IT,
## the boss crate with two weapons, the two-tap rule and the command arguments (the fake records choice * 16 + action).

var _api: FakeRunApi
var _o: SalvageOverlay


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_api = VarietyEKit.api_for("salvage")
	_o = VarietyEKit.overlay(self, "salvage", _api) as SalvageOverlay


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _arg(call: Dictionary) -> int:
	var arg: int = call["arg"]
	return arg


func _open(offer: Dictionary, slots: Array[Dictionary] = []) -> SalvageOverlay:
	var api: FakeRunApi = VarietyEKit.api_for("salvage")
	api.fake_salvage_offer = offer
	if not slots.is_empty():
		api.fake_weapon_slots = slots
	_api = api
	return VarietyEKit.overlay(self, "salvage", api) as SalvageOverlay


func test_the_recovered_weapon_shows_tier_name_new_rules_and_stats() -> void:
	var def: WeaponDef = TestContent.variety().weapon(&"arc_projector")
	assert_int(_o.new_panels.size()).is_equal(1)
	var p: SalvageWeaponPanel = _o.new_panels[0]
	assert_str(p.tier_label.text).is_equal(Strings.tf("salvage.tier", [5]))
	assert_str(p.name_label.text).is_equal(Strings.t("weapon.arc_projector.name").to_upper())
	assert_str(p.new_label.text).is_equal(Strings.t("salvage.new"))
	assert_str(p.desc_label.text).is_equal(Strings.t("weapon.arc_projector.desc"))
	assert_str(p.stats_label.text).is_equal(WeaponStats.line(def, 1))
	assert_str(_o.title_label.text).is_equal(Strings.t("salvage.header"))


func test_the_carried_weapons_show_slot_name_level_and_a_replace_plate() -> void:
	assert_int(_o.slot_panels.size()).is_equal(2)
	assert_str(_o.slot_panels[0].slot_label.text).is_equal("1")
	assert_str(_o.slot_panels[0].name_label.text).is_equal(Strings.t("weapon.smg.short"))
	assert_str(_o.slot_panels[0].level_label.text).is_equal(Strings.tf("salvage.level", [2]))
	assert_str(_o.slot_panels[1].slot_label.text).is_equal("2")
	assert_str(_o.slot_panels[1].name_label.text).is_equal(Strings.t("weapon.pistol.short"))
	assert_str(_o.slot_panels[1].plate_label.text).is_equal(Strings.t("salvage.replace"))
	assert_str(_o.scrap_panel.name_label.text).is_equal(Strings.tf("salvage.scrap_it", [80]))


func test_selecting_sends_nothing_and_confirm_starts_disabled() -> void:
	assert_bool(_o.confirm_button.disabled).is_true()
	_o.slot_panels[1].tap()
	assert_int(_o.action).is_equal(1)
	assert_bool(_o.slot_panels[1].selected).is_true()
	assert_bool(_o.confirm_button.disabled).is_false()
	assert_int(_api.calls.size()).is_equal(0)


func test_replace_names_the_weapon_and_sends_the_slot() -> void:
	_o.slot_panels[1].tap()
	assert_str(_o.confirm_button.text).is_equal(Strings.tf("salvage.confirm_replace", [Strings.t("weapon.pistol.name").to_upper()]))
	_o.confirm_button.pressed.emit()
	var calls: Array[Dictionary] = VarietyEKit.calls_of(_api, "resolve_salvage")
	assert_int(calls.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)
	assert_int(_arg(calls[0])).is_equal(0 * 16 + 1)


func test_scrap_it_sends_the_scrap_action() -> void:
	_o.scrap_panel.tap()
	assert_str(_o.confirm_button.text).is_equal(Strings.t("salvage.confirm_scrap"))
	_o.confirm_button.pressed.emit()
	var calls: Array[Dictionary] = VarietyEKit.calls_of(_api, "resolve_salvage")
	assert_int(_arg(calls[0])).is_equal(0 * 16 + RunApi.SALVAGE_SCRAP)


func test_a_duplicate_offers_level_up_as_the_highlighted_default() -> void:
	var o: SalvageOverlay = _open({"weapons": [&"smg"], "tiers": [2], "level_up_slot": [0], "boss": false, "scrap_value": 60})
	assert_bool(o.level_panel.visible).is_true()
	assert_bool(o.level_panel.selected).is_true()
	assert_str(o.level_panel.name_label.text).is_equal(Strings.tf("salvage.level_up", ["SMG", 2, 3]))
	assert_str(o.confirm_button.text).is_equal(Strings.t("salvage.confirm_level"))
	assert_bool(o.confirm_button.disabled).is_false()
	o.confirm_button.pressed.emit()
	assert_int(_arg(VarietyEKit.calls_of(_api, "resolve_salvage")[0])).is_equal(RunApi.SALVAGE_LEVEL_UP)


func test_no_level_up_row_without_a_duplicate() -> void:
	assert_bool(_o.level_panel.visible).is_false()


func test_a_boss_crate_shows_two_weapons_and_needs_one_chosen_before_anything_else() -> void:
	var o: SalvageOverlay = _open({"weapons": [&"arc_projector", &"rail_lance"], "tiers": [5, 5], "level_up_slot": [-1, -1], "boss": true, "scrap_value": 120})
	assert_int(o.new_panels.size()).is_equal(2)
	assert_bool(o.new_panels[0].selectable).is_true()
	assert_bool(o.confirm_button.disabled).is_true()
	o.slot_panels[0].tap()  # a slot before a weapon is chosen does nothing
	assert_int(o.action).is_equal(-1)
	o.new_panels[1].tap()
	assert_int(o.choice).is_equal(1)
	assert_bool(o.new_panels[1].selected).is_true()
	assert_int(_api.calls.size()).is_equal(0)
	o.slot_panels[0].tap()
	assert_str(o.confirm_button.text).is_equal(Strings.tf("salvage.confirm_replace", ["SMG"]))
	o.confirm_button.pressed.emit()
	assert_int(_arg(VarietyEKit.calls_of(_api, "resolve_salvage")[0])).is_equal(1 * 16 + 0)


func test_an_empty_carried_slot_says_take_and_sends_its_index() -> void:
	var slots: Array[Dictionary] = [
		{"id": &"smg", "level": 1, "magazine": 30, "size": 30, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_READY, "ticks_left": 0},
		{"id": &"pistol", "level": 1, "magazine": 12, "size": 12, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_READY, "ticks_left": 0},
		{"id": &"", "level": 0, "magazine": 0, "size": 0, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_EMPTY, "ticks_left": 0},
	]
	var o: SalvageOverlay = _open({"weapons": [&"arc_projector"], "tiers": [5], "level_up_slot": [-1], "boss": false, "scrap_value": 80}, slots)
	assert_int(o.slot_panels.size()).is_equal(3)
	assert_str(o.slot_panels[2].plate_label.text).is_equal(Strings.t("salvage.take"))
	assert_str(o.slot_panels[2].name_label.text).is_equal(Strings.t("salvage.empty"))
	o.slot_panels[2].tap()
	assert_str(o.confirm_button.text).is_equal(Strings.tf("salvage.confirm_take", [3]))
	o.confirm_button.pressed.emit()
	assert_int(_arg(VarietyEKit.calls_of(_api, "resolve_salvage")[0])).is_equal(2)


func test_a_long_press_shows_the_weapon_rules_and_stats_and_commits_nothing() -> void:
	_o.new_panels[0].long_press()
	var panel: RunDetailPanel = _o.modal as RunDetailPanel
	assert_object(panel).is_not_null()
	assert_str(panel.body_label.text).is_equal(Strings.t("weapon.arc_projector.desc"))
	assert_int(panel.extra_labels.size()).is_greater(2)
	assert_int(_api.calls.size()).is_equal(0)


func test_the_weapon_stat_words_come_from_the_weapon_data() -> void:
	var content: ContentSet = TestContent.variety()
	var mortar: WeaponDef = content.weapon(&"slag_mortar")
	var parts: PackedStringArray = WeaponStats.parts(mortar, 1)
	assert_str(parts[0]).is_equal(Strings.tf("weapon.stat.dmg", [roundi(mortar.damage)]))
	assert_bool(WeaponStats.line(mortar, 1).contains("m")).is_true()
	var arc: WeaponDef = content.weapon(&"arc_projector")
	assert_bool(WeaponStats.parts(arc, 1).has(Strings.t("weapon.stat.heat"))).is_true()
	assert_int(WeaponStats.damage(arc, 3)).is_greater(WeaponStats.damage(arc, 1))
