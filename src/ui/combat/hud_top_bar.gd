class_name HudTopBar
extends Control
## The top band: pause button, core bar with percent, number and shield overlay, WAVE n/5 and Scrap
## (GDD 10.1). Its content sits below the safe-area inset; the band itself reaches the screen edge.

signal pause_pressed

var pause_button: Button
var core_label: Label
var core_value_label: Label
var core_bar: HudBar
var wave_label: Label
var scrap_label: Label
var shield_icon: TextureRect  ## variety: the shield mark that replaces the "SHIELD +n" text
var variety: bool = false
var _margin: MarginContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_margin.add_child(row)
	_build_pause(row)
	_build_core(row)
	_build_wave(row)
	_build_scrap(row)


func _build_pause(row: HBoxContainer) -> void:
	pause_button = Button.new()
	pause_button.custom_minimum_size = Vector2(HudStyle.TOUCH, HudStyle.TOUCH)
	pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_button.icon = HudStyle.texture(&"pause")
	pause_button.expand_icon = true
	pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_button.add_theme_constant_override(&"icon_max_width", 84)
	pause_button.tooltip_text = Strings.t("hud.pause")
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	HudStyle.style_button(pause_button, HudStyle.fill(), HudStyle.color(&"warden_cyan"))
	row.add_child(pause_button)


func _build_core(row: HBoxContainer) -> void:
	var panel: PanelContainer = _panel(row)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override(&"separation", 10)
	panel.add_child(hb)
	hb.add_child(HudStyle.icon(&"core", 56.0))
	shield_icon = HudStyle.icon(&"shield", 44.0)
	shield_icon.visible = false
	shield_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(shield_icon)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(col)
	var line: HBoxContainer = HBoxContainer.new()
	col.add_child(line)
	core_label = HudStyle.make_label("-", 34, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(core_label)
	core_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(core_label)
	core_value_label = HudStyle.make_label("-", 26, HudStyle.color(&"gunmetal").lightened(0.4))
	core_value_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	HudStyle.mono(core_value_label)
	line.add_child(core_value_label)
	core_bar = HudBar.new()
	core_bar.custom_minimum_size = Vector2(0.0, 28.0)
	col.add_child(core_bar)


func _build_wave(row: HBoxContainer) -> void:
	var panel: PanelContainer = _panel(row)
	wave_label = HudStyle.make_label("-", HudStyle.FONT_BODY, HudStyle.color(&"bone_ceramic"))
	HudStyle.center(wave_label)
	HudStyle.bold(wave_label)
	panel.add_child(wave_label)


func _build_scrap(row: HBoxContainer) -> void:
	var panel: PanelContainer = _panel(row)
	panel.custom_minimum_size = Vector2(240.0, 112.0)  # fixed, so the core bar does not jitter as the digits grow
	var hb: HBoxContainer = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override(&"separation", 10)
	panel.add_child(hb)
	var ic: TextureRect = HudStyle.icon(&"scrap", 52.0)
	ic.tooltip_text = Strings.t("hud.scrap")
	hb.add_child(ic)
	scrap_label = HudStyle.make_label("0", 44, HudStyle.color(&"core_amber"))
	HudStyle.mono(scrap_label)
	HudStyle.bold(scrap_label)
	scrap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(scrap_label)


func _panel(row: HBoxContainer) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(0.0, 112.0)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.fill(), HudStyle.alpha(HudStyle.color(&"warden_cyan"), 0.7)))
	row.add_child(p)
	return p


## The band is `band_h` tall from the top edge; the content starts below the safe-area inset (margins.y).
func place(width: float, band_h: float, margins: Vector4) -> void:
	position = Vector2.ZERO
	size = Vector2(width, band_h)
	_margin.add_theme_constant_override(&"margin_left", roundi(HudStyle.EDGE + margins.x))
	_margin.add_theme_constant_override(&"margin_right", roundi(HudStyle.EDGE + margins.z))
	_margin.add_theme_constant_override(&"margin_top", roundi(margins.y))
	_margin.add_theme_constant_override(&"margin_bottom", 0)
	queue_redraw()


## The variety run's bar: the core line is "CORE 64%" (the shield is the cyan overlay segment plus a shield mark) and the wave
## label is two lines, "ACT II" over "W7/15" (VARIETY_SPEC 11.4), so the core bar keeps its room.
func set_variety(on: bool) -> void:
	variety = on
	core_value_label.visible = not on
	if on:
		wave_label.add_theme_font_size_override(&"font_size", 34)
	else:
		wave_label.remove_theme_font_size_override(&"font_size")
		shield_icon.visible = false


func set_act_wave(act: int, index: int, total: int) -> void:
	wave_label.text = "%s\n%s" % [RunUi.act_label(act), Strings.tf("hud.wave_short", [maxi(index, 1), total])]


func set_core(hp: float, max_hp: float, shield: float) -> void:
	var frac: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	core_label.text = Strings.tf("hud.core_pct", [HudStyle.pct(hp, max_hp)])
	shield_icon.visible = variety and shield > 0.0
	if shield > 0.0:
		core_value_label.text = Strings.tf("hud.shield_up", [ceili(shield)])
		core_value_label.add_theme_color_override(&"font_color", HudStyle.color(&"warden_cyan"))
	else:
		core_value_label.text = Strings.tf("hud.core_hp", [ceili(hp), roundi(max_hp)])
		core_value_label.add_theme_color_override(&"font_color", HudStyle.color(&"gunmetal").lightened(0.4))
	var low: bool = frac < 0.25
	core_bar.set_fill_color(HudStyle.color(&"chorus_red") if low else HudStyle.color(&"core_amber"))
	core_bar.set_state(frac, shield / maxf(max_hp, 1.0))


func set_wave(index: int, total: int) -> void:
	wave_label.text = Strings.tf("hud.wave", [maxi(index, 1), total])


func set_scrap(value: int) -> void:
	scrap_label.text = HudStyle.group(value)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), HudStyle.alpha(HudStyle.color(&"obsidian"), 0.96))
	draw_rect(Rect2(0.0, size.y - 4.0, size.x, 4.0), HudStyle.alpha(HudStyle.color(&"warden_cyan"), 0.55))
