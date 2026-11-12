class_name HudTickerLine
extends PanelContainer
## One line of the threat ticker: an icon (warning triangle for harm, hex mark for help), the text and a countdown bar.

var icon_rect: TextureRect
var text_label: Label
var bar: HudBar
var harmful: bool = false
var _look: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	icon_rect = HudStyle.icon(&"ticker_warn", 44.0)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_rect)
	text_label = HudStyle.make_label("-", HudStyle.FONT_SMALL + 2, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(text_label)
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_label)
	bar = HudBar.new()
	bar.custom_minimum_size = Vector2(150.0, 16.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.segments = 8
	row.add_child(bar)


## `fraction` < 0 hides the bar (a notice).
func show_line(text: String, is_harmful: bool, fraction: float) -> void:
	visible = true
	text_label.text = text
	bar.visible = fraction >= 0.0
	if fraction >= 0.0:
		bar.set_state(fraction, 0.0)
	var look: int = 1 if is_harmful else 0
	if look == _look:
		return
	_look = look
	harmful = is_harmful
	var tone: Color = HudStyle.color(&"chorus_red") if is_harmful else HudStyle.color(&"warden_cyan")
	icon_rect.texture = HudStyle.texture(&"ticker_warn" if is_harmful else &"ticker_help")
	bar.set_fill_color(tone)
	text_label.add_theme_color_override(&"font_color", tone.lightened(0.35))
	add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.alpha(HudStyle.color(&"obsidian"), 0.88), tone, 10, 3))
	if HudStyle.high_contrast():
		HudStyle.outline(text_label, 5)
