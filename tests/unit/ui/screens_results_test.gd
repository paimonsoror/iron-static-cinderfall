extends GdUnitTestSuite
## ResultsScreen: the run's numbers, the Data count-up, the already-recorded case, no reward logic of its own.

var _content: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_content = TestContent.baseline()


func _summary(won: bool) -> RunSummary:
	var r: RunSummary = RunSummary.new()
	r.run_id = "results-test"
	r.result = RunResult.Id.VICTORY if won else RunResult.Id.DEFEAT
	r.waves_completed = 5 if won else 3
	r.core_max_hp = 1000
	r.core_hp = 620 if won else 0
	r.duration_ticks = 16320 if won else 8400  # 4:32 and 2:20
	r.kills_by_type = PackedInt32Array([88, 10, 18, 1] if won else [60, 6, 0, 0])
	r.data_reward = 131 if won else 30
	return r


func _results(summary: RunSummary, granted: bool = true, total: int = 1250) -> ResultsScreen:
	var s: ResultsScreen = ScreensTestKit.screen(self, ScreensTestKit.RESULTS) as ResultsScreen
	var profile: Profile = Profile.defaults()
	profile.data = total
	s.setup(summary, _content, profile, granted)
	return s


func test_a_victory_fills_every_label_with_its_numbers() -> void:
	var s: ResultsScreen = _results(_summary(true))
	s.finish_count_up()
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()
	assert_str(s.title_label.text).is_equal(Strings.t("results.victory"))
	assert_str(s.waves_cell.value.text).is_equal("5/5")
	assert_str(s.time_cell.value.text).is_equal("4:32")
	assert_str(s.core_cell.value.text).is_equal("620/1000 (62%)")
	assert_str(s.kills_cell.value.text).is_equal("117")
	assert_str(s.lore_label.text).is_equal(Strings.t("lore.results.victory"))


func test_a_defeat_says_so_and_shows_the_waves_cleared_and_zero_core() -> void:
	var s: ResultsScreen = _results(_summary(false))
	s.finish_count_up()
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()
	assert_str(s.title_label.text).is_equal(Strings.t("results.defeat"))
	assert_str(s.waves_cell.value.text).is_equal("3/5")
	assert_str(s.core_cell.value.text).is_equal("0/1000 (0%)")
	assert_str(s.lore_label.text).is_equal(Strings.t("lore.results.defeat"))
	assert_str(s.speaker_label.text).is_equal(Strings.t("lore.results.speaker.defeat"))


func test_kills_by_type_list_every_enemy_in_content_order() -> void:
	var s: ResultsScreen = _results(_summary(true))
	assert_int(s.kill_rows.size()).is_equal(_content.enemies.size())
	var counts: Array[String] = []
	for l: Label in s.kill_rows:
		counts.append(l.text)
	assert_array(counts).is_equal(["88", "10", "18", "1"])
	var short: RunSummary = _summary(true)
	short.kills_by_type = PackedInt32Array([5])
	var s2: ResultsScreen = _results(short)
	assert_str(s2.kill_rows[3].text).is_equal("0")


func test_the_data_reward_passed_in_is_shown_with_the_new_total() -> void:
	var s: ResultsScreen = _results(_summary(true), true, 1250)
	s.finish_count_up()
	assert_str(s.data_label.text).is_equal("+131")
	assert_str(s.total_label.text).is_equal(Strings.tf("results.data_total", ["1,250"]))


func test_the_data_counts_up_and_a_tap_or_the_end_of_the_count_shows_the_final_number() -> void:
	var s: ResultsScreen = _results(_summary(true))
	assert_bool(s.is_counting()).is_true()
	assert_str(s.data_label.text).is_equal("+0")
	s._process(ResultsScreen.COUNT_SECONDS * 0.5)
	var half: int = int(s.data_label.text.trim_prefix("+"))
	assert_int(half).is_between(1, 130)
	s._process(ResultsScreen.COUNT_SECONDS)
	assert_bool(s.is_counting()).is_false()
	assert_str(s.data_label.text).is_equal("+131")
	var again: ResultsScreen = _results(_summary(true))
	again.finish_count_up()
	assert_str(again.data_label.text).is_equal("+131")


func test_a_run_that_was_already_recorded_shows_no_new_data() -> void:
	var s: ResultsScreen = _results(_summary(true), false, 1250)
	assert_bool(s.is_counting()).is_false()
	assert_str(s.data_label.text).is_equal("+0")
	assert_str(s.total_label.text).is_equal(Strings.tf("results.data_banked", ["1,250"]))
	assert_array(ScreensTestKit.bad_texts(s)).is_empty()


func test_results_never_grants_a_reward_itself() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/ui/screens/results_screen.gd")
	assert_bool(source.contains("grant_run_reward")).is_false()
	assert_bool(source.contains("set_setting")).is_false()
	var before: int = Save.profile.data
	var runs_before: int = Save.profile.runs_played
	var s: ResultsScreen = _results(_summary(true))
	s.finish_count_up()
	s.retry_button.pressed.emit()
	assert_int(Save.profile.data).is_equal(before)
	assert_int(Save.profile.runs_played).is_equal(runs_before)
	assert_array(Save.profile.awarded_run_ids).is_empty()


func test_each_results_button_emits_its_signal_once_and_is_big() -> void:
	var s: ResultsScreen = _results(_summary(true))
	var hits: Array[String] = []
	s.retry_pressed.connect(func() -> void: hits.append("retry"))
	s.menu_pressed.connect(func() -> void: hits.append("menu"))
	s.retry_button.pressed.emit()
	assert_array(hits).is_equal(["retry"])
	s.menu_button.pressed.emit()
	assert_array(hits).is_equal(["retry", "menu"])
	await ScreensTestKit.settle(get_tree())
	assert_int(UiKit.buttons(s).size()).is_equal(4)  # V4-U: SAME SEED and ARCHIVE exist but stay hidden on the legacy results
	assert_array(ScreensTestKit.small_buttons(s)).is_empty()
	assert_float(s.retry_button.size.y).is_greater_equal(148.0)
