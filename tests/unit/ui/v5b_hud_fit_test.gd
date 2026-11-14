extends GdUnitTestSuite
## V5-B: the combat HUD of a generated run fits every viewport in its worst state (the biggest numbers, three weapons in a
## state each, every call button live with FREIGHT, three ticker lines of the longest event names, a boss bar with its phase pips,
## the low-core line, a wave banner and a hint), with nothing leaving the viewport, no cut text and no two controls on top of
## each other (UiOverflowKit.problems). The shipped content and its real strings are used.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = Content.db


func after_test() -> void:
	ScreensTestKit.fresh_save()
	RunSession.bind(null, null)


## The HUD needs the 1080 px of the game's canvas (the top bar is 984 px wide at least, the ability row 936): the stretch mode
## `expand` never makes the canvas narrower, so the 900 and 720 px windows of the screen checks do not exist for the HUD.
func _sizes() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for view: Vector2 in UiOverflowKit.SIZES_V5B:
		if view.x >= 1080.0:
			out.append(view)
	out.append(UiOverflowKit.SIZE_WIDE)
	return out


func _check(h: CombatHud, view: Vector2, what: String) -> void:
	var message: String = V5bKit.verdict(h, view, what)
	assert_str(message).override_failure_message(message).is_empty()


func test_the_worst_combat_state_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var api: FakeRunApi = V5bKit.combat_api(_cs, view)
		var h: CombatHud = V5bKit.hud(self, api, _cs, view)
		await V5bKit.settle(get_tree())
		_check(h, view, "combat hud")


func test_each_weapon_in_hand_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		for active: int in 3:
			var api: FakeRunApi = V5bKit.combat_api(_cs, view)
			api.fake_active_slot = active
			var h: CombatHud = V5bKit.hud(self, api, _cs, view)
			await V5bKit.settle(get_tree())
			_check(h, view, "combat hud, slot %d in hand" % active)


func test_the_boss_bar_of_every_boss_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		for id: StringName in V5bKit.boss_ids(_cs):
			var api: FakeRunApi = V5bKit.combat_api(_cs, view)
			api.fake_boss_hp = 4000.0
			api.fake_boss_max_hp = 9000.0
			var h: CombatHud = V5bKit.hud(self, api, _cs, view)
			Events.boss_spawned.emit(1, id)
			await V5bKit.settle(get_tree())
			_check(h, view, "boss bar %s" % String(id))


func test_every_banner_the_game_can_show_fits_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var api: FakeRunApi = V5bKit.combat_api(_cs, view)
		var h: CombatHud = V5bKit.hud(self, api, _cs, view)
		await V5bKit.settle(get_tree())
		var failures: Array[String] = []
		for pair: PackedStringArray in V5bKit.banner_texts(_cs):
			h.banners.show_text(pair[0], pair[1], 0.0)
			await V5bKit.settle(get_tree(), 2)
			var message: String = V5bKit.verdict(h, view, "banner '%s' / '%s'" % [pair[0], pair[1]])
			if message != "":
				failures.append(message)
		assert_array(failures).override_failure_message("
".join(failures.slice(0, 4))).is_empty()


func test_the_low_core_line_a_hint_and_a_crowded_ticker_fit_every_viewport() -> void:
	for view: Vector2 in _sizes():
		var api: FakeRunApi = V5bKit.combat_api(_cs, view)
		api.fake_core_hp = 120.0
		api.fake_boss_hp = 9000.0
		api.fake_boss_max_hp = 9000.0
		var h: CombatHud = V5bKit.hud(self, api, _cs, view)
		h.banners.show_hint(Strings.t("hint.corrupted"))
		V5bKit.crowd_the_ticker(h)
		await V5bKit.settle(get_tree())
		_check(h, view, "low core, hint and ticker")
