class_name ResultsRecapPanels
extends VBoxContainer
## The two recap panels of a generated run's results (VARIETY_SPEC 11.5): WHAT BROKE THE LINE and YOUR BUILD, filled from a
## RunSummary through ResultsRecap. Hidden for the legacy content (a summary without the variety fields has nothing to recap).

var broke_panel: PanelContainer
var broke_title: Label
var broke_events: Label
var broke_lines: Array[Label] = []
var build_panel: PanelContainer
var build_chips: Array[Label] = []
var build_weapons: Label
var build_directives: Array[Label] = []
var _broke_col: VBoxContainer
var _build_col: VBoxContainer
var _flow: HFlowContainer
var _chip_row: HFlowContainer


func _init() -> void:
	add_theme_constant_override("separation", 16)
	broke_panel = UiKit.panel_variant(UiTheme.PANEL_INSET)
	_broke_col = VBoxContainer.new()
	_broke_col.add_theme_constant_override("separation", 6)
	broke_panel.add_child(_broke_col)
	broke_title = UiKit.label_text(Strings.t("results.broke"), UiTheme.LABEL_ACCENT)
	_broke_col.add_child(broke_title)
	_broke_col.add_child(UiKit.rule())
	add_child(broke_panel)
	build_panel = UiKit.panel_variant(UiTheme.PANEL_INSET)
	_build_col = VBoxContainer.new()
	_build_col.add_theme_constant_override("separation", 8)
	build_panel.add_child(_build_col)
	_build_col.add_child(UiKit.label_text(Strings.t("results.build"), UiTheme.LABEL_ACCENT))
	_build_col.add_child(UiKit.rule())
	_chip_row = HFlowContainer.new()  # the tag chips wrap on a narrow screen
	_chip_row.add_theme_constant_override("h_separation", 12)
	_chip_row.add_theme_constant_override("v_separation", 8)
	_build_col.add_child(_chip_row)
	build_weapons = UiKit.label_text("", &"", UiTheme.FONT_SMALL + 4)
	build_weapons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_col.add_child(build_weapons)
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 10)
	_flow.add_theme_constant_override("v_separation", 8)
	_build_col.add_child(_flow)
	add_child(build_panel)
	visible = false


## Fills both panels. Hidden when the content is the legacy one.
func show_run(summary: RunSummary, content: ContentSet) -> void:
	visible = content != null and content.is_variety()
	if not visible:
		return
	_fill_broke(summary, content)
	_fill_build(summary, content)


func _fill_broke(summary: RunSummary, content: ContentSet) -> void:
	for label: Label in broke_lines:
		label.queue_free()
	broke_lines.clear()
	if broke_events != null:
		broke_events.queue_free()
		broke_events = null
	var events: String = ResultsRecap.events_line(summary, content)
	if events != "":
		broke_events = UiKit.label_text(events, UiTheme.LABEL_DANGER, UiTheme.FONT_BODY)
		broke_events.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_broke_col.add_child(broke_events)
	var damage: Array[String] = ResultsRecap.damage_lines(summary, content)
	if damage.is_empty():
		var held: Label = UiKit.label_text(Strings.t("results.broke_held"), UiTheme.LABEL_DIM)
		held.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_broke_col.add_child(held)
		broke_lines.append(held)
		return
	var line: Label = UiKit.label_text("   ".join(damage), UiTheme.LABEL_CAPTION)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_broke_col.add_child(line)
	broke_lines.append(line)


func _fill_build(summary: RunSummary, content: ContentSet) -> void:
	for child: Node in _chip_row.get_children():
		child.queue_free()
	for child: Node in _flow.get_children():
		child.queue_free()
	build_chips.clear()
	build_directives.clear()
	for text: String in ResultsRecap.chip_texts(summary, content):
		var chip: PanelContainer = PanelContainer.new()
		chip.add_theme_stylebox_override(&"panel", RunUi.chip_box(UiTheme.rim(&"warden_cyan", RunUi.hc())))
		var label: Label = RunUi.label(text, RunUi.MIN_TEXT + 2, &"friendly", true)
		chip.add_child(label)
		_chip_row.add_child(chip)
		build_chips.append(label)
	build_weapons.text = "%s  %s" % [Strings.t("results.build_weapons"), ResultsRecap.weapons_line(summary, content)]
	var texts: Array[String] = ResultsRecap.directive_texts(summary, content)
	if texts.is_empty():
		var none: Label = UiKit.label_text(Strings.t("results.build_none"), UiTheme.LABEL_DIM)
		_flow.add_child(none)
		build_directives.append(none)
		return
	for text: String in texts:
		var chip: PanelContainer = PanelContainer.new()
		chip.add_theme_stylebox_override(&"panel", RunUi.chip_box())
		var label: Label = RunUi.label(text, RunUi.MIN_TEXT, &"body")
		chip.add_child(label)
		_flow.add_child(chip)
		build_directives.append(label)
