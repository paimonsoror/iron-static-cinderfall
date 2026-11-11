class_name UiToggleRow
extends PanelContainer
## A settings row: name and one hint line on the left, an ON/OFF switch on the right (at least 132 px tall, 220 wide).
## The state is written as text (ON/OFF) and as a filled plate vs a hollow one, never as color alone.

signal changed(on: bool)

const SWITCH_W: float = 220.0

var title_label: Label
var hint_label: Label
var switch: Button


func _init(title_key: String = "", hint_key: String = "", on: bool = false) -> void:
	theme_type_variation = UiTheme.PANEL_INSET
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	title_label = UiKit.label_text(Strings.t(title_key).to_upper(), UiTheme.LABEL_HEADING, UiTheme.FONT_BODY + 4)
	text.add_child(title_label)
	hint_label = UiKit.label_text(Strings.t(hint_key), UiTheme.LABEL_CAPTION)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(hint_label)
	switch = UiKit.button("settings.off")
	switch.theme_type_variation = UiTheme.BUTTON_SEGMENT
	switch.toggle_mode = true
	switch.custom_minimum_size = Vector2(SWITCH_W, UiTheme.TOUCH_MIN)
	switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	switch.toggled.connect(_on_toggled)
	row.add_child(switch)
	set_on(on)


func is_on() -> bool:
	return switch.button_pressed


## Sets the state without emitting `changed`.
func set_on(on: bool) -> void:
	switch.set_pressed_no_signal(on)
	_refresh_text()


func _on_toggled(_pressed: bool) -> void:
	_refresh_text()
	changed.emit(switch.button_pressed)


func _refresh_text() -> void:
	switch.text = Strings.t("settings.on" if switch.button_pressed else "settings.off")
