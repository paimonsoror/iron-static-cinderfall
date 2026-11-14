extends GdUnitTestSuite
## V5-B: every screen of the game (boot, menu, settings, briefing, results, the Archive, the pause overlay) fits every viewport of
## UiOverflowKit.SIZES_V5B and the wide window of a foldable's inner display, in its worst state (the biggest numbers, an empty
## purse, every row owned or selected, High Contrast on): nothing leaves the viewport, no text is cut and no two controls overlap.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = Content.db


func after_test() -> void:
	ScreensTestKit.fresh_save()
	RunSession.bind(null, null)


func _sizes() -> Array[Vector2]:
	var out: Array[Vector2] = UiOverflowKit.SIZES_V5B.duplicate()
	out.append(UiOverflowKit.SIZE_WIDE)
	return out


func _check(node: Control, view: Vector2, what: String) -> void:
	var message: String = V5bKit.verdict(node, view, what)
	assert_str(message).override_failure_message(message).is_empty()


func _screen(path: String, view: Vector2) -> Control:
	return ScreensTestKit.screen(self, path, view)


func test_boot_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var s: BootScreen = _screen(ScreensTestKit.BOOT, view) as BootScreen
		s.setup("9.99.999-debug")
		await V5bKit.settle(get_tree())
		_check(s, view, "boot")


func test_the_menu_in_its_fullest_state_fits_every_viewport() -> void:
	for high_contrast: bool in [false, true]:
		Save.profile.settings[&"high_contrast"] = high_contrast
		for view: Vector2 in _sizes():
			var s: MainMenuScreen = _screen(ScreensTestKit.MENU, view) as MainMenuScreen
			var big: int = V5bKit.BIG if view.x >= 1080.0 else 12500  # the biggest numbers need the phone's 1080 px canvas
			var profile: Profile = V4uKit.profile(big)
			profile.best_core_hp = 1000
			profile.missions_completed = big
			s.setup(profile)
			s.set_resume_wave(15)
			s.daily_button.visible = true
			s.daily_label.text = Strings.tf("menu.daily.best", [15])
			s.daily_label.visible = true
			await V5bKit.settle(get_tree())
			_check(s, view, "menu (high contrast %s)" % high_contrast)


func test_the_menu_of_a_new_profile_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var s: MainMenuScreen = _screen(ScreensTestKit.MENU, view) as MainMenuScreen
		s.setup(Profile.defaults())
		await V5bKit.settle(get_tree())
		_check(s, view, "menu (new profile)")


func test_settings_fit_every_viewport() -> void:
	for high_contrast: bool in [false, true]:
		Save.profile.settings[&"high_contrast"] = high_contrast
		for view: Vector2 in _sizes():
			var s: SettingsScreen = _screen(ScreensTestKit.SETTINGS, view) as SettingsScreen
			s.setup()
			await V5bKit.settle(get_tree())
			_check(s, view, "settings (high contrast %s)" % high_contrast)


func test_the_briefing_with_every_kit_fits_every_viewport() -> void:
	for id: String in ["k_breacher", "k_signal", "k_gunline", "k_ledger", "k_gambler"]:
		Save.profile.unlocks.append(id)
	Save.profile.kit = &"k_gambler"
	for view: Vector2 in _sizes():
		var s: BriefingScreen = _screen(ScreensTestKit.BRIEFING, view) as BriefingScreen
		s.setup(_cs)
		await V5bKit.settle(get_tree())
		_check(s, view, "briefing")


func _summary(won: bool, big: bool) -> RunSummary:
	var s: RunSummary = V4uKit.summary(_cs, RunResult.Id.VICTORY if won else RunResult.Id.DEFEAT)
	s.run_seed = 2147483647
	s.waves_completed = 15
	s.act_reached = 3
	s.duration_ticks = 60 * 3600 * 9 + 59 * 3600 if big else 60 * 60 * 59  # 9:59:00 h of play, or 59 minutes
	s.core_hp = 1000 if won else 0
	s.data_reward = V5bKit.BIG if big else 1310
	for i: int in s.kills_by_type.size():
		s.kills_by_type[i] = 99999 if big else 999
	for i: int in s.core_damage_by_type.size():
		s.core_damage_by_type[i] = 99999.0 if big else 999.0
	for i: int in s.events_seen.size():
		s.events_seen[i] = 99
	for id: StringName in [&"hot_loads", &"cyclic_tuning", &"penetrator_cores", &"incendiary_tips", &"emp_capacitor", &"glass_cannon"]:
		var index: int = _cs.directive_index(id)
		if index >= 0 and index < s.directives.size():
			s.directives[index] = 5
	return s


func test_the_results_of_a_long_run_fit_every_viewport() -> void:
	for won: bool in [true, false]:
		for view: Vector2 in _sizes():
			var s: ResultsScreen = _screen(ScreensTestKit.RESULTS, view) as ResultsScreen
			var big: bool = view.x >= 1080.0
			s.setup(_summary(won, big), _cs, V4uKit.profile(V5bKit.BIG if big else 12500), true)
			s.show_milestones([
				{"id": &"ms_first_boss_siege_hulk", "data": 50}, {"id": &"ms_victory_kit_k_gambler", "data": 75},
				{"id": &"ms_first_boss_siege_hulk", "data": 500}, {"id": &"ms_victory_kit_k_gambler", "data": 750},
			])
			s.finish_count_up()
			await V5bKit.settle(get_tree())
			_check(s, view, "results (won %s)" % won)


func _archive(view: Vector2, data: int, owned: Array[String]) -> ArchiveScreen:
	var packed: PackedScene = load(V4uKit.ARCHIVE) as PackedScene
	var screen: ArchiveScreen = packed.instantiate() as ArchiveScreen
	UiOverflowKit.host(self, view).add_child(screen)
	screen.setup(_cs, ArchiveBank.new(V4uKit.profile(data, owned), _cs))
	return screen


func test_every_tab_of_the_archive_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var screen: ArchiveScreen = _archive(view, 40, [])
		for branch: int in ArchiveModel.BRANCHES:
			screen.select_branch(branch)
			await V5bKit.settle(get_tree(), 3)
			_check(screen, view, "archive tab %d" % branch)
		var rich: ArchiveScreen = _archive(view, V5bKit.BIG, ["u_w_hornet", "u_w_lmg", "u_p_blast", "k_breacher"])
		for branch: int in ArchiveModel.BRANCHES:
			rich.select_branch(branch)
			await V5bKit.settle(get_tree(), 3)
			_check(rich, view, "archive tab %d (rich)" % branch)


func test_the_pause_overlay_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var api: FakeRunApi = V5bKit.combat_api(_cs)
		RunSession.bind(api, _cs)
		var node: PauseOverlay = (load(V5bKit.PAUSE) as PackedScene).instantiate() as PauseOverlay
		V5bKit.host(self, view).add_child(node)
		node.setup()
		await V5bKit.settle(get_tree())
		_check(node, view, "pause")
		assert_bool(node.open_build()).is_true()
		await V5bKit.settle(get_tree())
		_check(node, view, "pause with the build list")
