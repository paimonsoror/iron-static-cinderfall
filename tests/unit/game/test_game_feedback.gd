extends GdUnitTestSuite
## GameFeedback: the three first-run hints (once per profile, filtered by Save) and the haptic ticks.

var _log: GameSignalLog
var _fb: GameFeedback


func before_test() -> void:
	GameRunKit.fresh_save()
	_log = GameSignalLog.new()
	_log.attach()
	_fb = GameFeedback.new()
	_fb.attach(TestContent.baseline())


func after_test() -> void:
	_fb.detach()
	_log.detach()
	GameRunKit.reset_save()


func test_the_scrap_hint_shows_at_the_price_of_the_cheapest_upgrade_and_only_once() -> void:
	assert_int(_fb.scrap_threshold).is_equal(150)  # baseline: fire_rate costs 150
	Events.scrap_changed.emit(149)
	assert_int(_log.count(&"hint_requested")).is_equal(0)
	Events.scrap_changed.emit(150)
	assert_array(_log.first_args(&"hint_requested")).is_equal(["hint.tap_upgrades"])
	Events.scrap_changed.emit(400)
	Events.scrap_changed.emit(150)
	assert_int(_log.count(&"hint_requested")).is_equal(1)
	assert_bool(Save.has_seen_hint("hint.tap_upgrades")).is_true()


func test_the_core_hit_hint_shows_on_the_first_hit_only() -> void:
	Events.core_hit.emit(3, &"skitter", 12.0, 0.0)
	Events.core_hit.emit(4, &"rusher", 28.0, 0.0)
	assert_int(_log.count(&"hint_requested")).is_equal(1)
	assert_array(_log.first_args(&"hint_requested")).is_equal(["hint.core_hit"])


func test_the_intermission_hint_shows_on_the_first_intermission_only() -> void:
	Events.intermission_started.emit(1, 480)
	Events.intermission_started.emit(2, 480)
	assert_int(_log.count(&"hint_requested")).is_equal(1)
	assert_array(_log.first_args(&"hint_requested")).is_equal(["hint.intermission"])


func test_a_hint_the_profile_has_seen_is_never_forwarded() -> void:
	Save.mark_hint_seen("hint.core_hit")
	Events.core_hit.emit(3, &"skitter", 12.0, 0.0)
	assert_int(_log.count(&"hint_requested")).is_equal(0)


func test_hints_stay_seen_across_a_restart_of_the_profile() -> void:
	Events.intermission_started.emit(1, 480)
	Save.load_profile()  # reloads from the in-memory file
	_log.clear()
	Events.intermission_started.emit(1, 480)
	assert_int(_log.count(&"hint_requested")).is_equal(0)


func test_each_hint_is_independent() -> void:
	Events.scrap_changed.emit(500)
	Events.core_hit.emit(1, &"skitter", 5.0, 0.0)
	Events.intermission_started.emit(1, 480)
	var shown: Array[String] = []
	for r: Dictionary in _log.rows:
		if r["name"] == &"hint_requested":
			var a: Array = r["args"]
			shown.append(str(a[0]))
	assert_array(shown).is_equal(["hint.tap_upgrades", "hint.core_hit", "hint.intermission"])
	assert_int(Save.profile.hints_seen.size()).is_equal(3)


func test_request_hint_reports_whether_it_asked_the_hud() -> void:
	assert_bool(_fb.request_hint("hint.tap_upgrades")).is_true()
	assert_bool(_fb.request_hint("hint.tap_upgrades")).is_false()


func test_detach_removes_every_connection_and_attach_does_not_double_them() -> void:
	_fb.detach()
	var base: int = GameSignalLog.events_connection_count()
	_fb.attach(TestContent.baseline())
	var attached: int = GameSignalLog.events_connection_count()
	assert_int(attached).is_greater(base)
	assert_int(attached - base).is_equal(_fb.connection_count())
	_fb.attach(TestContent.baseline())
	assert_int(GameSignalLog.events_connection_count()).is_equal(attached)
	_fb.detach()
	assert_int(GameSignalLog.events_connection_count()).is_equal(base)
	Events.scrap_changed.emit(500)
	assert_int(_log.count(&"hint_requested")).is_equal(0)


func test_haptics_do_nothing_off_android() -> void:
	assert_bool(Haptics.enabled()).is_false()
	Haptics.tick()  # must not crash on desktop
	Events.purchase_resolved.emit(1, true, Reason.Id.OK)
	Events.boss_spawned.emit(9, &"siege_hulk")
