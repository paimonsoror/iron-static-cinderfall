extends GdUnitTestSuite
## The route screen (VARIETY_SPEC 11.2) and the boss briefing: the two cards, the glyphs and counts, the two-tap rule, the
## command and its argument, the act banner and strip, the briefing lines and CONTINUE.

var _api: FakeRunApi
var _o: RouteOverlay


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_api = VarietyEKit.api_for("route")
	_o = VarietyEKit.overlay(self, "route", _api) as RouteOverlay


func after_test() -> void:
	ScreensTestKit.fresh_save()


func test_the_two_cards_show_pack_risk_counts_modifier_and_reward() -> void:
	assert_int(_o.cards.size()).is_equal(2)
	var standard: RouteCard = _o.cards[0]
	var hot: RouteCard = _o.cards[1]
	assert_str(standard.risk_label.text).is_equal(Strings.t("route.standard"))
	assert_str(hot.risk_label.text).is_equal(Strings.t("route.hot"))
	assert_str(standard.name_label.text).is_equal(Strings.t("pack.column.name"))
	assert_str(hot.name_label.text).is_equal(Strings.t("pack.powder.name"))
	assert_str(standard.hostiles_label.text).is_equal(Strings.tf("route.hostiles", [29]))
	assert_str(hot.hostiles_label.text).is_equal(Strings.tf("route.hostiles", [65]))
	assert_str(standard.elites_label.text).is_equal(Strings.t("route.elite_one"))
	assert_str(standard.modifier_label.text).is_equal(Strings.t("modifier.none"))
	assert_str(hot.modifier_label.text).is_equal(Strings.t("modifier.volatile.name"))
	assert_str(hot.modifier_desc.text).is_equal(Strings.t("modifier.volatile.desc"))
	assert_str(standard.reward_label.text).is_equal(Strings.tf("reward.scrap.name", [120]))
	assert_str(hot.reward_label.text).is_equal(Strings.t("reward.crate.name"))


func test_the_glyphs_are_the_three_most_numerous_types_with_their_counts() -> void:
	var hot: RouteCard = _o.cards[1]
	assert_int(hot.glyphs.size()).is_equal(3)
	var ids: Array[String] = []
	for g: RunEnemyGlyph in hot.glyphs:
		ids.append(String(g.enemy_id))
	assert_array(ids).is_equal(["mote", "skitter", "burster"])
	assert_str(hot.glyph_counts[0].text).is_equal(Strings.tf("route.glyph_count", [29]))
	assert_str(hot.glyph_counts[2].text).is_equal(Strings.tf("route.glyph_count", [10]))
	assert_int(_o.cards[0].glyphs.size()).is_equal(2)


func test_a_tap_selects_a_card_and_sends_nothing() -> void:
	assert_bool(_o.confirm_button.disabled).is_true()
	_o.cards[1].tap()
	assert_int(_o.selected).is_equal(1)
	assert_bool(_o.cards[1].selected).is_true()
	assert_bool(_o.confirm_button.disabled).is_false()
	assert_str(_o.confirm_button.text).is_equal(Strings.tf("route.confirm", [Strings.t("route.hot")]))
	assert_int(_api.calls.size()).is_equal(0)


func test_confirm_sends_pick_route_with_the_option_index() -> void:
	_o.cards[1].tap()
	_o.confirm_button.pressed.emit()
	var picks: Array[Dictionary] = VarietyEKit.calls_of(_api, "pick_route")
	assert_int(picks.size()).is_equal(1)
	assert_int(_api.calls.size()).is_equal(1)
	var option: int = picks[0]["arg"]
	var command_id: int = picks[0]["command_id"]
	assert_int(option).is_equal(1)
	assert_int(command_id).is_greater(0)


func test_confirm_with_no_selection_sends_nothing() -> void:
	_o.confirm_button.pressed.emit()
	assert_int(_api.calls.size()).is_equal(0)


func test_the_act_banner_names_the_act_the_wave_and_the_visible_plating() -> void:
	assert_str(_o.act_label_node.text).is_equal("%s  %s" % [Strings.tf("act.label", ["I"]), Strings.t("act.yard.name")])
	assert_str(_o.wave_label.text).is_equal(Strings.tf("route.wave_of", [3, 5]))
	assert_str(_o.info_label.text).is_equal("%s (%s)" % [Strings.tf("act.tier", [1]), Strings.tf("route.plating_hp", [0])])
	assert_str(_o.core_label.text).is_equal(Strings.tf("hud.core_pct", [64]))
	assert_str(_o.scrap_label.text).is_equal("410")


func test_the_act_strip_marks_the_waves_and_the_bosses() -> void:
	assert_int(_o.strip.next_wave).is_equal(3)
	assert_int(_o.strip.wave_count).is_equal(5)
	assert_bool(_o.strip.boss_waves.has(5)).is_true()
	assert_int(_o.strip.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_two_hot_options_say_no_quiet_route_and_confirm_names_the_pack() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("route")
	api.fake_route_options[0]["hot"] = true
	var o: RouteOverlay = VarietyEKit.overlay(self, "route", api) as RouteOverlay
	assert_object(o.quiet_label).is_not_null()
	assert_str(o.quiet_label.text).is_equal(Strings.t("route.none_quiet"))
	o.cards[0].tap()
	assert_str(o.confirm_button.text).is_equal(Strings.tf("route.confirm", [Strings.t("pack.column.name")]))


func test_a_long_press_lists_the_enemies_and_commits_nothing() -> void:
	_o.cards[1].long_press()
	var panel: RunDetailPanel = _o.modal as RunDetailPanel
	assert_object(panel).is_not_null()
	assert_str(panel.title_label.text).is_equal(Strings.t("pack.powder.name"))
	assert_str(panel.extra_labels[0].text).is_equal("%s  %s" % [Strings.t("enemy.mote.name"), Strings.tf("route.glyph_count", [29])])
	assert_int(_api.calls.size()).is_equal(0)
	panel.close_button.pressed.emit()
	assert_object(_o.modal).is_null()


func test_a_new_offer_clears_the_selection() -> void:
	_o.cards[0].tap()
	Events.route_offered.emit()
	assert_int(_o.selected).is_equal(-1)
	assert_int(_o.cards.size()).is_equal(2)


# --- the boss briefing ---


func test_the_boss_briefing_shows_name_attack_and_answer_and_continue_sends_continue_run() -> void:
	Save.profile.unlocks.append("u_w_arc")  # the answer names the Arc Projector: a run that owns it (or an Archive without it) shows it as written
	var api: FakeRunApi = VarietyEKit.api_for("boss_brief")
	var b: BossBriefOverlay = VarietyEKit.overlay(self, "boss_brief", api) as BossBriefOverlay
	assert_str(b.name_label.text).is_equal(Strings.t("boss.siege_hulk.name"))
	assert_str(b.attack_head.text).is_equal(Strings.t("boss_brief.attack"))
	assert_str(b.attack_label.text).is_equal(Strings.t("lore.threat.siege_hulk"))
	assert_str(b.answer_head.text).is_equal(Strings.t("boss_brief.answer"))
	assert_str(b.answer_label.text).is_equal(Strings.t("boss.siege_hulk.answer"))
	assert_str(String(b.glyph.enemy_id)).is_equal("siege_hulk")
	assert_str(b.wave_label.text).is_equal(Strings.tf("route.wave_of", [5, 5]))
	assert_int(api.calls.size()).is_equal(0)
	b.continue_button.pressed.emit()
	assert_int(VarietyEKit.calls_of(api, "continue_run").size()).is_equal(1)
	assert_int(api.calls.size()).is_equal(1)
	ScreensTestKit.fresh_save()


func test_a_node_9_variant_shows_its_name_and_its_own_lines() -> void:
	Save.profile.unlocks.append("u_w_torch")  # the plated line names the torch and the rail lance: a run that owns them shows it as written
	Save.profile.unlocks.append("u_w_rail")
	var api: FakeRunApi = VarietyEKit.api_for("boss_brief")
	api.fake_boss_brief["variant"] = &"hulk_plated"
	var b: BossBriefOverlay = VarietyEKit.overlay(self, "boss_brief", api) as BossBriefOverlay
	assert_object(b.variant_label).is_not_null()
	assert_str(b.variant_label.text).is_equal(Strings.t("boss.hulk_plated"))
	assert_str(b.attack_label.text).is_equal(Strings.t("boss.hulk_plated.attack"))
	assert_str(b.answer_label.text).is_equal(Strings.t("boss.hulk_plated.answer"))
	ScreensTestKit.fresh_save()


func test_every_boss_has_a_name_an_attack_line_and_an_answer_line() -> void:
	for id: String in ["brood_carrier", "lance_platform", "aegis_array", "tremor_rig", "siege_hulk"]:
		var api: FakeRunApi = VarietyEKit.api_for("boss_brief")
		api.fake_boss_brief = {"id": StringName(id), "name_key": "boss.%s.name" % id, "variant": &"", "banner_key": "boss.%s.banner" % id,
			"attack_key": "", "answer_key": ""}
		var b: BossBriefOverlay = VarietyEKit.overlay(self, "boss_brief", api) as BossBriefOverlay
		assert_str(b.name_label.text).is_equal(Strings.t("boss.%s.name" % id))
		assert_str(b.attack_label.text).is_equal(Strings.t("boss.%s.attack" % id))
		assert_str(b.answer_label.text).is_equal(Strings.t("boss.%s.answer" % id))
		assert_bool(b.attack_head.visible).is_true()
		assert_str(b.banner_label.text).is_equal(Strings.t("boss.%s.banner" % id))


func test_a_line_with_no_text_is_left_out_instead_of_showing_a_marker() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("boss_brief")
	api.fake_boss_brief = {"id": &"unknown_node", "name_key": "boss.siege_hulk.name", "variant": &"", "banner_key": "", "attack_key": "", "answer_key": ""}
	var b: BossBriefOverlay = VarietyEKit.overlay(self, "boss_brief", api) as BossBriefOverlay
	assert_bool(b.attack_head.visible).is_false()
	assert_bool(b.answer_label.visible).is_false()
	assert_array(VarietyEKit.bad_texts(b)).is_empty()
