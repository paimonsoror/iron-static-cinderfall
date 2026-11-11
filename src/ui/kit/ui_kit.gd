class_name UiKit
extends RefCounted
## Small control factories (ARCH 9). All text goes through Strings. TODO(W2-B) extends the set; signatures stay.


static func panel() -> PanelContainer:
	return PanelContainer.new()


## A button at least TOUCH_MIN square (primary height) labelled with Strings.t(text_key).
static func button(text_key: String) -> Button:
	var b: Button = Button.new()
	b.text = Strings.t(text_key)
	b.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN * 3, UiTheme.BTN_PRIMARY_H)
	return b


static func label(text_key: String, size: int = UiTheme.FONT_BODY) -> Label:
	var l: Label = Label.new()
	l.text = Strings.t(text_key)
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


## Wave 0 helper for the stub screens: a full-rect root with a centered column that starts with a title.
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
