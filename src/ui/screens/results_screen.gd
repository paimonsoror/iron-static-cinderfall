class_name ResultsScreen
extends Control
## Results (GDD 10.2): VICTORY or DEFEAT, a radio or log line, waves cleared, run time, core remaining, kills by
## type, and the Recovered Data earned (a count-up) with the new total, then RETRY and MENU. The reward was granted
## by the run flow before this screen exists; here it is only shown (`reward_granted` false means this run was
## already recorded, so nothing was earned now). The signals and setup() are the frozen contract (ARCH 9).

signal retry_pressed
signal menu_pressed

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
	waves_cell.set_value(Strings.tf("results.waves_value", [summary.waves_completed, content.waves.size()]))
	time_cell.set_value(UiKit.clock(summary.duration_ticks))
	core_cell.set_value(Strings.tf("results.core_value", [
		summary.core_hp, summary.core_max_hp, UiKit.percent(float(summary.core_hp), float(summary.core_max_hp)),
	]))
	_fill_kills(summary, content)
	_target = summary.data_reward if reward_granted else 0
	if reward_granted:
		total_label.text = Strings.tf("results.data_total", [UiKit.group(profile.data)])
	else:
		total_label.text = Strings.tf("results.data_banked", [UiKit.group(profile.data)])
	_start_count_up()


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
	col.add_child(_lore_panel())
	col.add_child(_stats_grid())
	col.add_child(_kills_panel())
	col.add_child(_data_panel())
	retry_button = UiKit.button_primary("results.retry")
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	_frame.footer.add_child(retry_button)
	menu_button = UiKit.button_quiet("results.menu")
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	_frame.footer.add_child(menu_button)


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
	return panel


## One row per enemy type in content order: silhouette, name, count.
func _fill_kills(summary: RunSummary, content: ContentSet) -> void:
	for child: Node in _kills_col.get_children():
		_kills_col.remove_child(child)
		child.queue_free()
	kill_rows.clear()
	var total: int = 0
	for i: int in content.enemies.size():
		var enemy: EnemyDef = content.enemies[i]
		var n: int = summary.kills_by_type[i] if i < summary.kills_by_type.size() else 0
		total += n
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.add_child(UiEnemyGlyph.new(enemy.id, 88.0))
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
