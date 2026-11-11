class_name UiTitleBlock
extends VBoxContainer
## "IRON STATIC:" over "CINDERFALL" between two amber rules (armory_style.png header). Text from the string table.

var top_label: Label
var main_label: Label


func _init(big: bool = true) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 0)
	top_label = UiKit.label_text(Strings.t("boot.title_top"), UiTheme.LABEL_HEADING, 60 if big else 44)
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(top_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	row.add_child(_rule())
	main_label = UiKit.label_text(Strings.t("boot.title_main"), UiTheme.LABEL_ACCENT, 104 if big else 76)
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(main_label)
	row.add_child(_rule())


func _rule() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = UiTheme.alpha(UiTheme.color(&"core_amber"), 0.85)
	r.custom_minimum_size = Vector2(24.0, 5.0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
