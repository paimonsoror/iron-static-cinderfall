extends GdUnitTestSuite
## V4-U: the combat HUD additions (VARIETY_SPEC 11.4): the threat ticker's three lines and their priorities, the edge arrows, the
## boss bar's phase pips, SWAP ASSIST; and the pause overlay's seed line and BUILD button, the settings row. Every test runs on
## the variety fixture and a FakeRunApi.

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = V4uKit.content()


func after_test() -> void:
	ScreensTestKit.fresh_save()
	RunSession.bind(null, null)


func _ev(id: StringName, phase: int, harmful: bool, x: float = 0.0, z: float = 0.0) -> Dictionary:
	return {"id": id, "phase": phase, "ticks_left": 300, "ticks_total": 360, "harmful": harmful, "x": x, "z": z}


func _texts(ticker: HudThreatTicker) -> Array[String]:
	var out: Array[String] = []
	for line: HudTickerLine in ticker.lines:
		if line.visible:
			out.append(line.text_label.text)
	return out


# --- the threat ticker ---


func test_the_ticker_shows_three_lines_at_most() -> void:
	var ticker: HudThreatTicker = HudThreatTicker.new()
	add_child(ticker)
	auto_free(ticker)
	var events: Array[Dictionary] = [
		_ev(&"static_front", 0, true), _ev(&"floor_breach", 0, true), _ev(&"recount", 0, true), _ev(&"power_surge", 0, true),
	]
	ticker.refresh(events, _cs, {})
	assert_int(ticker.visible_lines()).is_equal(HudThreatTicker.MAX_LINES)
	assert_int(HudThreatTicker.MAX_LINES).is_equal(3)


func test_priorities_put_a_harmful_warning_first_then_the_crate_then_running_events() -> void:
	var ticker: HudThreatTicker = HudThreatTicker.new()
	add_child(ticker)
	auto_free(ticker)
	var events: Array[Dictionary] = [
		_ev(&"accord_window", 1, false), _ev(&"floor_breach", 1, true), _ev(&"static_front", 0, true),
	]
	var crate: Dictionary = {"contested": false, "ticks_left": 300, "ticks_total": 600}
	ticker.refresh(events, _cs, crate)
	var shown: Array[String] = _texts(ticker)
	assert_int(shown.size()).is_equal(3)
	assert_str(shown[0]).contains("STATIC FRONT")  # about to start and harmful
	assert_str(shown[1]).contains("ACCORD DROP")  # the crate in the clear
	assert_str(shown[2]).contains("FLOOR BREACH")  # running and harmful; the helpful running event is the one that waits


func test_a_contested_crate_outranks_a_crate_in_the_clear_and_notices_come_last() -> void:
	var ticker: HudThreatTicker = HudThreatTicker.new()
	add_child(ticker)
	auto_free(ticker)
	ticker.push_notice("ELITE: PLATED SKITTER")
	var contested: Dictionary = {"contested": true, "ticks_left": 300, "ticks_total": 600}
	ticker.refresh([_ev(&"accord_window", 1, false)], _cs, contested)
	var shown: Array[String] = _texts(ticker)
	assert_str(shown[0]).is_equal(Strings.t("hud.crate.contested"))
	assert_bool(ticker.lines[0].harmful).is_true()
	assert_str(shown[1]).contains("RELAY WINDOW")
	assert_str(shown[2]).contains("ELITE")
	ticker.refresh([_ev(&"static_front", 0, true), _ev(&"floor_breach", 0, true), _ev(&"recount", 0, true)], _cs, {})
	assert_bool(_texts(ticker).any(func(t: String) -> bool: return t.contains("ELITE"))).is_false()  # three real lines leave no room


func test_priority_numbers_follow_the_order_of_the_card() -> void:
	assert_int(HudThreatTicker.priority_of(true, true)).is_less(HudThreatTicker.PRIO_CRATE)
	assert_int(HudThreatTicker.PRIO_CRATE).is_less(HudThreatTicker.priority_of(false, true))
	assert_int(HudThreatTicker.priority_of(false, true)).is_less(HudThreatTicker.priority_of(true, false))
	assert_int(HudThreatTicker.priority_of(true, false)).is_less(HudThreatTicker.priority_of(false, false))
	assert_int(HudThreatTicker.priority_of(false, false)).is_less(HudThreatTicker.PRIO_NOTICE)


# --- the edge arrows ---


func _arrows(width: float = 1000.0, height: float = 1400.0) -> HudEdgeArrows:
	var node: HudEdgeArrows = HudEdgeArrows.new()
	node.size = Vector2(width, height)
	add_child(node)
	auto_free(node)
	return node


func test_an_arrow_sits_on_the_edge_toward_the_event_and_points_at_it() -> void:
	var arrows: HudEdgeArrows = _arrows()
	var identity: Callable = func(x: float, z: float) -> Vector2: return Vector2(x, z)
	arrows.refresh([_ev(&"recount", 0, true, -400.0, 700.0)], identity, Vector2.ZERO)  # far left of the middle
	assert_int(arrows.visible_count()).is_equal(1)
	var left: HudEdgeArrow = arrows.arrows[0]
	assert_float(left.position.x).is_less_equal(HudEdgeArrows.INSET + 1.0)
	assert_float(absf(left.angle)).is_greater(2.9)  # pointing left (pi)
	assert_str(left.word_label.text).is_equal(Strings.t("hud.arrow.recount"))
	arrows.refresh([_ev(&"floor_breach", 0, true, 500.0, -900.0)], identity, Vector2.ZERO)  # straight above
	var top: HudEdgeArrow = arrows.arrows[0]
	assert_float(top.position.y).is_less_equal(HudEdgeArrows.INSET + 1.0)
	assert_float(top.angle).is_less(-1.4)  # pointing up
	assert_str(top.word_label.text).is_equal(Strings.t("hud.arrow.breach"))
	arrows.refresh([_ev(&"floor_breach", 1, true, 5000.0, 700.0)], identity, Vector2.ZERO)  # far right
	assert_float(arrows.arrows[0].position.x + HudEdgeArrow.W).is_greater_equal(arrows.size.x - HudEdgeArrows.INSET - 1.0)


func test_an_arrow_stays_inside_the_zone_and_only_the_arriving_events_get_one() -> void:
	var arrows: HudEdgeArrows = _arrows()
	var identity: Callable = func(x: float, z: float) -> Vector2: return Vector2(x, z)
	var events: Array[Dictionary] = [
		_ev(&"static_front", 0, true, 0.0, 0.0), _ev(&"recount", 0, true, 20.0, 20.0), _ev(&"floor_breach", 0, true, 990.0, 1390.0),
		_ev(&"runaway_freight", 0, true, 500.0, 1390.0), _ev(&"recount", 1, true, 0.0, 700.0),
	]
	arrows.refresh(events, identity, Vector2.ZERO)
	assert_int(arrows.visible_count()).is_equal(HudEdgeArrows.MAX_ARROWS)  # static front has none; the fourth arriving one is dropped
	for arrow: HudEdgeArrow in arrows.arrows:
		assert_float(arrow.position.x).is_greater_equal(-0.5)
		assert_float(arrow.position.y).is_greater_equal(-0.5)
		assert_float(arrow.position.x + HudEdgeArrow.W).is_less_equal(arrows.size.x + 0.5)
		assert_float(arrow.position.y + HudEdgeArrow.H).is_less_equal(arrows.size.y + 0.5)
	arrows.refresh([], identity, Vector2.ZERO)
	assert_int(arrows.visible_count()).is_equal(0)


func test_the_hud_shows_an_arrow_for_a_floor_breach_and_none_for_a_static_front() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)
	await VarietyEKit.settle(get_tree())
	assert_int(hud.banners.edge_arrows.visible_count()).is_equal(0)  # the strike warning has no arrow
	api.fake_active_events = [_ev(&"floor_breach", 0, true, _cs.arena.max_x, _cs.arena.core_z)]
	hud.refresh()
	assert_int(hud.banners.edge_arrows.visible_count()).is_equal(1)
	var arrow: HudEdgeArrow = hud.banners.edge_arrows.arrows[0]
	assert_float(arrow.position.x).is_greater(hud.banners.edge_arrows.size.x * 0.5)  # the right-hand edge of the field
	api.fake_active_events = [_ev(&"static_front", 1, true)]
	hud.refresh()
	assert_int(hud.banners.edge_arrows.visible_count()).is_equal(0)


func test_the_legacy_hud_never_shows_arrows() -> void:
	var legacy: CombatHud = CombatHud.new()
	V4uKit.host(self, Vector2(1080.0, 1920.0)).add_child(legacy)
	var api: FakeRunApi = FakeRunApi.new()
	api.fake_active_events = [_ev(&"floor_breach", 0, true, 0.0, 0.0)]
	legacy.setup(api, TestContent.baseline(), null)
	legacy.refresh()
	assert_int(legacy.banners.edge_arrows.visible_count()).is_equal(0)


# --- the boss bar's phase pips ---


func test_the_pips_follow_the_phases_of_the_living_boss() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	api.fake_boss_hp = 1800.0
	api.fake_boss_max_hp = 2800.0
	api.fake_boss_phase = 1
	api.fake_boss_phase_count = 3
	var hud: CombatHud = VarietyEKit.hud(self, api)
	var pips: HudBossPips = hud.banners.boss_bar.pips
	assert_bool(hud.banners.boss_bar.visible).is_true()
	assert_bool(pips.visible).is_true()
	assert_int(pips.count).is_equal(3)
	assert_int(pips.phase).is_equal(1)
	assert_float(pips.custom_minimum_size.x).is_equal(HudBossPips.STEP * 3.0)
	api.fake_boss_phase = 2
	Events.boss_phase.emit(2)
	assert_int(pips.phase).is_equal(2)
	api.fake_boss_phase_count = 1
	hud.refresh()
	assert_bool(pips.visible).is_false()  # one phase: no pips
	api.fake_boss_hp = -1.0
	hud.refresh()
	assert_bool(hud.banners.boss_bar.visible).is_false()


# --- SWAP ASSIST ---


func _reloading(api: FakeRunApi, state: int) -> void:
	api.fake_weapon_slots[0]["state"] = state
	api.fake_weapon_slots[0]["ticks_left"] = 40 if state == RunApi.SLOT_RELOADING else 0


func test_swap_assist_swaps_once_when_the_active_weapon_starts_reloading() -> void:
	Save.profile.settings[&"swap_assist"] = true
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)
	assert_int(VarietyEKit.calls_of(api, "swap_weapon").size()).is_equal(0)
	_reloading(api, RunApi.SLOT_RELOADING)
	hud.refresh()
	var calls: Array[Dictionary] = VarietyEKit.calls_of(api, "swap_weapon")
	assert_int(calls.size()).is_equal(1)
	var arg: int = calls[0]["arg"]
	assert_int(arg).is_equal(1)  # to the holstered, ready weapon
	hud.refresh()
	hud.refresh()
	assert_int(VarietyEKit.calls_of(api, "swap_weapon").size()).is_equal(1)  # once per reload, not every poll


func test_swap_assist_is_silent_when_off_or_when_the_other_weapon_is_not_ready() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)
	_reloading(api, RunApi.SLOT_RELOADING)
	hud.refresh()
	assert_int(VarietyEKit.calls_of(api, "swap_weapon").size()).is_equal(0)  # off by default: only the hint pulses
	Save.profile.settings[&"swap_assist"] = true
	api.fake_weapon_slots[1]["state"] = RunApi.SLOT_RELOADING
	hud.refresh()
	assert_int(VarietyEKit.calls_of(api, "swap_weapon").size()).is_equal(0)  # nothing ready to swap to


func test_swap_assist_arms_again_after_the_reload_ends() -> void:
	Save.profile.settings[&"swap_assist"] = true
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)
	_reloading(api, RunApi.SLOT_RELOADING)
	hud.refresh()
	api.fake_active_slot = 0  # the fake keeps the slot it moved to; put the first weapon back in hand
	_reloading(api, RunApi.SLOT_READY)
	hud.refresh()
	_reloading(api, RunApi.SLOT_VENTING)
	hud.refresh()
	assert_int(VarietyEKit.calls_of(api, "swap_weapon").size()).is_equal(2)


# --- the settings row ---


func test_settings_offers_swap_assist_as_a_toggle() -> void:
	var s: SettingsScreen = ScreensTestKit.screen(self, ScreensTestKit.SETTINGS) as SettingsScreen
	s.setup()
	assert_bool(s.toggle_rows.has(&"swap_assist")).is_true()
	assert_bool(s.toggle_rows[&"swap_assist"].is_on()).is_false()
	assert_str(s.toggle_rows[&"swap_assist"].title_label.text).contains("SWAP")


# --- the pause overlay ---


func _pause() -> PauseOverlay:
	var node: PauseOverlay = (load("res://src/ui/combat/pause_overlay.tscn") as PackedScene).instantiate() as PauseOverlay
	V4uKit.host(self, Vector2(1080.0, 2400.0)).add_child(node)
	node.setup()
	return node


func test_the_pause_overlay_shows_the_seed_and_a_build_button_for_a_generated_run() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)  # the HUD registers its run
	assert_bool(RunSession.has_variety_run()).is_true()
	var pause: PauseOverlay = _pause()
	assert_bool(pause.seed_label.visible).is_true()
	assert_str(pause.seed_label.text).is_equal("SEED 48211")
	assert_bool(pause.build_button.visible).is_true()
	await VarietyEKit.settle(get_tree())
	assert_float(pause.build_button.size.y).is_greater_equal(132.0)
	pause.build_button.pressed.emit()
	assert_object(pause.build_list).is_not_null()
	assert_array(pause.build_list.weapon_rows.map(func(l: Label) -> String: return l.text)).is_not_empty()
	pause.build_list.close_button.pressed.emit()
	await VarietyEKit.settle(get_tree())
	assert_object(pause.build_list).is_null()
	assert_bool(is_instance_valid(hud)).is_true()


func test_the_pause_overlay_of_a_legacy_run_is_what_it_was() -> void:
	var legacy: CombatHud = CombatHud.new()
	V4uKit.host(self, Vector2(1080.0, 1920.0)).add_child(legacy)
	legacy.setup(FakeRunApi.new(), TestContent.baseline(), null)
	assert_bool(RunSession.has_variety_run()).is_false()
	var pause: PauseOverlay = _pause()
	assert_bool(pause.seed_label.visible).is_false()
	assert_bool(pause.build_button.visible).is_false()
	assert_bool(pause.open_build()).is_false()


func test_the_session_lets_go_when_the_hud_leaves() -> void:
	var api: FakeRunApi = VarietyEKit.api_for("combat2")
	var hud: CombatHud = VarietyEKit.hud(self, api)
	assert_object(RunSession.current_api()).is_same(api)
	hud.get_parent().remove_child(hud)
	assert_object(RunSession.current_api()).is_null()
	hud.free()
