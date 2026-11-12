class_name RunDetailPanel
extends Control
## The long-press detail of a choice (VARIETY_SPEC 11.1): the full rules text and what it works with, in a panel at the
## bottom of the screen (the thumb that pressed is already there) over a second dimming layer. CLOSE or a tap outside closes
## it; the choice underneath is untouched.

signal closed

var title_label: Label
var sub_label: Label
var body_label: Label
var extra_labels: Array[Label] = []
var close_button: Button


func _init() -> void:
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


## `sub` is the rarity or kind line, `body` the full text, `extra` further lines (WORKS WITH, enemies, ...).
func show_detail(title: String, sub: String, body: String, extra: PackedStringArray, rim: Color) -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	UiKit.fill(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(margin)
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(RunUi.EDGE))
	margin.add_theme_constant_override("margin_top", int(RunUi.EDGE))
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", int(RunUi.GAP))
	margin.add_child(column)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", RunUi.box(RunUi.fill(), rim))
	column.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	panel.add_child(col)
	title_label = RunUi.wrap(RunUi.label(title, UiTheme.FONT_LARGE, &"body", true))
	col.add_child(title_label)
	sub_label = RunUi.label(sub, RunUi.MIN_TEXT, &"dim", true)
	sub_label.add_theme_color_override(&"font_color", rim)
	col.add_child(sub_label)
	body_label = RunUi.wrap(RunUi.label(body, UiTheme.FONT_BODY))
	col.add_child(body_label)
	for line: String in extra:
		var l: Label = RunUi.wrap(RunUi.label(line, RunUi.MIN_TEXT + 4, &"accent", true))
		extra_labels.append(l)
		col.add_child(l)
	close_button = RunUi.button(Strings.t("ui.close"), true)
	close_button.pressed.connect(close)
	column.add_child(close_button)


func close() -> void:
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close()
