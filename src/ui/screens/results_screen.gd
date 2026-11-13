class_name ResultsScreen
extends Control
## Results (GDD 10.2, 10.6): VICTORY or DEFEAT, a radio or log line, the act and wave reached, waves cleared, run time, core
## remaining, kills by type, and the Recovered Data earned (a count-up) with the new total, then RETRY and MENU. A generated run
## adds WHAT BROKE THE LINE, the build recap, the milestones it paid (`show_milestones`), the Archive hook that names what the
## Data now buys, the run's seed with SAME SEED, and an ARCHIVE button that opens the Archive over this screen. The reward was
## granted by the run flow before this screen exists; here it is only shown (`reward_granted` false means this run was already
## recorded, so nothing was earned now). The signals and setup() are the frozen contract (ARCH 9).

signal retry_pressed
signal menu_pressed
signal same_seed_pressed(run_seed: int)  ## RETRY with the seed of this run (the game layer starts it)
signal archive_pressed

const ARCHIVE_SCENE: String = "res://src/ui/screens/archive_screen.tscn"

const COUNT_SECONDS: float = 1.2
const COUNT_STEP: float = 0.05  ## the count-up redraws its number at 20 Hz, not every frame

var title_label: Label
var subtitle_label: Label
var speaker_label: Label
var lore_label: Label
var waves_cell: UiStatCell
var time_cell: UiStatCell
var core_cell: UiStatCell
var kills_cell: UiStatCell
var kill_rows: Array[Label] = []  ## one count label per enemy type, in content order
var data_label: Label
var total_label: Label
var retry_button: Button
var menu_button: Button
var act_label: Label  ## "ACT II  WAVE 8 OF 15" (a generated run)
var recap: ResultsRecapPanels
var milestone_label: Label
var hook_label: Label
var seed_label: Label
var seed_row: HBoxContainer
var same_seed_button: Button
var archive_button: Button
var archive_screen: ArchiveScreen  ## the open Archive overlay, or null
var open_archive_overlay: bool = true  ## false when the game layer opens the Archive itself on `archive_pressed`
var _seed: int = 0
var _frame: UiScreenFrame
var _kills_col: VBoxContainer
var _built: bool = false
var _target: int = 0
var _elapsed: float = 0.0
var _since_step: float = 0.0
var _counting: bool = false


func _ready() -> void:
	_ensure_built()


func setup(summary: RunSummary, content: ContentSet, profile: Profile, reward_granted: bool) -> void:
	_ensure_built()
	var won: bool = summary.result == RunResult.Id.VICTORY
	_frame.backdrop.mode = UiBackdrop.Mode.VICTORY if won else UiBackdrop.Mode.DEFEAT
	title_label.text = Strings.t("results.victory" if won else "results.defeat")
	title_label.theme_type_variation = UiTheme.LABEL_FRIENDLY if won else UiTheme.LABEL_DANGER
	title_label.add_theme_font_size_override("font_size", 104)
	subtitle_label.text = Strings.t("results.sub.victory" if won else "results.sub.defeat")
	speaker_label.text = Strings.t("lore.results.speaker.victory" if won else "lore.results.speaker.defeat")
	lore_label.text = Strings.t("lore.results.victory" if won else "lore.results.defeat")
	waves_cell.set_value(Strings.tf("results.waves_value", [summary.waves_completed, RunRoster.wave_count(content)]))
	time_cell.set_value(UiKit.clock(summary.duration_ticks))
	core_cell.set_value(Strings.tf("results.core_value", [
		summary.core_hp, summary.core_max_hp, UiKit.percent(float(summary.core_hp), float(summary.core_max_hp)),
	]))
	_fill_kills(summary, content)
	_fill_run_extras(summary, content, profile, won)
	_target = summary.data_reward if reward_granted else 0
	if reward_granted:
		total_label.text = Strings.tf("results.data_total", [UiKit.group(profile.data)])
	else:
		total_label.text = Strings.tf("results.data_banked", [UiKit.group(profile.data)])
	_start_count_up()


## The milestones this run paid, `{ "id": StringName, "data": int }` each (the game layer reads them from the reward): one
## "MILESTONE: NODE 9 FIRST KILL  +50" line each, under the Recovered Data.
func show_milestones(items: Array[Dictionary]) -> void:
	_ensure_built()
	var lines: PackedStringArray = PackedStringArray()
	for item: Dictionary in items:
		lines.append(ResultsRecap.milestone_text(item))
	milestone_label.text = "\n".join(lines)
	milestone_label.visible = not lines.is_empty()


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


func _process(delta: float) -> void:
	if not _counting:
		return
	_elapsed += delta
	_since_step += delta
	if _elapsed >= COUNT_SECONDS:
		finish_count_up()
	elif _since_step >= COUNT_STEP:
		_since_step = 0.0
		_show_count(roundi(float(_target) * _elapsed / COUNT_SECONDS))


## Jumps the count-up to the final number (also what a tap on the Data panel does).
func finish_count_up() -> void:
	_counting = false
	set_process(false)
	_show_count(_target)


func is_counting() -> bool:
	return _counting


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_frame = UiScreenFrame.new(UiBackdrop.Mode.PLAIN)
	add_child(_frame)
	var col: VBoxContainer = _frame.content
	title_label = UiKit.label_text("", UiTheme.LABEL_FRIENDLY, 104)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame.header.add_child(title_label)
	subtitle_label = UiKit.label_text("", UiTheme.LABEL_DIM)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame.header.add_child(subtitle_label)
	act_label = UiKit.label_text("", UiTheme.LABEL_ACCENT)
	act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_label.visible = false
	_frame.header.add_child(act_label)
	col.add_child(_lore_panel())
	col.add_child(_stats_grid())
	recap = ResultsRecapPanels.new()
	col.add_child(recap)
	col.add_child(_kills_panel())
	col.add_child(_data_panel())
	_build_footer()


func _build_footer() -> void:
	seed_row = HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 20)
	seed_row.visible = false
	seed_label = UiKit.label_text("", UiTheme.LABEL_NUMBER, UiTheme.FONT_BODY)
	seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seed_row.add_child(seed_label)
	same_seed_button = UiKit.button("results.same_seed")
	same_seed_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN * 2, UiTheme.TOUCH_MIN)
	same_seed_button.pressed.connect(_on_same_seed)
	seed_row.add_child(same_seed_button)
	_frame.footer.add_child(seed_row)
	retry_button = UiKit.button_primary("results.retry")
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	_frame.footer.add_child(retry_button)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_frame.footer.add_child(row)
	archive_button = UiKit.button("results.archive")
	archive_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.BTN_PRIMARY_H)
	archive_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_button.visible = false
	archive_button.pressed.connect(_on_archive)
	row.add_child(archive_button)
	menu_button = UiKit.button_quiet("results.menu")
	menu_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.BTN_PRIMARY_H)
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(menu_button)


func _lore_panel() -> PanelContainer:
	var panel: PanelContainer = UiKit.panel()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	speaker_label = UiKit.label_text("", UiTheme.LABEL_FRIENDLY, UiTheme.FONT_SMALL)
	col.add_child(speaker_label)
	lore_label = UiKit.label_text("")
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(lore_label)
	return panel


func _stats_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	waves_cell = UiStatCell.new(Strings.t("results.waves"), "")
	time_cell = UiStatCell.new(Strings.t("results.time"), "")
	core_cell = UiStatCell.new(Strings.t("results.core"), "")
	kills_cell = UiStatCell.new(Strings.t("results.kills_total"), "")
	for cell: UiStatCell in [waves_cell, time_cell, core_cell, kills_cell]:
		grid.add_child(cell)
	return grid


func _kills_panel() -> PanelContainer:
	var panel: PanelContainer = UiKit.panel_variant(UiTheme.PANEL_INSET)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UiKit.label_text(Strings.t("results.kills"), UiTheme.LABEL_ACCENT))
	col.add_child(UiKit.rule())
	_kills_col = VBoxContainer.new()
	_kills_col.add_theme_constant_override("separation", 6)
	col.add_child(_kills_col)
	return panel


func _data_panel() -> PanelContainer:
	var panel: PanelContainer = UiKit.panel_variant(UiTheme.PANEL_RAISED)
	panel.gui_input.connect(_on_data_input)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var head: Label = UiKit.label_text(Strings.t("results.data"), UiTheme.LABEL_CAPTION)
	col.add_child(head)
	data_label = UiKit.label_text("", UiTheme.LABEL_NUMBER, 84)
	col.add_child(data_label)
	total_label = UiKit.label_text("", UiTheme.LABEL_DIM)
	total_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(total_label)
	milestone_label = UiKit.label_text("", UiTheme.LABEL_FRIENDLY, UiTheme.FONT_SMALL + 2)
	milestone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	milestone_label.visible = false
	col.add_child(milestone_label)
	hook_label = UiKit.label_text("", UiTheme.LABEL_ACCENT, UiTheme.FONT_SMALL + 2)
	hook_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hook_label.visible = false
	col.add_child(hook_label)
	return panel


## One row per enemy type in content order: silhouette, name, count.
func _fill_kills(summary: RunSummary, content: ContentSet) -> void:
	for child: Node in _kills_col.get_children():
		_kills_col.remove_child(child)
		child.queue_free()
	kill_rows.clear()
	var total: int = 0
	for enemy: EnemyDef in RunRoster.enemies(content):  # the legacy four, or what the generated run can field
		var i: int = enemy.index
		var n: int = summary.kills_by_type[i] if i < summary.kills_by_type.size() else 0
		total += n
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.add_child(RunEnemyGlyph.new(enemy.id, 88.0))
		var name_label: Label = UiKit.label_text(Strings.t(enemy.name_key).to_upper())
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
		var count: Label = UiKit.label_text(UiKit.group(n), UiTheme.LABEL_NUMBER)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kill_rows.append(count)
		row.add_child(count)
		_kills_col.add_child(row)
	kills_cell.set_value(UiKit.group(total))


## The additions of a generated run: act line, recap panels, Archive hook, seed row, ARCHIVE button. Hidden on legacy content.
func _fill_run_extras(summary: RunSummary, content: ContentSet, profile: Profile, won: bool) -> void:
	var variety: bool = content != null and content.is_variety()
	act_label.visible = variety
	recap.show_run(summary, content)
	archive_button.visible = variety
	seed_row.visible = variety
	hook_label.text = ResultsRecap.hook_text(content, profile) if variety else ""
	hook_label.visible = hook_label.text != ""
	milestone_label.visible = milestone_label.visible and variety
	_seed = summary.run_seed
	if not variety:
		return
	var total: int = RunRoster.wave_count(content)
	var reached: int = clampi(summary.waves_completed + (0 if won else 1), 1, maxi(total, 1))
	act_label.text = "%s    %s" % [
		Strings.tf("results.act_wave", [RunUi.roman(maxi(summary.act_reached, 1)), reached, total]), UiKit.clock(summary.duration_ticks),
	]
	seed_label.text = Strings.tf("results.seed", [_seed])


func _on_same_seed() -> void:
	if same_seed_pressed.get_connections().is_empty():
		Sfx.play(&"ui_deny")  # nobody starts runs from here (a sandbox): nothing to do
		return
	Sfx.play(&"ui_tap")
	same_seed_pressed.emit(_seed)


func _on_archive() -> void:
	archive_pressed.emit()
	if open_archive_overlay:
		var _screen: ArchiveScreen = open_archive()


## The back gesture: closes the Archive overlay when one is open. True when it did (the game layer then does nothing else).
func close_overlay() -> bool:
	if archive_screen != null and is_instance_valid(archive_screen):
		archive_screen.close()
		return true
	return false


func _on_archive_closed(screen: ArchiveScreen) -> void:
	screen.queue_free()
	archive_screen = null


func _start_count_up() -> void:
	_elapsed = 0.0
	_since_step = 0.0
	if _target <= 0:
		finish_count_up()
		return
	_counting = true
	set_process(true)
	_show_count(0)


func _show_count(n: int) -> void:
	data_label.text = Strings.tf("results.data_earned", [UiKit.group(n)])


func _on_data_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and _counting:
		finish_count_up()
