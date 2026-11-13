class_name MainMenuScreen
extends Control
## Main menu (GDD 10.2): the title over the hero backdrop, the profile's totals (Recovered Data, best core HP, best wave or
## missions held) and RESUME RUN (when a run file exists), START MISSION, DAILY RUN (after the first act I boss kill), ARCHIVE,
## SETTINGS and QUIT. ARCHIVE opens the Archive as an overlay on this screen (VARIETY_SPEC 13.4: the Archive is an overlay on
## MENU) unless `open_archive_overlay` is false; `archive_pressed` is emitted either way. DAILY RUN only announces itself
## (`daily_pressed`): the game layer knows the date and the seed. The signals and setup() are the frozen contract (ARCH 9).

signal start_pressed
signal settings_pressed
signal quit_pressed
signal resume_pressed  ## RESUME RUN: continue the run the run file holds (V3-I)
signal archive_pressed
signal daily_pressed

const NARROW_ROW_W: float = 900.0  ## below this much room the three footer buttons stack
const ARCHIVE_SCENE: String = "res://src/ui/screens/archive_screen.tscn"

var open_archive_overlay: bool = true  ## false when the game layer opens the Archive itself on `archive_pressed`
var resume_button: Button
var resume_wave: int = 0  ## 0 = no run to resume (the button is hidden)
var title_block: UiTitleBlock
var tagline_label: Label
var data_cell: UiStatCell
var best_core_cell: UiStatCell
var missions_cell: UiStatCell
var wave_cell: UiStatCell  ## BEST WAVE, in place of MISSIONS HELD on the generated run
var daily_label: Label  ## "TODAY: BEST WAVE 7" under the stats, while the daily run is open
var start_button: Button
var daily_button: Button
var archive_button: Button
var settings_button: Button
var quit_button: Button
var archive_screen: ArchiveScreen  ## the open Archive overlay, or null
var _frame: UiScreenFrame
var _profile: Profile
var _today: String = ""
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func setup(profile: Profile) -> void:
	_ensure_built()
	_profile = profile
	data_cell.set_value(UiKit.group(profile.data))
	best_core_cell.set_value(UiKit.group(profile.best_core_hp) if profile.best_core_hp > 0 else Strings.t("menu.none"))
	missions_cell.set_value(UiKit.group(profile.missions_completed))
	var best: int = MetaProfile.best_wave(profile)
	wave_cell.set_value(UiKit.group(best) if best > 0 else Strings.t("menu.none"))
	var variety: bool = Content.db != null and Content.db.is_variety()
	missions_cell.visible = not variety
	wave_cell.visible = variety
	_refresh_daily()


## RESUME RUN (VARIETY_SPEC 2.8): `wave` is the wave the saved run would continue; 0 hides the button. START MISSION
## stays below it and starts a new run, which replaces the saved one.
func set_resume_wave(wave: int) -> void:
	_ensure_built()
	resume_wave = maxi(wave, 0)
	resume_button.visible = resume_wave > 0
	if resume_wave > 0:
		resume_button.text = Strings.tf("menu.resume", [resume_wave])


## The date of today ("2026-11-12", from the game layer; the UI never reads the clock). With it the DAILY RUN line says how
## today's run went; without it the button shows alone.
func set_daily_today(date: String) -> void:
	_today = date
	_refresh_daily()


## True when the DAILY RUN button is on screen: the profile has killed an act I boss.
func daily_visible() -> bool:
	return daily_button != null and daily_button.visible


## Opens the Archive over this screen (the ARCHIVE button does it). Returns the overlay.
func open_archive() -> ArchiveScreen:
	if archive_screen != null and is_instance_valid(archive_screen):
		return archive_screen
	var packed: PackedScene = load(ARCHIVE_SCENE) as PackedScene
	var screen: ArchiveScreen = packed.instantiate() as ArchiveScreen
	add_child(screen)
	screen.setup(Content.db)
	screen.closed.connect(_on_archive_closed.bind(screen))
	archive_screen = screen
	return screen


## The back gesture: closes the Archive overlay when one is open. True when it did (the game layer then does nothing else).
func close_overlay() -> bool:
	if archive_screen != null and is_instance_valid(archive_screen):
		archive_screen.close()
		return true
	return false


func _on_archive_closed(screen: ArchiveScreen) -> void:
	screen.queue_free()
	archive_screen = null
	if _profile != null:
		setup(_profile)  # the Archive may have spent Data


## The tagline wraps in two equal lines, never one line and a lone word.
func _balance_tagline() -> void:
	if _frame != null and tagline_label != null and _frame.size.x > 1.0:
		UiKit.balance(tagline_label, _frame.available_width())


func _refresh_daily() -> void:
	if daily_button == null:
		return
	var open: bool = _profile != null and MetaProfile.act_one_boss_killed(_profile, Content.db)
	daily_button.visible = open
	daily_label.visible = false
	if not open or _today == "":
		return
	var daily: Dictionary = MetaProfile.daily(_profile)
	var date: String = str(daily.get("date", ""))
	if date != _today:
		daily_label.text = Strings.t("menu.daily.today")
	elif daily.get("won", false):
		daily_label.text = Strings.t("menu.daily.won")
	else:
		var best_value: Variant = daily.get("best_wave", 0)
		var best: int = best_value if typeof(best_value) == TYPE_INT else 0
		daily_label.text = Strings.tf("menu.daily.best", [best])
	daily_label.visible = true


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var frame: UiScreenFrame = UiScreenFrame.new(UiBackdrop.Mode.HERO)
	add_child(frame)
	_frame = frame
	var col: VBoxContainer = frame.content
	col.add_child(UiKit.spacer(60.0))
	title_block = UiTitleBlock.new(true)
	col.add_child(title_block)
	tagline_label = UiKit.label_text(Strings.t("lore.tagline"), UiTheme.LABEL_DIM)
	tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tagline_label)
	frame.resized.connect(_balance_tagline)
	_balance_tagline.call_deferred()
	col.add_child(UiKit.spacer(0.0, 0.0, true))
	var stats: HBoxContainer = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	col.add_child(stats)
	data_cell = UiStatCell.new(Strings.t("menu.data"), "0")
	best_core_cell = UiStatCell.new(Strings.t("menu.best_core"), Strings.t("menu.none"))
	missions_cell = UiStatCell.new(Strings.t("menu.missions"), "0")
	wave_cell = UiStatCell.new(Strings.t("menu.best_wave"), Strings.t("menu.none"))
	wave_cell.visible = false
	for cell: UiStatCell in [data_cell, best_core_cell, missions_cell, wave_cell]:
		stats.add_child(cell)
	daily_label = UiKit.label_text("", UiTheme.LABEL_DIM, UiTheme.FONT_SMALL)
	daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daily_label.visible = false
	col.add_child(daily_label)
	_build_footer(frame.footer)


func _build_footer(footer: VBoxContainer) -> void:
	resume_button = UiKit.button("menu.start")
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	resume_button.visible = false
	footer.add_child(resume_button)
	start_button = UiKit.button_primary("menu.start")
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	footer.add_child(start_button)
	daily_button = UiKit.button("menu.daily")
	daily_button.pressed.connect(func() -> void: daily_pressed.emit())
	daily_button.visible = false
	footer.add_child(daily_button)
	var row: GridContainer = GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 20)
	footer.add_child(row)
	row.add_theme_constant_override("v_separation", 20)
	UiKit.stack_when_narrow(row, _frame, NARROW_ROW_W)
	archive_button = _row_button("menu.archive", row, false)
	archive_button.pressed.connect(_on_archive)
	settings_button = _row_button("menu.settings", row, false)
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	quit_button = _row_button("menu.quit", row, true)
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())


## A button of the three-in-a-row footer line: it shares the width (the usual minimum would need more than the screen).
func _row_button(text_key: String, row: GridContainer, quiet: bool) -> Button:
	var b: Button = UiKit.button_quiet(text_key) if quiet else UiKit.button(text_key)
	b.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.BTN_PRIMARY_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(b)
	return b


func _on_archive() -> void:
	archive_pressed.emit()
	if open_archive_overlay:
		var _screen: ArchiveScreen = open_archive()
