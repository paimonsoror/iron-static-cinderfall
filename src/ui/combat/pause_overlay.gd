class_name PauseOverlay
extends Control
## Full pause: a dimmed scrim, "PAUSED" and four big buttons (GDD 10.2). The signals and `setup()` are the
## frozen contract (ARCH 9); Game connects them and frees the overlay. The simulation, cooldowns and audio are
## frozen by whoever shows this overlay; it only reports which button was pressed.

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal quit_pressed

const PANEL_W: float = 780.0

var title_label: Label
var resume_button: Button
var restart_button: Button
var settings_button: Button
var quit_button: Button
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func setup() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.color = HudStyle.alpha(HudStyle.color(&"obsidian"), 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, 0.0)
	panel.add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.fill(), HudStyle.color(&"warden_cyan"), 22, 4))
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	panel.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 24)
	margin.add_child(col)
	title_label = HudStyle.make_label(Strings.t("pause.title"), HudStyle.FONT_TITLE, HudStyle.color(&"bone_ceramic"))
	HudStyle.center(title_label)
	HudStyle.bold(title_label)
	col.add_child(title_label)
	resume_button = _button(col, "pause.resume", true)
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	restart_button = _button(col, "pause.restart", false)
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	settings_button = _button(col, "pause.settings", false)
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	quit_button = _button(col, "pause.quit", false)
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())


func _button(col: VBoxContainer, key: String, primary: bool) -> Button:
	var b: Button = Button.new()
	b.text = Strings.t(key)
	b.custom_minimum_size = Vector2(0.0, HudStyle.PRIMARY_H)
	b.add_theme_font_size_override(&"font_size", HudStyle.FONT_LARGE)
	HudStyle.bold_button(b)
	var amber: Color = HudStyle.color(&"core_amber")
	if primary:
		var dark: Color = HudStyle.color(&"obsidian")
		b.add_theme_color_override(&"font_color", dark)
		b.add_theme_color_override(&"font_hover_color", dark)
		b.add_theme_color_override(&"font_pressed_color", dark)
		HudStyle.style_button(b, amber, HudStyle.color(&"bone_ceramic"))
	else:
		b.add_theme_color_override(&"font_color", HudStyle.color(&"bone_ceramic"))
		HudStyle.style_button(b, HudStyle.fill(), HudStyle.color(&"warden_cyan"))
	col.add_child(b)
	return b
