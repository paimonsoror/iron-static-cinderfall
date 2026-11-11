class_name UiThemeBuilder
extends RefCounted
## Fills a Theme with the label, button, panel, bar and scroll-bar styles of UiTheme (ARCH 9). Split out of UiTheme to
## keep each file under 400 lines; UiTheme.build() is the only caller.


## Adds every style and type variation of UiTheme to `t` (fonts and default size are set by the caller).
static func apply(t: Theme, hc: bool) -> void:
	_build_labels(t, hc)
	_build_buttons(t, hc)
	_build_panels(t, hc)
	_build_bars(t, hc)
	_build_misc(t, hc)


static func _build_labels(t: Theme, hc: bool) -> void:
	t.set_font("font", "Label", UiTheme.body_font())
	t.set_font_size("font_size", "Label", UiTheme.FONT_BODY)
	t.set_color("font_color", "Label", UiTheme.text_color(&"body", hc))
	if hc:
		t.set_constant("outline_size", "Label", 4)
		t.set_color("font_outline_color", "Label", UiTheme.alpha(UiTheme.color(&"obsidian"), 0.95))
	_label_variant(t, UiTheme.LABEL_DIM, UiTheme.text_color(&"dim", hc), UiTheme.FONT_BODY, null)
	_label_variant(t, UiTheme.LABEL_CAPTION, UiTheme.text_color(&"dim", hc), UiTheme.FONT_SMALL, null)
	_label_variant(t, UiTheme.LABEL_ACCENT, UiTheme.text_color(&"accent", hc), UiTheme.FONT_BODY, UiTheme.bold_font())
	_label_variant(t, UiTheme.LABEL_FRIENDLY, UiTheme.text_color(&"friendly", hc), UiTheme.FONT_BODY, UiTheme.bold_font())
	_label_variant(t, UiTheme.LABEL_DANGER, UiTheme.text_color(&"danger", hc), UiTheme.FONT_BODY, UiTheme.bold_font())
	_label_variant(t, UiTheme.LABEL_HEADING, UiTheme.text_color(&"body", hc), UiTheme.FONT_LARGE, UiTheme.bold_font())
	_label_variant(t, UiTheme.LABEL_TITLE, UiTheme.text_color(&"body", hc), UiTheme.FONT_TITLE, UiTheme.bold_font())
	_label_variant(t, UiTheme.LABEL_NUMBER, UiTheme.text_color(&"accent", hc), UiTheme.FONT_LARGE, UiTheme.mono_font())
	t.add_type(&"Mono")
	t.set_type_variation(&"Mono", &"Label")
	t.set_font("font", &"Mono", UiTheme.mono_font())


static func _label_variant(t: Theme, variant: StringName, col: Color, size: int, font: Font) -> void:
	t.set_type_variation(variant, &"Label")
	t.set_color("font_color", variant, col)
	t.set_font_size("font_size", variant, size)
	if font != null:
		t.set_font("font", variant, font)


static func _build_buttons(t: Theme, hc: bool) -> void:
	var w: int = UiTheme.rim_width(hc)
	var cyan: Color = UiTheme.rim(&"warden_cyan", hc)
	var amber: Color = UiTheme.rim(&"core_amber", hc)
	var gun: Color = UiTheme.rim(&"gunmetal", hc)
	t.set_font("font", "Button", UiTheme.bold_font())
	t.set_font_size("font_size", "Button", UiTheme.FONT_LARGE)
	_button_states(t, "Button", {
		"normal": UiTheme.chamfer_box(UiTheme.button_fill(hc), cyan, UiTheme.CHAMFER, w),
		"hover": UiTheme.chamfer_box(UiTheme.button_fill(hc, true), cyan.lightened(0.2), UiTheme.CHAMFER, w),
		"pressed": UiTheme.chamfer_box(UiTheme.panel_fill(hc), amber, UiTheme.CHAMFER, w),
		"disabled": UiTheme.chamfer_box(UiTheme.panel_fill(hc), gun, UiTheme.CHAMFER, w),
		"hover_pressed": UiTheme.chamfer_box(UiTheme.panel_fill(hc), amber, UiTheme.CHAMFER, w),
	}, {
		"font_color": UiTheme.text_color(&"body", hc),
		"font_hover_color": UiTheme.text_color(&"friendly", hc),
		"font_pressed_color": UiTheme.text_color(&"accent", hc),
		"font_hover_pressed_color": UiTheme.text_color(&"accent", hc),
		"font_focus_color": UiTheme.text_color(&"body", hc),
		"font_disabled_color": UiTheme.text_color(&"dim", hc),
	})
	var on_accent: Color = UiTheme.text_color(&"on_accent", hc)
	t.set_type_variation(UiTheme.BUTTON_PRIMARY, &"Button")
	_button_states(t, UiTheme.BUTTON_PRIMARY, {
		"normal": UiTheme.chamfer_box(UiTheme.accent_fill(hc), amber.lightened(0.25), UiTheme.CHAMFER, w),
		"hover": UiTheme.chamfer_box(UiTheme.accent_fill(hc, true), Color.WHITE, UiTheme.CHAMFER, w),
		"pressed": UiTheme.chamfer_box(UiTheme.accent_fill(hc).darkened(0.18), amber, UiTheme.CHAMFER, w),
		"disabled": UiTheme.chamfer_box(UiTheme.panel_fill(hc), gun, UiTheme.CHAMFER, w),
		"hover_pressed": UiTheme.chamfer_box(UiTheme.accent_fill(hc).darkened(0.18), amber, UiTheme.CHAMFER, w),
	}, {
		"font_color": on_accent,
		"font_hover_color": on_accent,
		"font_pressed_color": on_accent,
		"font_hover_pressed_color": on_accent,
		"font_focus_color": on_accent,
		"font_disabled_color": UiTheme.text_color(&"dim", hc),
	})
	t.set_type_variation(UiTheme.BUTTON_QUIET, &"Button")
	_button_states(t, UiTheme.BUTTON_QUIET, {
		"normal": UiTheme.chamfer_box(UiTheme.panel_fill(hc), gun, UiTheme.CHAMFER, w),
		"hover": UiTheme.chamfer_box(UiTheme.button_fill(hc), cyan, UiTheme.CHAMFER, w),
		"pressed": UiTheme.chamfer_box(UiTheme.inset_fill(hc), amber, UiTheme.CHAMFER, w),
		"disabled": UiTheme.chamfer_box(UiTheme.panel_fill(hc), gun, UiTheme.CHAMFER, w),
		"hover_pressed": UiTheme.chamfer_box(UiTheme.inset_fill(hc), amber, UiTheme.CHAMFER, w),
	}, {
		"font_color": UiTheme.text_color(&"body", hc),
		"font_hover_color": UiTheme.text_color(&"friendly", hc),
		"font_pressed_color": UiTheme.text_color(&"accent", hc),
		"font_hover_pressed_color": UiTheme.text_color(&"accent", hc),
		"font_focus_color": UiTheme.text_color(&"body", hc),
		"font_disabled_color": UiTheme.text_color(&"dim", hc),
	})
	# A toggle or one option of a segmented row: hollow when off, a filled cyan plate with dark text when on.
	var selected: StyleBoxFlat = UiTheme.chamfer_box(cyan, cyan.lightened(0.3), 12, w)
	t.set_type_variation(UiTheme.BUTTON_SEGMENT, &"Button")
	_button_states(t, UiTheme.BUTTON_SEGMENT, {
		"normal": UiTheme.chamfer_box(UiTheme.inset_fill(hc), gun, 12, w),
		"hover": UiTheme.chamfer_box(UiTheme.button_fill(hc), cyan, 12, w),
		"pressed": selected,
		"disabled": UiTheme.chamfer_box(UiTheme.panel_fill(hc), gun, 12, w),
		"hover_pressed": selected,
	}, {
		"font_color": UiTheme.text_color(&"dim", hc),
		"font_hover_color": UiTheme.text_color(&"body", hc),
		"font_pressed_color": on_accent,
		"font_hover_pressed_color": on_accent,
		"font_focus_color": UiTheme.text_color(&"dim", hc),
		"font_disabled_color": UiTheme.text_color(&"dim", hc),
	})


static func _button_states(t: Theme, type_name: StringName, boxes: Dictionary, colors: Dictionary) -> void:
	for state: Variant in boxes.keys():
		var state_name: String = state
		var box: StyleBox = boxes[state]
		t.set_stylebox(state_name, type_name, box)
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for slot: Variant in colors.keys():
		var slot_name: String = slot
		var c: Color = colors[slot]
		t.set_color(slot_name, type_name, c)


static func _build_panels(t: Theme, hc: bool) -> void:
	var w: int = UiTheme.rim_width(hc)
	var fill: Color = UiTheme.panel_fill(hc)
	t.set_stylebox("panel", "PanelContainer", _glow(UiTheme.chamfer_box(fill, UiTheme.rim(&"warden_cyan", hc), UiTheme.CHAMFER, w), hc))
	t.set_stylebox("panel", "Panel", UiTheme.chamfer_box(fill, UiTheme.rim(&"warden_cyan", hc), UiTheme.CHAMFER, w))
	t.set_type_variation(UiTheme.PANEL_RAISED, &"PanelContainer")
	t.set_stylebox("panel", UiTheme.PANEL_RAISED, _glow(UiTheme.chamfer_box(fill, UiTheme.rim(&"core_amber", hc), UiTheme.CHAMFER, w), hc))
	t.set_type_variation(UiTheme.PANEL_INSET, &"PanelContainer")
	t.set_stylebox("panel", UiTheme.PANEL_INSET, UiTheme.chamfer_box(UiTheme.inset_fill(hc), UiTheme.rim(&"gunmetal", hc), 12, maxi(w - 1, 2)))
	t.set_type_variation(UiTheme.PANEL_DANGER, &"PanelContainer")
	t.set_stylebox("panel", UiTheme.PANEL_DANGER, _glow(UiTheme.chamfer_box(fill, UiTheme.rim(&"chorus_red", hc), UiTheme.CHAMFER, w), hc))
	# The header plate of armory_style.png: a long plate, cut hard at two opposite corners.
	t.set_type_variation(UiTheme.PANEL_PLATE, &"PanelContainer")
	var plate: StyleBoxFlat = UiTheme.corner_box(UiTheme.inset_fill(hc), UiTheme.rim(&"warden_cyan", hc), 26, 8, 26, 8, w)
	plate.content_margin_left = 48.0
	plate.content_margin_right = 48.0
	plate.content_margin_top = 16.0
	plate.content_margin_bottom = 16.0
	t.set_stylebox("panel", UiTheme.PANEL_PLATE, plate)


## A faint cyan or amber halo around a panel (skipped in High Contrast, where the rim does the work).
static func _glow(sb: StyleBoxFlat, hc: bool) -> StyleBoxFlat:
	if not hc:
		sb.shadow_color = UiTheme.alpha(sb.border_color, 0.22)
		sb.shadow_size = 8
	return sb


static func _build_bars(t: Theme, hc: bool) -> void:
	var back: StyleBoxFlat = UiTheme.chamfer_box(UiTheme.inset_fill(hc), UiTheme.rim(&"gunmetal", hc), 4, 2)
	back.content_margin_left = 0.0
	back.content_margin_right = 0.0
	back.content_margin_top = 0.0
	back.content_margin_bottom = 0.0
	t.set_stylebox("background", "ProgressBar", back)
	t.set_stylebox("fill", "ProgressBar", _bar_fill(UiTheme.rim(&"core_amber", hc)))
	t.set_type_variation(UiTheme.BAR_CYAN, &"ProgressBar")
	t.set_stylebox("fill", UiTheme.BAR_CYAN, _bar_fill(UiTheme.rim(&"warden_cyan", hc)))
	t.set_type_variation(UiTheme.BAR_DANGER, &"ProgressBar")
	t.set_stylebox("fill", UiTheme.BAR_DANGER, _bar_fill(UiTheme.color(&"chorus_red")))


static func _bar_fill(c: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	sb.corner_detail = 1
	return sb


static func _build_misc(t: Theme, hc: bool) -> void:
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = UiTheme.alpha(UiTheme.rim(&"gunmetal", hc), 0.7)
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 12)
	for part: String in ["scroll", "scroll_focus"]:
		t.set_stylebox(part, "VScrollBar", StyleBoxEmpty.new())
	var grab: StyleBoxFlat = StyleBoxFlat.new()
	grab.bg_color = UiTheme.alpha(UiTheme.rim(&"core_amber", hc), 0.55)
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 5.0
	grab.content_margin_right = 5.0
	for part: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(part, "VScrollBar", grab)
