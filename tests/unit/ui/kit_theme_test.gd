extends GdUnitTestSuite
## UiTheme: palette roles, 4.5:1 text contrast (normal and High Contrast), chamfered panels, variations.

const BUTTON_TYPES: Array[StringName] = [&"Button", UiTheme.BUTTON_PRIMARY, UiTheme.BUTTON_QUIET, UiTheme.BUTTON_SEGMENT]
const LABEL_TYPES: Array[StringName] = [
	&"Label", UiTheme.LABEL_DIM, UiTheme.LABEL_CAPTION, UiTheme.LABEL_ACCENT, UiTheme.LABEL_FRIENDLY,
	UiTheme.LABEL_DANGER, UiTheme.LABEL_HEADING, UiTheme.LABEL_TITLE, UiTheme.LABEL_NUMBER, &"Mono",
]
const LIGHT_ROLES: Array[StringName] = [&"body", &"dim", &"accent", &"friendly", &"danger"]
## Button states: stylebox name and the font color slot that is drawn on it.
const BUTTON_STATES: Dictionary = {
	"normal": "font_color", "hover": "font_hover_color", "pressed": "font_pressed_color",
	"hover_pressed": "font_hover_pressed_color", "disabled": "font_disabled_color",
}


func _theme(high_contrast: bool) -> Theme:
	return UiTheme.build(TestContent.baseline().tokens, high_contrast)


func _fill_of(theme: Theme, type_name: StringName, state: String) -> Color:
	var box: StyleBoxFlat = theme.get_stylebox(state, type_name) as StyleBoxFlat
	return box.bg_color


## The font color a Label of `type_name` draws (a variation without its own color inherits its base type's).
func _font_color(theme: Theme, type_name: StringName) -> Color:
	if theme.has_color("font_color", type_name):
		return theme.get_color("font_color", type_name)
	return theme.get_color("font_color", theme.get_type_variation_base(type_name))


func _assert_color(actual: Color, expected: Color) -> void:
	assert_bool(actual.is_equal_approx(expected)).override_failure_message("%s != %s" % [actual, expected]).is_true()


func test_the_contract_sizes_and_palette_tokens_are_unchanged() -> void:
	assert_int(UiTheme.TOUCH_MIN).is_equal(132)
	assert_int(UiTheme.BTN_PRIMARY_H).is_equal(148)
	assert_int(UiTheme.FONT_SMALL).is_equal(30)
	assert_int(UiTheme.FONT_BODY).is_equal(38)
	assert_int(UiTheme.FONT_LARGE).is_equal(52)
	assert_int(UiTheme.FONT_TITLE).is_equal(84)
	var t: Theme = _theme(false)
	assert_object(t).is_not_null()
	assert_object(t.default_font).is_not_null()
	assert_int(t.default_font_size).is_equal(38)
	assert_str(UiTheme.color(&"warden_cyan").to_html(false).to_upper()).is_equal("39C9DB")
	assert_str(UiTheme.color(&"core_amber").to_html(false).to_upper()).is_equal("F1A34A")
	assert_str(UiTheme.color(&"no_such_token").to_html(false)).is_equal(Color.MAGENTA.to_html(false))


func test_contrast_ratio_and_readable_behave() -> void:
	assert_float(UiTheme.contrast_ratio(Color.WHITE, Color.BLACK)).is_equal_approx(21.0, 0.01)
	assert_float(UiTheme.contrast_ratio(Color.RED, Color.RED)).is_equal_approx(1.0, 0.001)
	var panel: Color = UiTheme.panel_fill(false)
	var gun: Color = UiTheme.color(&"gunmetal")
	assert_float(UiTheme.contrast_ratio(gun, panel)).is_less(4.5)  # raw gunmetal is a frame color, not a text color
	assert_float(UiTheme.contrast_ratio(UiTheme.readable(gun, panel), panel)).is_greater_equal(4.5)
	_assert_color(UiTheme.readable(Color.WHITE, Color.BLACK), Color.WHITE)


func test_every_light_text_role_reaches_4_5_to_1_on_every_surface_in_both_modes() -> void:
	_theme(false)
	for hc: bool in [false, true]:
		var surfaces: Array[Color] = [
			UiTheme.panel_fill(hc), UiTheme.inset_fill(hc), UiTheme.button_fill(hc), UiTheme.button_fill(hc, true),
		]
		for role: StringName in LIGHT_ROLES:
			# danger (red) is for panels, wells and the backdrop, never on a button fill
			for surface: Color in (surfaces.slice(0, 2) if role == &"danger" else surfaces):
				assert_float(UiTheme.contrast_ratio(UiTheme.text_color(role, hc), surface)) \
					.override_failure_message("%s hc=%s on %s" % [role, hc, surface]) \
					.is_greater_equal(UiTheme.MIN_CONTRAST)


func test_dark_text_on_the_amber_and_cyan_plates_reaches_4_5_to_1() -> void:
	for hc: bool in [false, true]:
		var dark: Color = UiTheme.text_color(&"on_accent", hc)
		var plates: Array[Color] = [
			UiTheme.accent_fill(hc), UiTheme.accent_fill(hc, true), UiTheme.accent_fill(hc).darkened(0.18),
			UiTheme.rim(&"warden_cyan", hc),
		]
		for plate: Color in plates:
			assert_float(UiTheme.contrast_ratio(dark, plate)).is_greater_equal(UiTheme.MIN_CONTRAST)


func test_the_built_label_colors_reach_4_5_to_1_on_the_panel_backgrounds() -> void:
	for hc: bool in [false, true]:
		var t: Theme = _theme(hc)
		var panels: Array[Color] = [
			_fill_of(t, &"PanelContainer", "panel"), _fill_of(t, UiTheme.PANEL_INSET, "panel"),
			_fill_of(t, UiTheme.PANEL_PLATE, "panel"), _fill_of(t, UiTheme.PANEL_RAISED, "panel"),
		]
		for type_name: StringName in LABEL_TYPES:
			var text: Color = _font_color(t, type_name)
			for bg: Color in panels:
				assert_float(UiTheme.contrast_ratio(text, bg)) \
					.override_failure_message("%s hc=%s on %s" % [type_name, hc, bg]) \
					.is_greater_equal(UiTheme.MIN_CONTRAST)


func test_every_built_button_state_has_4_5_to_1_text_on_its_own_fill() -> void:
	for hc: bool in [false, true]:
		var t: Theme = _theme(hc)
		for type_name: StringName in BUTTON_TYPES:
			for state: String in BUTTON_STATES:
				var slot: String = BUTTON_STATES[state]
				var text: Color = t.get_color(slot, type_name)
				var fill: Color = _fill_of(t, type_name, state)
				assert_float(UiTheme.contrast_ratio(text, fill)) \
					.override_failure_message("%s.%s hc=%s" % [type_name, state, hc]) \
					.is_greater_equal(UiTheme.MIN_CONTRAST)


func test_panels_are_chamfered_dark_plates_with_a_cyan_rim_and_amber_or_red_variations() -> void:
	var t: Theme = _theme(false)
	var panel: StyleBoxFlat = t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_int(panel.corner_detail).is_equal(1)
	assert_int(panel.corner_radius_top_left).is_greater(0)
	assert_int(panel.corner_radius_bottom_right).is_greater(0)
	_assert_color(panel.border_color, UiTheme.color(&"warden_cyan"))
	assert_float(panel.bg_color.get_luminance()).is_less(0.2)  # dark
	var raised: StyleBoxFlat = t.get_stylebox("panel", UiTheme.PANEL_RAISED) as StyleBoxFlat
	_assert_color(raised.border_color, UiTheme.color(&"core_amber"))
	var danger: StyleBoxFlat = t.get_stylebox("panel", UiTheme.PANEL_DANGER) as StyleBoxFlat
	_assert_color(danger.border_color, UiTheme.color(&"chorus_red"))
	var primary: StyleBoxFlat = t.get_stylebox("normal", UiTheme.BUTTON_PRIMARY) as StyleBoxFlat
	_assert_color(primary.bg_color, UiTheme.color(&"core_amber"))
	assert_int(primary.corner_detail).is_equal(1)


func test_high_contrast_is_white_text_with_outlines_and_thicker_brighter_rims() -> void:
	var normal: Theme = _theme(false)
	var high: Theme = _theme(true)
	_assert_color(high.get_color("font_color", "Label"), Color.WHITE)
	assert_int(high.get_constant("outline_size", "Label")).is_equal(4)
	assert_int(normal.get_constant("outline_size", "Label")).is_equal(0)
	var n_box: StyleBoxFlat = normal.get_stylebox("normal", "Button") as StyleBoxFlat
	var h_box: StyleBoxFlat = high.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_int(h_box.border_width_left).is_greater(n_box.border_width_left)
	assert_float(h_box.border_color.get_luminance()).is_greater(n_box.border_color.get_luminance())
	var n_ratio: float = UiTheme.contrast_ratio(normal.get_color("font_color", "Label"), UiTheme.panel_fill(false))
	var h_ratio: float = UiTheme.contrast_ratio(high.get_color("font_color", "Label"), UiTheme.panel_fill(true))
	assert_float(h_ratio).is_greater_equal(n_ratio)


func test_the_type_variations_the_screens_use_exist_on_the_right_base_types() -> void:
	var t: Theme = _theme(false)
	for v: StringName in [UiTheme.LABEL_DIM, UiTheme.LABEL_CAPTION, UiTheme.LABEL_ACCENT, UiTheme.LABEL_FRIENDLY,
			UiTheme.LABEL_DANGER, UiTheme.LABEL_HEADING, UiTheme.LABEL_TITLE, UiTheme.LABEL_NUMBER, &"Mono"]:
		assert_str(String(t.get_type_variation_base(v))).is_equal("Label")
	for v: StringName in [UiTheme.BUTTON_PRIMARY, UiTheme.BUTTON_QUIET, UiTheme.BUTTON_SEGMENT]:
		assert_str(String(t.get_type_variation_base(v))).is_equal("Button")
	for v: StringName in [UiTheme.PANEL_RAISED, UiTheme.PANEL_INSET, UiTheme.PANEL_PLATE, UiTheme.PANEL_DANGER]:
		assert_str(String(t.get_type_variation_base(v))).is_equal("PanelContainer")
	for v: StringName in [UiTheme.BAR_CYAN, UiTheme.BAR_DANGER]:
		assert_str(String(t.get_type_variation_base(v))).is_equal("ProgressBar")
	assert_object(t.get_font("font", &"Mono")).is_same(UiTheme.mono_font())
	assert_object(t.get_font("font", UiTheme.LABEL_TITLE)).is_same(UiTheme.bold_font())


func test_the_shared_theme_is_cached_per_flag() -> void:
	var a: Theme = UiTheme.shared(false)
	assert_object(UiTheme.shared(false)).is_same(a)
	assert_object(UiTheme.shared(true)).is_not_same(a)
	assert_object(UiTheme.shared(true)).is_same(UiTheme.shared(true))
