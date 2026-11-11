class_name UiHeaderPlate
extends PanelContainer
## The title plate of armory_style.png ("ARMORY"): a long dark plate with a cyan rim, cut at two opposite corners,
## carrying one line of wide capitals.

var label: Label


func _init(text: String = "") -> void:
	theme_type_variation = UiTheme.PANEL_PLATE
	label = UiKit.label_text(text.to_upper(), UiTheme.LABEL_HEADING)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func set_text(text: String) -> void:
	label.text = text.to_upper()
