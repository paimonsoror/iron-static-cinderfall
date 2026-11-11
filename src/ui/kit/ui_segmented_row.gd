class_name UiSegmentedRow
extends PanelContainer
## A settings row with one choice out of a few (Quality LOW/MID/HIGH, FPS cap 30/60): a name and a hint line above a
## row of equal toggle buttons, each at least 132 px tall. The chosen one is a filled plate, the others are hollow.

signal selected(value: int)

var title_label: Label
var hint_label: Label
var buttons: Array[Button] = []
var _values: Array[int] = []
var _value: int = -1


## `option_keys[i]` is the string key of the button whose value is `values[i]`.
func _init(title_key: String = "", hint_key: String = "", option_keys: PackedStringArray = PackedStringArray(),
		values: Array[int] = [], current: int = -1) -> void:
	theme_type_variation = UiTheme.PANEL_INSET
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	title_label = UiKit.label_text(Strings.t(title_key).to_upper(), UiTheme.LABEL_HEADING, UiTheme.FONT_BODY + 4)
	col.add_child(title_label)
	hint_label = UiKit.label_text(Strings.t(hint_key), UiTheme.LABEL_CAPTION)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var group: ButtonGroup = ButtonGroup.new()
	_values = values.duplicate()
	for i: int in option_keys.size():
		var b: Button = UiKit.button(option_keys[i])
		b.theme_type_variation = UiTheme.BUTTON_SEGMENT
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0.0, UiTheme.TOUCH_MIN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(i))
		row.add_child(b)
		buttons.append(b)
	set_value(current)


func value() -> int:
	return _value


## Selects the option holding `v` without emitting `selected` (nothing is selected for an unknown value).
func set_value(v: int) -> void:
	_value = v
	for i: int in buttons.size():
		buttons[i].set_pressed_no_signal(i < _values.size() and _values[i] == v)


func _on_pressed(index: int) -> void:
	var v: int = _values[index]
	if v == _value:
		return
	_value = v
	selected.emit(v)
