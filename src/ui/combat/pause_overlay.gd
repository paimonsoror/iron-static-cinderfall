class_name PauseOverlay
extends Control
## Full pause: a dimmed scrim, "PAUSED" and four big buttons (GDD 10.2). A generated run adds the run's seed (a line under
## the title) and a BUILD button that lists the directives and weapons held (the run comes from `RunSession`, which the combat HUD
## fills). The signals and `setup()` are the frozen contract (ARCH 9); Game connects them and frees the overlay. The
## simulation, cooldowns and audio are frozen by whoever shows this overlay; it only reports which button was pressed.

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal quit_pressed

const PANEL_W: float = 780.0

var title_label: Label
var seed_label: Label  ## "SEED 48211" (a generated run)
var build_button: Button  ## BUILD (a generated run)
var build_list: BuildList  ## the open build list, or null
var resume_button: Button
var restart_button: Button
var settings_button: Button
var quit_button: Button
var _panel: PanelContainer
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func setup() -> void:
	_ensure_built()
	_fit_panel()
	var variety: bool = RunSession.has_variety_run()
	seed_label.visible = variety
	build_button.visible = variety
	if variety:
		seed_label.text = Strings.tf("pause.seed", [RunSession.current_api().run_seed()])


## The build list (directives and weapons held) over the pause panel; false without a generated run.
func open_build() -> bool:
	if not RunSession.has_variety_run():
		return false
	if build_list != null and is_instance_valid(build_list):
		return true
	build_list = BuildList.new()
	build_list.setup(RunSession.current_api(), RunSession.current_content())
	build_list.closed.connect(_on_build_closed)
	add_child(build_list)
	return true


func _on_build_closed() -> void:
	if build_list != null and is_instance_valid(build_list):
		build_list.queue_free()
	build_list = null


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
	_panel = panel
	resized.connect(_fit_panel)
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
	seed_label = HudStyle.make_label("", HudStyle.FONT_SMALL + 2, HudStyle.color(&"gunmetal").lightened(0.4))
	HudStyle.center(seed_label)
	HudStyle.mono(seed_label)
	seed_label.visible = false
	col.add_child(seed_label)
	resume_button = _button(col, "pause.resume", true)
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	build_button = _button(col, "pause.build", false)
	build_button.visible = false
	build_button.pressed.connect(_on_build_pressed)
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


func _on_build_pressed() -> void:
	Sfx.play(&"ui_tap")
	var _opened: bool = open_build()


## The panel is 780 px wide on a phone and never wider than the screen minus a margin (a narrower window).
func _fit_panel() -> void:
	if _panel != null and size.x > 1.0:
		_panel.custom_minimum_size.x = minf(PANEL_W, maxf(size.x - 48.0, 240.0))
