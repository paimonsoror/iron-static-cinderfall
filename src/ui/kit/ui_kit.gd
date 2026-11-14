class_name UiKit
extends RefCounted
## Small control factories (ARCH 9). All text goes through Strings. The look comes from UiTheme (type variations),
## so a screen only needs a themed ancestor; UiScreenFrame provides one.


## A themed panel (cyan rim, chamfered corners).
static func panel() -> PanelContainer:
	return PanelContainer.new()


## A panel with a UiTheme panel variation (PANEL_RAISED, PANEL_INSET, PANEL_DANGER, PANEL_PLATE).
static func panel_variant(variant: StringName) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = variant
	return p


## A secondary button (cyan rim) at least TOUCH_MIN square (primary height) labelled with Strings.t(text_key).
static func button(text_key: String) -> Button:
	var b: Button = Button.new()
	b.text = Strings.t(text_key)
	b.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN * 3, UiTheme.BTN_PRIMARY_H)
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long label ("RESUME RUN (WAVE 15)") wraps on a narrow window, it never widens the screen
	b.pressed.connect(_tap)
	return b


## The one action of a screen: amber fill, dark text.
static func button_primary(text_key: String) -> Button:
	var b: Button = button(text_key)
	b.theme_type_variation = UiTheme.BUTTON_PRIMARY
	return b


## A low-key action (BACK, QUIT): gunmetal rim.
static func button_quiet(text_key: String) -> Button:
	var b: Button = button(text_key)
	b.theme_type_variation = UiTheme.BUTTON_QUIET
	return b


static func label(text_key: String, size: int = UiTheme.FONT_BODY) -> Label:
	var l: Label = Label.new()
	l.text = Strings.t(text_key)
	l.add_theme_font_size_override("font_size", size)
	return l


## A label with already-resolved text (numbers, names) and an optional theme variation and size (0 = theme size).
static func label_text(text: String, variant: StringName = &"", size: int = 0) -> Label:
	var l: Label = Label.new()
	l.text = text
	if variant != &"":
		l.theme_type_variation = variant
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


## assets/icons/<id>.svg when present, otherwise an empty TextureRect of icon size.
static func icon(id: StringName) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	var path: String = "res://assets/icons/%s.svg" % String(id)
	if ResourceLoader.exists(path):
		r.texture = load(path) as Texture2D
	r.custom_minimum_size = Vector2(64.0, 64.0)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r


static func bar() -> ProgressBar:
	var p: ProgressBar = ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0.0, 24.0)
	return p


## Balanced wrapping for a short centered text (a tagline): the label gets the narrowest width that keeps the number of lines it has
## at `room`, so the lines come out about equally long and the last one is never a lone word ("... Three pushes. One" over "Warden.").
## A one-line text keeps its natural width.
static func balance(l: Label, room: float) -> void:
	var font: Font = l.get_theme_font(&"font")
	var px: int = l.get_theme_font_size(&"font_size")
	var lines: int = _line_count(font, px, l.text, room)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if lines > 1 else Control.SIZE_FILL
	if lines <= 1:
		l.custom_minimum_size.x = 0.0
		return
	var lo: float = 0.0
	var hi: float = room
	for _i: int in 12:
		var mid: float = (lo + hi) * 0.5
		if _line_count(font, px, l.text, mid) > lines:
			lo = mid
		else:
			hi = mid
	l.custom_minimum_size.x = ceilf(hi)


static func _line_count(font: Font, px: int, text: String, width: float) -> int:
	var para: TextParagraph = TextParagraph.new()
	var _added: bool = para.add_string(text, font, px)
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return para.get_line_count()


## How many columns a row of buttons that share the width gets: `across` normally, one when the frame has less than `min_width` for it (a
## window narrower than the phone's 1080 px: three words such as SETTINGS, ARCHIVE and QUIT no longer fit side by side without splitting
## a word). The screen calls it from its own `resized` handler (a method, so a freed screen is never called back).
static func columns_for(frame: UiScreenFrame, across: int, min_width: float) -> int:
	return 1 if frame != null and frame.available_width() < min_width else across


## An empty Control `h` tall (and `w` wide); with `grow` it also takes the free space of its container.
static func spacer(h: float, w: float = 0.0, grow: bool = false) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if grow:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## A thin gunmetal rule.
static func rule() -> HSeparator:
	return HSeparator.new()


## A margin wrapper with the same inset on every side.
static func inset(child: Control, px: int) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	m.add_child(child)
	return m


## Anchors `c` to its parent's full rect with zero offsets (also right before it is in the tree).
static func fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


## `root` and every Control below it ignore the mouse: decoration inside a Button.
static func ignore_mouse(root: Node) -> void:
	var c: Control = root as Control
	if c != null:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in root.get_children():
		ignore_mouse(child)


## Every Button below `root`, in tree order.
static func buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	_collect_buttons(root, out)
	return out


## Every Label below `root`, in tree order.
static func labels(root: Node) -> Array[Label]:
	var out: Array[Label] = []
	_collect_labels(root, out)
	return out


## 1240 -> "1,240".
static func group(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if n < 0 else out


## Simulation ticks as m:ss, rounded down ("4:32").
static func clock(ticks: int) -> String:
	var seconds: int = floori(float(maxi(ticks, 0)) / float(ContentLoader.TICK_RATE))
	return "%d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]


## Percent of `max_value` as a whole number, rounded up and never 0 while anything is left.
static func percent(value: float, max_value: float) -> int:
	if value <= 0.0:
		return 0
	return clampi(ceili(value / maxf(max_value, 1.0) * 100.0 - 0.000001), 1, 100)


## Wave 0 helper of the stub screens (a full-rect root with a centered column that starts with a title). The real
## screens use UiScreenFrame; this stays so the kit keeps its Wave 0 surface.
static func stub_layout(root: Control, title_key: String) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 32)
	center.add_child(col)
	var title: Label = label(title_key, UiTheme.FONT_LARGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	return col


static func _tap() -> void:
	Sfx.play(&"ui_tap")


static func _collect_buttons(node: Node, out: Array[Button]) -> void:
	var b: Button = node as Button
	if b != null:
		out.append(b)
	for child: Node in node.get_children():
		_collect_buttons(child, out)


static func _collect_labels(node: Node, out: Array[Label]) -> void:
	var l: Label = node as Label
	if l != null:
		out.append(l)
	for child: Node in node.get_children():
		_collect_labels(child, out)
