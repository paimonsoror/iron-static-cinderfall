class_name UiStatCell
extends PanelContainer
## One figure with a caption: a dark inset cell, small capitals above and a mono number below.

var caption: Label
var value: Label


func _init(caption_text: String = "", value_text: String = "", variant: StringName = UiTheme.LABEL_NUMBER) -> void:
	theme_type_variation = UiTheme.PANEL_INSET
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	caption = UiKit.label_text(caption_text, UiTheme.LABEL_CAPTION)
	col.add_child(caption)
	value = UiKit.label_text(value_text, variant)
	col.add_child(value)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func set_value(text: String) -> void:
	value.text = text
