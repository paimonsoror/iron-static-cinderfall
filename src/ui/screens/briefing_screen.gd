class_name BriefingScreen
extends Control
## Mission briefing (GDD 10.2): the mission name, the Accord radio text, the objectives (waves, core, boss), a threat
## row per enemy with its silhouette and rank, then DEPLOY and BACK. The signals and setup() are the frozen
## contract (ARCH 9).

signal deploy_pressed
signal back_pressed

var header_plate: UiHeaderPlate
var mission_label: Label
var assigned_label: Label
var radio_speaker_label: Label
var radio_label: Label
var objective_labels: Array[Label] = []
var threat_rows: Array[BriefingThreatRow] = []
var deploy_button: Button
var back_button: Button
var _frame: UiScreenFrame
var _objectives_col: VBoxContainer
var _threats_col: VBoxContainer
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func setup(content: ContentSet) -> void:
	_ensure_built()
	mission_label.text = Strings.t(content.mission.name_key).to_upper()
	_fill_objectives(content)
	_fill_threats(content)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = UiScreenFrame.new(UiBackdrop.Mode.PLAIN)
	add_child(_frame)
	header_plate = UiHeaderPlate.new(Strings.t("briefing.header"))
	_frame.header.add_child(header_plate)
	var col: VBoxContainer = _frame.content
	mission_label = UiKit.label_text("", UiTheme.LABEL_TITLE)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(mission_label)
	assigned_label = UiKit.label_text(Strings.t("lore.briefing.assigned"), UiTheme.LABEL_CAPTION)
	assigned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assigned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(assigned_label)
	col.add_child(_radio_panel())
	col.add_child(_section(Strings.t("briefing.objectives")))
	_objectives_col = VBoxContainer.new()
	_objectives_col.add_theme_constant_override("separation", 12)
	col.add_child(_objectives_col)
	col.add_child(_section(Strings.t("briefing.threats")))
	_threats_col = VBoxContainer.new()
	_threats_col.add_theme_constant_override("separation", 14)
	col.add_child(_threats_col)
	deploy_button = UiKit.button_primary("briefing.deploy")
	deploy_button.pressed.connect(func() -> void: deploy_pressed.emit())
	_frame.footer.add_child(deploy_button)
	back_button = UiKit.button_quiet("briefing.back")
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	_frame.footer.add_child(back_button)


## The Accord radio fragment on a cyan-rimmed panel, the speaker line above it.
func _radio_panel() -> PanelContainer:
	var panel: PanelContainer = UiKit.panel()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	radio_speaker_label = UiKit.label_text(Strings.t("lore.briefing.speaker"), UiTheme.LABEL_FRIENDLY, UiTheme.FONT_SMALL)
	col.add_child(radio_speaker_label)
	radio_label = UiKit.label_text(Strings.t("lore.briefing.text"))
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(radio_label)
	return panel


## A small amber heading with a rule under it.
func _section(text: String) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(UiKit.label_text(text, UiTheme.LABEL_ACCENT))
	col.add_child(UiKit.rule())
	return col


func _fill_objectives(content: ContentSet) -> void:
	_clear(_objectives_col)
	objective_labels.clear()
	var lines: Array[String] = [
		Strings.tf("briefing.obj.waves", [RunRoster.wave_count(content)]),
		Strings.tf("briefing.obj.core", [UiKit.group(roundi(content.mission.core_max_hp))]),
	]
	for entry: Dictionary in RunRoster.boss_waves(content):
		var boss: EnemyDef = entry["enemy"]
		var boss_wave: int = entry["wave"]
		lines.append(Strings.tf("briefing.obj.boss", [Strings.t(boss.name_key), boss_wave]))
	for line: String in lines:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var mark: UiChevrons = UiChevrons.new(1, 1)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # beside the first line when a text wraps
		row.add_child(mark)
		var l: Label = UiKit.label_text(line)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_labels.append(l)
		row.add_child(l)
		_objectives_col.add_child(row)


## One row per enemy, weakest first. A machine's rank is its place when the roster is sorted by hit points.
func _fill_threats(content: ContentSet) -> void:
	_clear(_threats_col)
	threat_rows.clear()
	var ordered: Array[EnemyDef] = RunRoster.enemies(content)  # the legacy four, or what the generated run can field
	ordered.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool: return a.hp < b.hp)
	for i: int in ordered.size():
		var row: BriefingThreatRow = BriefingThreatRow.new(ordered[i], i + 1, ordered.size())
		threat_rows.append(row)
		_threats_col.add_child(row)


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
