extends GdUnitTestSuite
## V4-U: no screen may be wider than the viewport (the Archive overflowed a 1080 x 2342 phone: "RECOVE", "FIE", cut columns). Each
## screen of the V4-U work is put under a host of every size of UiOverflowKit.SIZES (down to 720 wide) with the longest states it
## can show (an empty profile: every row says how much Data is missing), and no visible Control may leave the viewport sideways.
## The check is the real layout of the real scenes, not a minimum-size estimate.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = Content.db


func after_test() -> void:
	ScreensTestKit.fresh_save()
	RunSession.bind(null, null)


func _assert_fits(root: Control, view: Vector2, what: String) -> void:
	var out: Array[String] = UiOverflowKit.overflowing(root, view)
	var culprits: Array[String] = []
	if not out.is_empty():
		culprits = UiOverflowKit.wide_minimums(root, view.x - 60.0)
	assert_array(out).override_failure_message("%s overflows %s: %s | widest minimums, deepest first: %s" % [what, view, "\n".join(out.slice(0, 6)), "\n".join(culprits)]).is_empty()


# --- the Archive ---


func _archive(view: Vector2, data: int, owned: Array[String]) -> ArchiveScreen:
	var packed: PackedScene = load(V4uKit.ARCHIVE) as PackedScene
	var screen: ArchiveScreen = packed.instantiate() as ArchiveScreen
	UiOverflowKit.host(self, view).add_child(screen)
	screen.setup(_cs, ArchiveBank.new(V4uKit.profile(data, owned), _cs))
	return screen


func test_every_tab_of_the_archive_fits_every_viewport_with_an_empty_purse() -> void:
	for view: Vector2 in UiOverflowKit.SIZES_NARROW:
		var screen: ArchiveScreen = _archive(view, 40, [])  # 40 Data: every row reads "NEED n MORE", the longest state
		for branch: int in ArchiveModel.BRANCHES:
			screen.select_branch(branch)
			await UiOverflowKit.settle(get_tree())
			_assert_fits(screen, view, "archive tab %d" % branch)


func test_the_archive_fits_with_the_longest_rules_selected_and_owned_rows() -> void:
	for view: Vector2 in UiOverflowKit.SIZES_NARROW:
		var screen: ArchiveScreen = _archive(view, 900, ["u_w_hornet", "u_w_lmg", "u_p_blast"])
		for branch: int in ArchiveModel.BRANCHES:
			screen.select_branch(branch)
			for row: ArchiveRow in screen.rows:
				screen.select(row.def)
				await UiOverflowKit.settle(get_tree(), 2)
				_assert_fits(screen, view, "archive %s" % String(row.def.id))


func test_the_archive_undo_window_and_a_notice_fit() -> void:
	for view: Vector2 in [Vector2(1080.0, 2342.0), Vector2(720.0, 1600.0)]:
		var screen: ArchiveScreen = _archive(view, 900, [])
		screen.select(_cs.unlock(&"u_w_hornet"))
		screen.unlock_button.pressed.emit()
		await UiOverflowKit.settle(get_tree())
		_assert_fits(screen, view, "archive pending")
		screen._process(ArchiveScreen.UNDO_SECONDS + 1.0)
		await UiOverflowKit.settle(get_tree())
		_assert_fits(screen, view, "archive after a purchase")


# --- the other V4-U screens ---


func test_the_briefing_with_the_kit_row_fits_every_viewport() -> void:
	for view: Vector2 in UiOverflowKit.SIZES:
		var s: BriefingScreen = ScreensTestKit.screen(self, ScreensTestKit.BRIEFING, view) as BriefingScreen
		s.setup(_cs)
		await UiOverflowKit.settle(get_tree())
		assert_bool(s.kit_selector.visible).is_true()
		_assert_fits(s, view, "briefing")


func _summary() -> RunSummary:
	return V4uKit.summary(_cs)


func test_the_results_of_a_generated_run_fit_every_viewport() -> void:
	for view: Vector2 in UiOverflowKit.SIZES:
		var s: ResultsScreen = ScreensTestKit.screen(self, ScreensTestKit.RESULTS, view) as ResultsScreen
		s.setup(_summary(), _cs, V4uKit.profile(130), true)
		s.show_milestones([{"id": &"ms_first_boss_siege_hulk", "data": 50}, {"id": &"ms_victory_kit_k_gambler", "data": 75}])
		s.finish_count_up()
		await UiOverflowKit.settle(get_tree())
		_assert_fits(s, view, "results")


func test_the_menu_with_resume_daily_and_best_wave_fits_every_viewport() -> void:
	for view: Vector2 in UiOverflowKit.SIZES:
		var s: MainMenuScreen = ScreensTestKit.screen(self, ScreensTestKit.MENU, view) as MainMenuScreen
		var profile: Profile = V4uKit.profile(1250)
		profile.best_core_hp = 620
		s.setup(profile)
		s.set_resume_wave(12)
		s.daily_button.visible = true
		s.daily_label.text = Strings.tf("menu.daily.best", [12])
		s.daily_label.visible = true
		await UiOverflowKit.settle(get_tree())
		_assert_fits(s, view, "menu")


func test_the_pause_overlay_with_the_seed_and_build_fits_every_viewport() -> void:
	for view: Vector2 in UiOverflowKit.SIZES:
		var api: FakeRunApi = VarietyEKit.api_for("combat2")
		api.fake_run_seed = 2147483647
		RunSession.bind(api, TestContent.variety())
		var node: PauseOverlay = (load("res://src/ui/combat/pause_overlay.tscn") as PackedScene).instantiate() as PauseOverlay
		UiOverflowKit.host(self, view).add_child(node)
		node.setup()
		await UiOverflowKit.settle(get_tree())
		_assert_fits(node, view, "pause")
		assert_bool(node.open_build()).is_true()
		await UiOverflowKit.settle(get_tree())
		_assert_fits(node, view, "pause with the build list")


func test_the_choice_overlays_fit_every_viewport() -> void:
	for view: Vector2 in UiOverflowKit.SIZES:
		for state: String in VarietyEKit.STATES:
			Save.profile.hints_seen = PackedStringArray()  # the hint lines are part of the layout
			var overlay: RunOverlayBase = VarietyEKit.overlay(self, state, VarietyEKit.api_for(state), view)
			await UiOverflowKit.settle(get_tree())
			_assert_fits(overlay, view, "%s overlay" % state)
