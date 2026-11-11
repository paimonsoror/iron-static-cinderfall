class_name HudIntermissionPanel
extends PanelContainer
## Shown between waves: "WAVE n CLEARED", the countdown to the next wave and a CONTINUE button that skips it
## (GDD 4.3, 7). The panel only reports the tap; the HUD calls RunApi.skip_intermission().

signal continue_pressed

const HEIGHT: float = 156.0

var title_label: Label
var countdown_label: Label
var continue_button: Button


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	add_theme_stylebox_override(&"panel", HudStyle.panel(
		HudStyle.alpha(HudStyle.color(&"obsidian"), 0.95), HudStyle.color(&"core_amber"), HudStyle.CHAMFER, 3))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	title_label = HudStyle.make_label("-", HudStyle.FONT_BODY, HudStyle.color(&"core_amber"))
	HudStyle.bold(title_label)
	col.add_child(title_label)
	countdown_label = HudStyle.make_label("-", HudStyle.FONT_LARGE, HudStyle.color(&"bone_ceramic"))
	HudStyle.mono(countdown_label)
	col.add_child(countdown_label)
	continue_button = Button.new()
	continue_button.text = Strings.t("hud.intermission.continue")
	continue_button.custom_minimum_size = Vector2(HudStyle.TOUCH * 2.0, HudStyle.PRIMARY_H)
	continue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	continue_button.add_theme_font_size_override(&"font_size", HudStyle.FONT_LARGE)
	HudStyle.bold_button(continue_button)
	continue_button.add_theme_color_override(&"font_color", HudStyle.color(&"obsidian"))
	continue_button.add_theme_color_override(&"font_hover_color", HudStyle.color(&"obsidian"))
	continue_button.add_theme_color_override(&"font_pressed_color", HudStyle.color(&"obsidian"))
	HudStyle.style_button(continue_button, HudStyle.color(&"core_amber"), HudStyle.color(&"bone_ceramic"))
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	row.add_child(continue_button)


func show_countdown(wave_cleared: int, ticks_left: int) -> void:
	title_label.text = Strings.tf("hud.intermission.cleared", [wave_cleared])
	countdown_label.text = Strings.tf("hud.intermission.next", [HudStyle.secs(ticks_left)])
