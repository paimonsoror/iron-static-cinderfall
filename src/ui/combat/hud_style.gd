class_name HudStyle
extends RefCounted
## Look of the combat HUD: chamfered dark panels with a thin rim, amber accents, wide capitals
## (armory_style.png, styling only). All sizes are in 1080-wide base pixels.

const CHAMFER: int = 14
const RIM_W: int = 3
const GAP: int = 12
const EDGE: int = 24  ## horizontal screen margin
const TOUCH: float = 132.0  ## UiTheme.TOUCH_MIN
const PRIMARY_H: float = 148.0  ## UiTheme.BTN_PRIMARY_H
const FONT_TINY: int = 24
const FONT_SMALL: int = UiTheme.FONT_SMALL
const FONT_BODY: int = UiTheme.FONT_BODY
const FONT_LARGE: int = UiTheme.FONT_LARGE
const FONT_TITLE: int = UiTheme.FONT_TITLE
const FONT_PATH: String = "res://assets/fonts/Oxanium-Variable.ttf"
## OpenType tag "wght" as an int.
const WEIGHT_TAG: int = (0x77 << 24) | (0x67 << 16) | (0x68 << 8) | 0x74

static var _bold: Font = null


static func color(token: StringName) -> Color:
	return UiTheme.color(token)


## A color with its alpha replaced.
static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Obsidian panel fill, slightly lifted so panels read against the 3D scene.
static func fill() -> Color:
	return color(&"obsidian").lerp(color(&"gunmetal"), 0.12)


## A chamfered panel box (corner_detail 1 turns the rounded corner into a straight cut).
static func panel(fill_color: Color, rim: Color, chamfer: int = CHAMFER, rim_w: int = RIM_W) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.border_color = rim
	sb.set_border_width_all(rim_w)
	sb.set_corner_radius_all(chamfer)
	sb.corner_detail = 1
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


## Gives a button the HUD look in all its states (the Button theme is not relied on).
static func style_button(b: Button, fill_color: Color, rim: Color) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override(&"normal", panel(fill_color, rim))
	b.add_theme_stylebox_override(&"hover", panel(fill_color.lightened(0.08), rim))
	b.add_theme_stylebox_override(&"pressed", panel(fill_color.lightened(0.18), color(&"core_amber")))
	b.add_theme_stylebox_override(&"disabled", panel(fill_color.darkened(0.2), color(&"gunmetal")))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())


static func make_label(text: String, font_size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	style_label(l, font_size, col)
	return l


static func style_label(l: Label, font_size: int, col: Color) -> void:
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if high_contrast():
		outline(l, 5)


## A dark outline under text drawn over the 3D scene (always on for banners, on everywhere in High Contrast).
static func outline(l: Label, px: int) -> void:
	l.add_theme_constant_override(&"outline_size", px)
	l.add_theme_color_override(&"font_outline_color", alpha(color(&"obsidian"), 0.95))


## Bold weight of the body font for names and numbers (null when the font cannot be loaded).
static func bold_font() -> Font:
	if _bold == null:
		var base: Font = load(FONT_PATH) as Font
		if base == null:
			return null
		var fv: FontVariation = FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {WEIGHT_TAG: 700}
		_bold = fv
	return _bold


static func bold(l: Label) -> void:
	var f: Font = bold_font()
	if f != null:
		l.add_theme_font_override(&"font", f)


static func bold_button(b: Button) -> void:
	var f: Font = bold_font()
	if f != null:
		b.add_theme_font_override(&"font", f)


static func mono(l: Label) -> void:
	l.theme_type_variation = &"Mono"


static func center(l: Label) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## A square icon from assets/icons (UiKit.icon looks the file up by id), `px` wide, ignoring the mouse.
static func icon(id: StringName, px: float) -> TextureRect:
	var r: TextureRect = UiKit.icon(id)
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## assets/icons/<id>.svg, or null when it does not exist.
static func texture(id: StringName) -> Texture2D:
	var path: String = "res://assets/icons/%s.svg" % String(id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Makes `root` and every Control below it ignore the mouse (decoration inside a Button).
static func ignore_mouse(root: Node) -> void:
	for child: Node in root.get_children():
		var c: Control = child as Control
		if c != null:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(child)


## Simulation ticks as whole seconds, rounded up (a 0.2 s cooldown shows "1s", never "0s").
static func secs(ticks: int) -> int:
	if ticks <= 0:
		return 0
	return ceili(float(ticks) / float(ContentLoader.TICK_RATE))


## Percent of `max_value` shown as a whole number, rounded up and never 0 while anything is left
## (the small epsilon keeps 0.07 * 100 = 7.000000000000001 from showing 8).
static func pct(value: float, max_value: float) -> int:
	if value <= 0.0:
		return 0
	return clampi(ceili(value / maxf(max_value, 1.0) * 100.0 - 0.000001), 1, 100)


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


static func high_contrast() -> bool:
	return _flag(&"high_contrast")


static func reduced_flash() -> bool:
	return _flag(&"reduced_flash")


static func _flag(key: StringName) -> bool:
	var v: Variant = Save.get_setting(key)
	if typeof(v) != TYPE_BOOL:
		return false
	var on: bool = v
	return on
