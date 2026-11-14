class_name UiScreenFrame
extends Control
## The common frame of the meta screens: a drawn backdrop, then inside the display safe area a fixed `header`, a
## scrolling `content` column and a fixed `footer` (the buttons). It carries its own Theme (High Contrast aware), so a
## screen looks right with or without a themed ancestor, and re-skins itself when the High Contrast setting changes.
## Sizes are in 1080-wide base pixels.

const EDGE: float = 36.0
const GAP: float = 24.0

var backdrop: UiBackdrop
var header: VBoxContainer
var scroll: ScrollContainer
var content: VBoxContainer
var footer: VBoxContainer
var _margin: MarginContainer
var _safe: Vector4 = Vector4.ZERO


func _init(backdrop_mode: int = UiBackdrop.Mode.PLAIN) -> void:
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop = UiBackdrop.new(backdrop_mode)
	add_child(backdrop)
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_margin)
	add_child(_margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(GAP))
	_margin.add_child(column)
	header = VBoxContainer.new()
	header.add_theme_constant_override("separation", int(GAP))
	column.add_child(header)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(GAP))
	scroll.add_child(content)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", int(GAP))
	column.add_child(footer)
	_apply_margins()


func _ready() -> void:
	apply_style()
	get_viewport().size_changed.connect(_apply_os_safe_area)
	Events.settings_changed.connect(_on_setting_changed)
	_apply_os_safe_area()


func _exit_tree() -> void:
	var vp: Viewport = get_viewport()
	if vp != null and vp.size_changed.is_connected(_apply_os_safe_area):
		vp.size_changed.disconnect(_apply_os_safe_area)
	if Events.settings_changed.is_connected(_on_setting_changed):
		Events.settings_changed.disconnect(_on_setting_changed)


## Margins (left, top, right, bottom) of the display safe area in viewport units, added to the edge gap.
func set_safe_margins(margins: Vector4) -> void:
	_safe = margins
	_apply_margins()


func safe_margins() -> Vector4:
	return _safe


## The width the content column has: the frame minus its edge gaps and the safe area.
func available_width() -> float:
	return size.x - 2.0 * EDGE - _safe.x - _safe.z


## Rebuilds the look from the current High Contrast setting and redraws the drawn controls.
func apply_style() -> void:
	theme = UiTheme.shared(UiTheme.high_contrast_on())
	_redraw(self)


func _on_setting_changed(key: StringName) -> void:
	if key == &"high_contrast":
		apply_style()


func _apply_margins() -> void:
	_margin.add_theme_constant_override("margin_left", int(EDGE + _safe.x))
	_margin.add_theme_constant_override("margin_top", int(EDGE + _safe.y))
	_margin.add_theme_constant_override("margin_right", int(EDGE + _safe.z))
	_margin.add_theme_constant_override("margin_bottom", int(EDGE + _safe.w))


## Mobile only, and only in the real window (a capture SubViewport has no OS safe area).
func _apply_os_safe_area() -> void:
	if not is_inside_tree() or not OS.has_feature("mobile") or get_viewport() != get_tree().root:
		return
	var win: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	set_safe_margins(SafeArea.margins(win, safe, get_viewport_rect().size))


func _redraw(node: Node) -> void:
	var item: CanvasItem = node as CanvasItem
	if item != null:
		item.queue_redraw()
	for child: Node in node.get_children():
		_redraw(child)
