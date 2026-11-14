extends GdUnitTestSuite
## V4-U: the results additions of a generated run (GDD 10.6): the act and wave line, WHAT BROKE THE LINE, the build recap, the
## milestone lines, the Archive hook, the seed with SAME SEED and the ARCHIVE button; the legacy results stay as they were.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = V4uKit.content()


func after_test() -> void:
	ScreensTestKit.fresh_save()


func _event(id: StringName, harmful: bool) -> int:
	var def: EventDef = EventDef.new()
	def.id = id
	def.index = _cs.events.size()
	def.name_key = "event.%s.name" % String(id)
	def.harmful = harmful
	_cs.events.append(def)
	return def.index


func _results(summary: RunSummary, profile: Profile, view: Vector2 = Vector2(1080.0, 2400.0), content: ContentSet = null) -> ResultsScreen:
	var s: ResultsScreen = ScreensTestKit.screen(self, ScreensTestKit.RESULTS, view) as ResultsScreen
	s.setup(summary, content if content != null else _cs, profile, true)
	s.finish_count_up()
	return s


# --- the recap texts ---


func test_the_machines_that_hurt_the_core_most_come_first_and_at_most_three() -> void:
	var lines: Array[String] = ResultsRecap.damage_lines(V4uKit.summary(_cs), _cs)
	assert_array(lines).is_equal(["skitter 412", "hollow warden 260", "burster 90"])


func test_the_harmful_events_that_came_are_named_most_often_first() -> void:
	var front: int = _event(&"static_front", true)
	var vent: int = _event(&"core_vent", false)
	var surge: int = _event(&"power_surge", true)
	var s: RunSummary = V4uKit.summary(_cs)
	s.events_seen.resize(_cs.events.size())
	s.events_seen[front] = 2
	s.events_seen[vent] = 5  # helpful: never listed
	s.events_seen[surge] = 1
	assert_str(ResultsRecap.events_line(s, _cs)).is_equal("STATIC FRONT + CORE SURGE")
	assert_str(ResultsRecap.events_line(V4uKit.summary(_cs), _cs)).is_equal("")


func test_the_build_recap_counts_tags_directives_and_weapons() -> void:
	var s: RunSummary = V4uKit.summary(_cs)
	var expected: Dictionary[StringName, int] = {}
	for i: int in _cs.directives.size():
		if s.directives[i] <= 0:
			continue
		for tag: StringName in _cs.directives[i].tags:
			var held: int = expected.get(tag, 0)
			expected[tag] = held + s.directives[i]
	var chips: Array[String] = ResultsRecap.chip_texts(s, _cs)
	assert_int(chips.size()).is_between(1, ResultsRecap.MAX_CHIPS)
	var got: Dictionary[StringName, int] = ResultsRecap.tag_stacks(s, _cs)
	assert_dict(got).is_equal(expected)
	var texts: Array[String] = ResultsRecap.directive_texts(s, _cs)
	assert_array(texts).contains("HOT LOADS x3", "CYCLIC TUNING x2")
	assert_str(ResultsRecap.weapons_line(s, _cs)).is_equal("ARC PROJ.  PISTOL")  # an empty slot is not listed


func test_a_milestone_line_names_it_and_its_data() -> void:
	assert_str(ResultsRecap.milestone_text({"id": &"ms_first_boss_siege_hulk", "data": 50})).is_equal("MILESTONE: NODE 9 FIRST KILL  +50")
	assert_str(ResultsRecap.milestone_text({"id": &"ms_first_victory", "data": 1200})).contains("+1,200")
	assert_str(ResultsRecap.milestone_text({"id": &"ms_unknown_one", "data": 5})).contains("MS UNKNOWN ONE")  # an id with no text


func test_the_archive_hook_names_what_the_data_covers_or_the_nearest_goal() -> void:
	assert_str(ResultsRecap.hook_text(_cs, V4uKit.profile(130))).is_equal("ARCHIVE: YOU CAN AFFORD LMG (120)")
	assert_str(ResultsRecap.hook_text(_cs, V4uKit.profile(50))).is_equal("ARCHIVE: HORNET RACK IS 30 DATA AWAY")
	assert_str(ResultsRecap.hook_text(TestContent.baseline(), V4uKit.profile(500))).is_equal("")  # no Archive in the legacy content


# --- the screen ---


func test_a_generated_run_shows_the_act_line_the_recap_the_seed_and_the_archive_button() -> void:
	var s: ResultsScreen = _results(V4uKit.summary(_cs), V4uKit.profile(130))
	await V4uKit.settle(get_tree())
	assert_bool(s.act_label.visible).is_true()
	assert_str(s.act_label.text).contains("ACT I")
	assert_str(s.act_label.text).contains("WAVE 4 OF 15")  # a defeat in the fourth wave of the fifteen
	assert_str(s.act_label.text).contains("9:42")
	assert_bool(s.recap.visible).is_true()
	assert_str(s.recap.broke_lines[0].text).contains("skitter 412")
	assert_array(s.recap.build_directives.map(func(l: Label) -> String: return l.text)).contains("HOT LOADS x3")
	assert_str(s.seed_label.text).is_equal("SEED 48211")
	assert_bool(s.seed_label.visible).is_true()
	assert_bool(s.same_seed_button.visible).is_true()
	assert_bool(s.archive_button.visible).is_true()
	assert_str(s.hook_label.text).contains("LMG")
	assert_bool(s.hook_label.visible).is_true()


func test_a_victory_counts_the_wave_it_finished_and_names_nothing_that_broke() -> void:
	var s: RunSummary = V4uKit.summary(_cs, RunResult.Id.VICTORY)
	s.waves_completed = 5
	s.core_damage_by_type = PackedFloat64Array()
	s.core_damage_by_type.resize(_cs.enemies.size())
	var screen: ResultsScreen = _results(s, V4uKit.profile(0))
	assert_str(screen.act_label.text).contains("WAVE 5 OF 15")
	assert_str(screen.recap.broke_lines[0].text).is_equal(Strings.t("results.broke_held"))


func test_milestones_show_under_the_data_and_clear() -> void:
	var s: ResultsScreen = _results(V4uKit.summary(_cs), V4uKit.profile(0))
	assert_bool(s.milestone_label.visible).is_false()
	s.show_milestones([{"id": &"ms_first_boss_siege_hulk", "data": 50}, {"id": &"ms_first_victory", "data": 200}])
	assert_bool(s.milestone_label.visible).is_true()
	assert_str(s.milestone_label.text).contains("NODE 9 FIRST KILL")
	assert_str(s.milestone_label.text).contains("FIRST VICTORY")
	s.show_milestones([])
	assert_bool(s.milestone_label.visible).is_false()


func test_same_seed_sends_the_seed_of_the_run_and_does_nothing_unheard() -> void:
	var s: ResultsScreen = _results(V4uKit.summary(_cs), V4uKit.profile(0))
	s.same_seed_button.pressed.emit()  # nobody listens: no signal, no crash
	var seeds: Array[int] = []
	s.same_seed_pressed.connect(func(run_seed: int) -> void: seeds.append(run_seed))
	s.same_seed_button.pressed.emit()
	assert_array(seeds).is_equal([48211])
	var retries: Array[bool] = []
	s.retry_pressed.connect(func() -> void: retries.append(true))
	s.retry_button.pressed.emit()
	assert_array(retries).is_equal([true])


func test_the_archive_button_opens_the_archive_over_the_results_and_closing_it_frees_it() -> void:
	var s: ResultsScreen = _results(V4uKit.summary(_cs), V4uKit.profile(0))
	var hits: Array[bool] = []
	s.archive_pressed.connect(func() -> void: hits.append(true))
	s.archive_button.pressed.emit()
	assert_array(hits).is_equal([true])
	assert_object(s.archive_screen).is_not_null()
	s.archive_screen.close()
	await V4uKit.settle(get_tree())
	assert_object(s.archive_screen).is_null()


func test_the_legacy_results_keep_their_old_shape() -> void:
	var legacy: ContentSet = TestContent.baseline()
	var s: RunSummary = RunSummary.new()
	s.run_id = "legacy"
	s.result = RunResult.Id.VICTORY
	s.waves_completed = 5
	s.core_max_hp = 1000
	s.core_hp = 500
	s.kills_by_type = PackedInt32Array([10, 5, 3, 1])
	var screen: ResultsScreen = _results(s, Profile.defaults(), Vector2(1080.0, 2400.0), legacy)
	assert_bool(screen.act_label.visible).is_false()
	assert_bool(screen.recap.visible).is_false()
	assert_bool(screen.seed_label.visible).is_false()
	assert_bool(screen.same_seed_button.visible).is_false()
	assert_bool(screen.archive_button.visible).is_false()
	assert_bool(screen.hook_label.visible).is_false()


func test_the_results_fit_three_aspects_and_a_narrow_phone() -> void:
	var sizes: Array[Vector2] = V4uKit.SIZES.duplicate()
	sizes.append(V4uKit.NARROW)
	for view: Vector2 in sizes:
		var s: ResultsScreen = _results(V4uKit.summary(_cs), V4uKit.profile(130), view)
		await V4uKit.settle(get_tree())
		assert_array(ScreensTestKit.bad_texts(s)).is_empty()
		for b: Button in UiKit.buttons(s):
			if b.is_visible_in_tree():
				assert_float(b.size.y).override_failure_message("%s %s at %s" % [b.text, b.size, view]).is_greater_equal(132.0)
				assert_float(b.global_position.x + b.size.x).is_less_equal(view.x + 0.5)
				assert_float(b.global_position.y + b.size.y).override_failure_message("%s off screen at %s" % [b.text, view]).is_less_equal(view.y + 0.5)
		for label: Label in s.recap.broke_lines:
			assert_int(label.get_theme_font_size(&"font_size")).is_greater_equal(30)
		for label: Label in s.recap.build_directives:
			assert_int(label.get_theme_font_size(&"font_size")).is_greater_equal(30)


func test_the_back_gesture_closes_the_archive_overlay_of_the_results() -> void:
	var s: ResultsScreen = _results(V4uKit.summary(_cs), V4uKit.profile(0))
	assert_bool(s.close_overlay()).is_false()
	s.archive_button.pressed.emit()
	assert_bool(s.close_overlay()).is_true()
	await V4uKit.settle(get_tree())
	assert_object(s.archive_screen).is_null()


func test_the_recovered_data_comes_before_the_recaps_so_it_is_on_the_first_screen() -> void:
	var s: ResultsScreen = _results(V4uKit.summary(_cs), V4uKit.profile(130), Vector2(1080.0, 1920.0))
	await V4uKit.settle(get_tree())
	assert_float(s.data_label.global_position.y).is_less(s.recap.global_position.y)
	assert_float(s.data_label.global_position.y + s.data_label.size.y).is_less(1920.0 - 400.0)  # above the footer on a 1920 screen
	assert_float(s.hook_label.global_position.y + s.hook_label.size.y).is_less(1920.0 - 300.0)
