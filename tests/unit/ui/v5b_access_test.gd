extends GdUnitTestSuite
## V5-B accessibility audit of what can be asserted (GDD 6.7, 10.3, 12.3): contrast of the text and key marks of the HUD and the
## screens against the surfaces they sit on, the 132 px touch target of every button of the real layouts, the 30 px text floor, and the
## cues that are never colour alone (shape and word beside every colour).

const PHONE: Vector2 = Vector2(1080.0, 2342.0)
const TEXT_MIN_RATIO: float = 4.5  ## GDD 10.3
const MARK_MIN_RATIO: float = 3.0  ## a bar, an icon or a rim against what is behind it (WCAG non-text)
const TEXT_FLOOR: int = 30  ## GDD 10: small text never under 30 px at the 1080 px design width
const TOUCH_MIN: float = 132.0

var _cs: ContentSet


func before_test() -> void:
	ScreensTestKit.fresh_save()
	_cs = Content.db


func after_test() -> void:
	ScreensTestKit.fresh_save()
	RunSession.bind(null, null)


static func _c(token: StringName) -> Color:
	return HudStyle.color(token)


## Over the 3D scene a panel's fill is only so dark: its alpha lets up to `alpha` of a white scene through (the worst case).
static func _over_scene(fill: Color, alpha: float) -> Color:
	return fill.lerp(Color.WHITE, 1.0 - alpha)


# --- contrast of text ---


func test_the_hud_text_colours_reach_4_5_to_1_on_their_panels() -> void:
	var fill: Color = HudStyle.fill()
	var amber: Color = _c(&"core_amber")
	var red: Color = _c(&"chorus_red")
	var cyan: Color = _c(&"warden_cyan")
	var bone: Color = _c(&"bone_ceramic")
	var pairs: Dictionary[String, Array] = {
		"names and labels (bone on panel)": [bone, fill],
		"a holstered weapon name (bone darkened 12%)": [bone.darkened(0.12), fill],
		"Scrap and call values (amber on panel)": [amber, fill],
		"READY and heat words (cyan on panel)": [cyan, fill],
		"dim values (gunmetal lightened 40%)": [_c(&"gunmetal").lightened(0.4), fill],
		"a locked call value on its dimmed plate": [_c(&"gunmetal").lightened(0.4), fill.darkened(0.25)],
		"the core warning and the boss percent (red lightened 30%)": [red.lightened(0.3), fill],
		"VENTING and a hot heat bar word (red lightened 20%)": [red.lightened(0.2), fill],
		"the active weapon card (amber text on its amber-tinted plate)": [amber, fill.lerp(amber, 0.16)],
		"the ticker, a harmful line (red lightened 35%)": [red.lightened(0.35), _over_scene(_c(&"obsidian"), 0.88)],
		"the ticker, a helpful line (cyan lightened 35%)": [cyan.lightened(0.35), _over_scene(_c(&"obsidian"), 0.88)],
		"the banner whisper and the HC labels (cyan inside their dark outline)": [cyan, _c(&"obsidian")],
		"the banner title (bone inside its dark outline)": [bone, _c(&"obsidian")],
	}
	var failures: Array[String] = []
	for what: String in pairs:
		var pair: Array = pairs[what]
		var fg: Color = pair[0]
		var bg: Color = pair[1]
		var ratio: float = UiTheme.contrast_ratio(fg, bg)
		if ratio < TEXT_MIN_RATIO:
			failures.append("%s: %.2f" % [what, ratio])
	assert_array(failures).override_failure_message("below 4.5:1: %s" % "; ".join(failures)).is_empty()


func test_the_screen_text_roles_reach_4_5_to_1_on_every_surface_in_both_themes() -> void:
	var failures: Array[String] = []
	for high_contrast: bool in [false, true]:
		for role: StringName in UiTheme.TEXT_ROLES:
			var fg: Color = UiTheme.text_color(role, high_contrast)
			var surfaces: Array[Color] = [UiTheme.panel_fill(high_contrast), UiTheme.inset_fill(high_contrast)]
			if role == &"on_accent":
				surfaces = [UiTheme.accent_fill(high_contrast)]
			for bg: Color in surfaces:
				var ratio: float = UiTheme.contrast_ratio(fg, bg)
				if ratio < TEXT_MIN_RATIO:
					failures.append("%s hc=%s %.2f" % [role, high_contrast, ratio])
	assert_array(failures).override_failure_message("below 4.5:1: %s" % "; ".join(failures)).is_empty()


# --- contrast of key marks ---


func test_the_key_marks_reach_3_to_1_against_what_they_sit_on() -> void:
	var trough: Color = _c(&"obsidian").darkened(0.2)
	var fill: Color = HudStyle.fill()
	var pairs: Dictionary[String, Array] = {
		"the core bar (amber on its trough)": [_c(&"core_amber"), trough],
		"a low core bar (red on its trough)": [_c(&"chorus_red"), trough],
		"a countdown or shield bar (cyan on its trough)": [_c(&"warden_cyan"), trough],
		"the boss bar red": [_c(&"chorus_red"), trough],
		"a harmful ticker icon (red on the plate)": [_c(&"chorus_red"), _c(&"obsidian")],
		"a helpful ticker icon (cyan on the plate)": [_c(&"warden_cyan"), _c(&"obsidian")],
		"a ready call button rim (cyan)": [_c(&"warden_cyan"), fill],
		"the active weapon rim (amber)": [_c(&"core_amber"), fill],
		"an edge arrow (red lightened 15% on a dark ground)": [_c(&"chorus_red").lightened(0.15), Color(0.10, 0.13, 0.16)],
		"the red optic of an enemy on its dark body": [_c(&"chorus_red"), Color(0.17, 0.19, 0.21)],
	}
	var failures: Array[String] = []
	for what: String in pairs:
		var pair: Array = pairs[what]
		var fg: Color = pair[0]
		var bg: Color = pair[1]
		var ratio: float = UiTheme.contrast_ratio(fg, bg)
		if ratio < MARK_MIN_RATIO:
			failures.append("%s: %.2f" % [what, ratio])
	assert_array(failures).override_failure_message("below 3:1: %s" % "; ".join(failures)).is_empty()


# --- touch targets and the text floor, from the real layouts ---


func _hud() -> CombatHud:
	return V5bKit.hud(self, V5bKit.combat_api(_cs, PHONE), _cs, PHONE)


func _screens() -> Array[Control]:
	var out: Array[Control] = []
	var menu: MainMenuScreen = ScreensTestKit.screen(self, ScreensTestKit.MENU, PHONE) as MainMenuScreen
	menu.setup(V4uKit.profile(1250))
	menu.set_resume_wave(3)
	menu.daily_button.visible = true
	out.append(menu)
	var settings: SettingsScreen = ScreensTestKit.screen(self, ScreensTestKit.SETTINGS, PHONE) as SettingsScreen
	settings.setup()
	out.append(settings)
	var briefing: BriefingScreen = ScreensTestKit.screen(self, ScreensTestKit.BRIEFING, PHONE) as BriefingScreen
	briefing.setup(_cs)
	out.append(briefing)
	var results: ResultsScreen = ScreensTestKit.screen(self, ScreensTestKit.RESULTS, PHONE) as ResultsScreen
	results.setup(V4uKit.summary(_cs), _cs, V4uKit.profile(130), true)
	results.finish_count_up()
	out.append(results)
	var archive: ArchiveScreen = ScreensTestKit.screen(self, V4uKit.ARCHIVE, PHONE) as ArchiveScreen
	archive.setup(_cs, ArchiveBank.new(V4uKit.profile(412, ["u_w_hornet"]), _cs))
	out.append(archive)
	RunSession.bind(V5bKit.combat_api(_cs, PHONE), _cs)
	var pause: PauseOverlay = (load(V5bKit.PAUSE) as PackedScene).instantiate() as PauseOverlay
	V5bKit.host(self, PHONE).add_child(pause)
	pause.setup()
	out.append(pause)
	for state: String in VarietyEKit.STATES:
		out.append(VarietyEKit.overlay(self, state, VarietyEKit.api_for(state), PHONE))
	return out


func _small_targets(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for n: Node in VarietyEKit.nodes_of(root, BaseButton):
		var b: BaseButton = n as BaseButton
		if b.is_visible_in_tree() and (b.size.x < TOUCH_MIN or b.size.y < TOUCH_MIN):
			bad.append("%s %s" % [b.get_path(), b.size])
	for n: Node in VarietyEKit.nodes_of(root, RunSelectable):
		var s: RunSelectable = n as RunSelectable
		if s.is_visible_in_tree() and s.selectable and (s.size.x < TOUCH_MIN or s.size.y < TOUCH_MIN):
			bad.append("%s %s" % [s.get_path(), s.size])
	return bad


func _small_text(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for l: Label in UiKit.labels(root):
		if l.is_visible_in_tree() and l.text.strip_edges() != "" and l.get_theme_font_size(&"font_size") < TEXT_FLOOR:
			bad.append("%s '%s' %d px" % [l.get_path(), l.text.left(24), l.get_theme_font_size(&"font_size")])
	for b: Button in UiKit.buttons(root):
		if b.is_visible_in_tree() and b.text.strip_edges() != "" and b.get_theme_font_size(&"font_size") < TEXT_FLOOR:
			bad.append("%s '%s' %d px" % [b.get_path(), b.text.left(24), b.get_theme_font_size(&"font_size")])
	return bad


func test_every_button_of_the_hud_and_every_screen_is_at_least_132_px() -> void:
	var roots: Array[Control] = _screens()
	roots.append(_hud())
	await V5bKit.settle(get_tree())
	var failures: Array[String] = []
	for root: Control in roots:
		failures.append_array(_small_targets(root))
	assert_array(failures).override_failure_message("touch targets under 132 px: %s" % "\n".join(failures.slice(0, 10))).is_empty()


func test_no_text_of_the_hud_or_a_screen_is_under_30_px() -> void:
	var roots: Array[Control] = _screens()
	roots.append(_hud())
	await V5bKit.settle(get_tree())
	var failures: Array[String] = []
	for root: Control in roots:
		failures.append_array(_small_text(root))
	assert_array(failures).override_failure_message("text under 30 px: %s" % "\n".join(failures.slice(0, 12))).is_empty()


# --- never colour alone ---


func test_a_harmful_ticker_line_and_a_helpful_one_differ_in_shape_not_only_in_colour() -> void:
	var line: HudTickerLine = HudTickerLine.new()
	add_child(line)
	auto_free(line)
	line.show_line("STATIC FRONT IN 5 s", true, 0.5)
	var warn: Texture2D = line.icon_rect.texture
	line.show_line("RELAY WINDOW 9 s", false, 0.5)
	var help: Texture2D = line.icon_rect.texture
	assert_object(warn).is_not_null()
	assert_object(help).is_not_null()
	assert_object(warn).is_not_same(help)
	assert_str(line.text_label.text).is_not_empty()


func test_every_weapon_state_has_a_word_and_the_timed_ones_a_bar() -> void:
	var card: HudWeaponCard = HudWeaponCard.new(0)
	add_child(card)
	auto_free(card)
	for state: int in [RunApi.SLOT_READY, RunApi.SLOT_RELOADING, RunApi.SLOT_VENTING, RunApi.SLOT_SWAPPING, RunApi.SLOT_CHARGING]:
		card.show_slot(V5bKit.slot(&"smg", 1, state, 0, 0), true, false)
		assert_str(card.status_label.text).override_failure_message("state %d has no word" % state).is_not_empty()
		if state != RunApi.SLOT_READY:
			assert_bool(card.bar.visible).override_failure_message("state %d has no bar" % state).is_true()
	card.show_slot({"id": &"", "state": RunApi.SLOT_EMPTY}, false, false)
	assert_str(card.status_label.text).is_not_empty()


func test_a_locked_call_says_why_in_words() -> void:
	var button: HudCallButton = HudCallButton.new(&"deadfall_strike", &"call_strike", "hud.call.strike")
	add_child(button)
	auto_free(button)
	button.show_state(false, "x0", Strings.t("hud.ability.offline"))
	assert_str(button.name_label.text).is_equal(Strings.t("hud.ability.offline"))
	assert_str(Strings.t("hud.ability.offline")).is_equal("OFFLINE")
