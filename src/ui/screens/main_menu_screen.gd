class_name MainMenuScreen
extends Control
## Main menu (GDD 10.2): the title over the hero backdrop, the profile's totals (Recovered Data, best core HP,
## missions held) and START MISSION, SETTINGS, QUIT. The signals and setup() are the frozen contract (ARCH 9).

signal start_pressed
signal settings_pressed
signal quit_pressed
signal resume_pressed  ## RESUME RUN: continue the run the run file holds (V3-I)

var resume_button: Button
var resume_wave: int = 0  ## 0 = no run to resume (the button is hidden)
var title_block: UiTitleBlock
var tagline_label: Label
var data_cell: UiStatCell
var best_core_cell: UiStatCell
var missions_cell: UiStatCell
var start_button: Button
var settings_button: Button
var quit_button: Button
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func setup(profile: Profile) -> void:
	_ensure_built()
	data_cell.set_value(UiKit.group(profile.data))
	best_core_cell.set_value(UiKit.group(profile.best_core_hp) if profile.best_core_hp > 0 else Strings.t("menu.none"))
	missions_cell.set_value(UiKit.group(profile.missions_completed))


## RESUME RUN (VARIETY_SPEC 2.8): `wave` is the wave the saved run would continue; 0 hides the button. START MISSION
## stays below it and starts a new run, which replaces the saved one.
func set_resume_wave(wave: int) -> void:
	_ensure_built()
	resume_wave = maxi(wave, 0)
	resume_button.visible = resume_wave > 0
	if resume_wave > 0:
		resume_button.text = Strings.tf("menu.resume", [resume_wave])


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var frame: UiScreenFrame = UiScreenFrame.new(UiBackdrop.Mode.HERO)
	add_child(frame)
	var col: VBoxContainer = frame.content
	col.add_child(UiKit.spacer(60.0))
	title_block = UiTitleBlock.new(true)
	col.add_child(title_block)
	tagline_label = UiKit.label_text(Strings.t("lore.tagline"), UiTheme.LABEL_DIM)
	tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tagline_label)
	col.add_child(UiKit.spacer(0.0, 0.0, true))
	var stats: HBoxContainer = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	col.add_child(stats)
	data_cell = UiStatCell.new(Strings.t("menu.data"), "0")
	best_core_cell = UiStatCell.new(Strings.t("menu.best_core"), Strings.t("menu.none"))
	missions_cell = UiStatCell.new(Strings.t("menu.missions"), "0")
	for cell: UiStatCell in [data_cell, best_core_cell, missions_cell]:
		stats.add_child(cell)
	resume_button = UiKit.button("menu.start")
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	resume_button.visible = false
	frame.footer.add_child(resume_button)
	start_button = UiKit.button_primary("menu.start")
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	frame.footer.add_child(start_button)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	frame.footer.add_child(row)
	settings_button = UiKit.button("menu.settings")
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(settings_button)
	quit_button = UiKit.button_quiet("menu.quit")
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(quit_button)
