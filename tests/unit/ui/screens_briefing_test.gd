extends GdUnitTestSuite
## BriefingScreen on the frozen baseline content: lore, objectives, threat rows, signals.

var _content: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_content = TestContent.baseline()


func _briefing() -> BriefingScreen:
	var s: BriefingScreen = ScreensTestKit.screen(self, ScreensTestKit.BRIEFING) as BriefingScreen
	s.setup(_content)
	return s


func test_setup_fills_every_label_with_no_placeholder() -> void:
	var s: BriefingScreen = _briefing()
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()
	assert_str(s.mission_label.text).is_equal(Strings.t(_content.mission.name_key).to_upper())
	assert_str(s.header_plate.label.text).is_equal(Strings.t("briefing.header").to_upper())


func test_the_accord_radio_text_and_the_warden_callsign_come_from_the_lore_table() -> void:
	var s: BriefingScreen = _briefing()
	assert_str(s.radio_label.text).is_equal(Strings.t("lore.briefing.text"))
	assert_str(s.radio_label.text).contains("Accord out.")
	assert_str(s.radio_speaker_label.text).is_equal(Strings.t("lore.briefing.speaker"))
	assert_str(s.assigned_label.text).contains("ASH-12")
	assert_str(s.assigned_label.text).contains("FLINT")


func test_the_objectives_state_waves_core_and_boss_from_the_content() -> void:
	var s: BriefingScreen = _briefing()
	assert_int(s.objective_labels.size()).is_equal(3)
	assert_str(s.objective_labels[0].text).is_equal(Strings.tf("briefing.obj.waves", [_content.waves.size()]))
	assert_str(s.objective_labels[1].text).contains(UiKit.group(roundi(_content.mission.core_max_hp)))
	assert_str(s.objective_labels[2].text).contains(Strings.t("enemy.siege_hulk.name"))
	assert_str(s.objective_labels[2].text).contains(str(_content.waves.size()))


func test_there_is_one_threat_row_per_enemy_weakest_first_with_its_own_silhouette() -> void:
	var s: BriefingScreen = _briefing()
	assert_int(s.threat_rows.size()).is_equal(4)
	var ids: Array[StringName] = []
	for row: BriefingThreatRow in s.threat_rows:
		ids.append(row.glyph.enemy_id)
	assert_array(ids).is_equal([&"skitter", &"rusher", &"hollow_warden", &"siege_hulk"])
	for i: int in s.threat_rows.size():
		assert_int(s.threat_rows[i].chevrons.count).is_equal(i + 1)
		assert_int(s.threat_rows[i].chevrons.max_count).is_equal(4)
		assert_str(s.threat_rows[i].name_label.text).is_not_empty()


func test_the_hollow_warden_row_explains_it_is_a_chorus_frame_not_the_accord() -> void:
	var s: BriefingScreen = _briefing()
	var text: String = ""
	for row: BriefingThreatRow in s.threat_rows:
		if row.glyph.enemy_id == &"hollow_warden":
			text = row.desc_label.text
	assert_str(text).contains("CHORUS")
	assert_str(text).contains("Not Accord")


func test_calling_setup_again_replaces_the_rows_instead_of_stacking_them() -> void:
	var s: BriefingScreen = _briefing()
	s.setup(_content)
	await ScreensTestKit.settle(get_tree())
	assert_int(s.threat_rows.size()).is_equal(4)
	assert_int(s.objective_labels.size()).is_equal(3)
	var rows: int = 0
	for node: Node in s.find_children("*", "PanelContainer", true, false):
		if node is BriefingThreatRow:
			rows += 1
	assert_int(rows).is_equal(4)


func test_each_briefing_button_emits_its_signal_once() -> void:
	var s: BriefingScreen = _briefing()
	var hits: Array[String] = []
	s.deploy_pressed.connect(func() -> void: hits.append("deploy"))
	s.back_pressed.connect(func() -> void: hits.append("back"))
	s.deploy_button.pressed.emit()
	assert_array(hits).is_equal(["deploy"])
	s.back_button.pressed.emit()
	assert_array(hits).is_equal(["deploy", "back"])
	assert_int(UiKit.buttons(s).size()).is_equal(2)


func test_briefing_buttons_are_big_and_the_whole_briefing_fits_a_tall_phone_screen() -> void:
	var s: BriefingScreen = _briefing()
	await ScreensTestKit.settle(get_tree())
	assert_array(ScreensTestKit.small_buttons(s)).is_empty()
	assert_float(s.deploy_button.size.y).is_greater_equal(148.0)
	for row: BriefingThreatRow in s.threat_rows:
		assert_float(row.get_global_rect().end.y).is_less_equal(s.deploy_button.global_position.y)
