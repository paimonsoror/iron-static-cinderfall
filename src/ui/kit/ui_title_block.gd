class_name UiTitleBlock
extends VBoxContainer
## "IRON STATIC:" over "CINDERFALL" between two amber rules (armory_style.png header). Text from the string table.

const RULES_W: float = 2.0 * 24.0 + 2.0 * 20.0  ## the two amber rules at their least and the gaps around the name

var top_label: Label
var main_label: Label
var _base_px: int = 104


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
	_base_px = 104 if big else 76


func _rule() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = UiTheme.alpha(UiTheme.color(&"core_amber"), 0.85)
	r.custom_minimum_size = Vector2(24.0, 5.0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _ready() -> void:
	var frame: UiScreenFrame = _frame()
	if frame != null and not frame.resized.is_connected(_fit):
		frame.resized.connect(_fit)
	_fit.call_deferred()


## "CINDERFALL" at 104 px needs about 650 px: a window narrower than the phone's canvas gets a smaller name instead of a screen
## wider than the display. The room is the frame's width minus its margins (the block's own width cannot say: a name too wide
## already stretches it).
func _fit() -> void:
	var frame: UiScreenFrame = _frame()
	if main_label == null or frame == null or frame.size.x < 1.0:
		return
	var font: Font = main_label.get_theme_font(&"font")
	var room: float = frame.available_width() - RULES_W
	var px: int = _base_px
	while px > 40 and font.get_string_size(main_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > room:
		px -= 4
	main_label.add_theme_font_size_override(&"font_size", px)


func _frame() -> UiScreenFrame:
	var node: Node = get_parent()
	while node != null and not node is UiScreenFrame:
		node = node.get_parent()
	return node as UiScreenFrame
