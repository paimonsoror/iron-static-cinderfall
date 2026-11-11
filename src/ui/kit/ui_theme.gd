class_name UiTheme
extends RefCounted
## Theme with the two project fonts and the palette (ARCH 9). Chamfered dark panels with a thin cyan rim, amber
## accents, wide capitals (armory_style.png, styling only) and a high-contrast variant. Sizes are in 1080-wide
## base pixels. Every text color is a palette token pushed through readable(), so it reaches 4.5:1 against the
## lightest surface it can sit on (GDD 10.3).
##
## Type variations (set `theme_type_variation`):
##   Label:  LabelDim, LabelCaption, LabelAccent, LabelFriendly, LabelDanger, LabelHeading, LabelTitle, LabelNumber, Mono
##   Button: ButtonPrimary (amber fill), ButtonQuiet (gunmetal rim), ButtonSegment (toggle: selected = cyan fill)
##   Panel:  PanelRaised (amber rim), PanelInset (darker, gunmetal rim), PanelPlate (header plate), PanelDanger
##   ProgressBar: BarCyan, BarDanger

const TOUCH_MIN: int = 132
const BTN_PRIMARY_H: int = 148
const FONT_SMALL: int = 30
const FONT_BODY: int = 38
const FONT_LARGE: int = 52
const FONT_TITLE: int = 84

const CHAMFER: int = 18
const RIM_W: int = 3
const RIM_W_HC: int = 5
const MIN_CONTRAST: float = 4.5
const BODY_WEIGHT: int = 500
const BOLD_WEIGHT: int = 700
## OpenType "wght" axis tag as an int (Oxanium-Variable defaults to ExtraLight, which is too thin for a phone).
const WEIGHT_TAG: int = (0x77 << 24) | (0x67 << 16) | (0x68 << 8) | 0x74

const FONT_BODY_PATH: String = "res://assets/fonts/Oxanium-Variable.ttf"
const FONT_MONO_PATH: String = "res://assets/fonts/ShareTechMono-Regular.ttf"

const LABEL_DIM: StringName = &"LabelDim"
const LABEL_CAPTION: StringName = &"LabelCaption"
const LABEL_ACCENT: StringName = &"LabelAccent"
const LABEL_FRIENDLY: StringName = &"LabelFriendly"
const LABEL_DANGER: StringName = &"LabelDanger"
const LABEL_HEADING: StringName = &"LabelHeading"
const LABEL_TITLE: StringName = &"LabelTitle"
const LABEL_NUMBER: StringName = &"LabelNumber"
const BUTTON_PRIMARY: StringName = &"ButtonPrimary"
const BUTTON_QUIET: StringName = &"ButtonQuiet"
const BUTTON_SEGMENT: StringName = &"ButtonSegment"
const PANEL_RAISED: StringName = &"PanelRaised"
const PANEL_INSET: StringName = &"PanelInset"
const PANEL_PLATE: StringName = &"PanelPlate"
const PANEL_DANGER: StringName = &"PanelDanger"
const BAR_CYAN: StringName = &"BarCyan"
const BAR_DANGER: StringName = &"BarDanger"

## Text roles (see text_color). Tests walk this list.
const TEXT_ROLES: Array[StringName] = [&"body", &"dim", &"accent", &"friendly", &"danger", &"on_accent"]

## Fallback palette (data/visual_tokens.json) used before build() is called.
const _DEFAULTS: Dictionary = {
	&"obsidian": Color(0.0627, 0.0941, 0.1255),
	&"warden_cyan": Color(0.2235, 0.7882, 0.8588),
	&"core_amber": Color(0.9451, 0.6392, 0.2902),
	&"chorus_red": Color(0.8510, 0.3020, 0.3020),
	&"gunmetal": Color(0.4235, 0.4706, 0.5098),
	&"bone_ceramic": Color(0.8471, 0.8275, 0.7725),
}

static var _tokens: VisualTokens = null
static var _body: Font = null
static var _bold: Font = null
static var _mono: Font = null
static var _shared: Dictionary[bool, Theme] = {}
static var _shared_tokens: VisualTokens = null


static func build(tokens: VisualTokens, high_contrast: bool) -> Theme:
	if tokens != null:
		_tokens = tokens
	var t: Theme = Theme.new()
	t.default_font = body_font()
	t.default_font_size = FONT_BODY
	UiThemeBuilder.apply(t, high_contrast)
	return t


## One cached Theme per high-contrast flag, built from the loaded content's tokens. Screens use this so they
## look right even when no ancestor carries a theme.
static func shared(high_contrast: bool) -> Theme:
	var tokens: VisualTokens = null
	if Content.db != null:
		tokens = Content.db.tokens
	if _shared_tokens != tokens:
		_shared.clear()
		_shared_tokens = tokens
	if not _shared.has(high_contrast):
		_shared[high_contrast] = build(tokens, high_contrast)
	return _shared[high_contrast]


## True when the High Contrast setting is on.
static func high_contrast_on() -> bool:
	var v: Variant = Save.get_setting(&"high_contrast")
	if typeof(v) != TYPE_BOOL:
		return false
	var on: bool = v
	return on


## A palette color by token name. Magenta for an unknown token.
static func color(token: StringName) -> Color:
	if _tokens != null and _tokens.palette.has(token):
		return _tokens.palette[token]
	var c: Color = _DEFAULTS.get(token, Color.MAGENTA)
	return c


## A color with its alpha replaced.
static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


# --- surfaces and text colors ---


## Panel background.
static func panel_fill(high_contrast: bool = false) -> Color:
	if high_contrast:
		return color(&"obsidian").lerp(Color.BLACK, 0.4)
	return color(&"obsidian").lerp(color(&"gunmetal"), 0.12)


## Darker well for list cells and bar backgrounds.
static func inset_fill(high_contrast: bool = false) -> Color:
	return color(&"obsidian").lerp(Color.BLACK, 0.55 if high_contrast else 0.3)


## Button fill (a step lighter than the panel); `hover` is the lightest surface text may sit on.
static func button_fill(high_contrast: bool = false, hover: bool = false) -> Color:
	var amount: float = 0.12 if high_contrast else 0.2
	if hover:
		amount *= 1.8
	return panel_fill(high_contrast).lerp(color(&"gunmetal"), amount)


## Rim color of a palette token; High Contrast brightens it.
static func rim(token: StringName, high_contrast: bool = false) -> Color:
	var c: Color = color(token)
	if high_contrast:
		return c.lerp(Color.WHITE, 0.3)
	return c


static func rim_width(high_contrast: bool = false) -> int:
	return RIM_W_HC if high_contrast else RIM_W


## Text color of a role: body, dim, accent (amber), friendly (cyan), danger (red) or on_accent (dark, for text on an
## amber or cyan fill). Light roles reach MIN_CONTRAST against button_fill(hover), the lightest surface under text;
## danger only against panel_fill (red text is for panels, wells and the backdrop, never for a button fill), which
## keeps it a red instead of a pink.
static func text_color(role: StringName, high_contrast: bool = false) -> Color:
	var surface: Color = button_fill(high_contrast, true)
	var base: Color = color(&"bone_ceramic")
	match role:
		&"body":
			if high_contrast:
				base = Color.WHITE
		&"dim":
			base = color(&"gunmetal").lerp(color(&"bone_ceramic"), 0.4)
			if high_contrast:
				base = color(&"bone_ceramic").lerp(Color.WHITE, 0.5)
		&"accent":
			base = rim(&"core_amber", high_contrast)
		&"friendly":
			base = rim(&"warden_cyan", high_contrast)
		&"danger":
			base = color(&"chorus_red")
			if high_contrast:
				base = base.lerp(Color.WHITE, 0.35)
			surface = panel_fill(high_contrast)
		&"on_accent":
			return readable(color(&"obsidian"), accent_fill(high_contrast, true))
	return readable(base, surface)


## The amber fill of a primary button; `hover` is its lightest state (dark text sits on it).
static func accent_fill(high_contrast: bool = false, hover: bool = false) -> Color:
	var amber: Color = rim(&"core_amber", high_contrast)
	if hover:
		return amber.lightened(0.12)
	return amber


## WCAG 2.x contrast ratio, 1.0 (identical) to 21.0.
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## `fg` moved toward white (on a darker `bg`) or toward black (on a lighter one) until it reaches `min_ratio`.
static func readable(fg: Color, bg: Color, min_ratio: float = MIN_CONTRAST) -> Color:
	var target: Color = Color.WHITE
	if _luminance(bg) > _luminance(fg):
		target = Color.BLACK
	var c: Color = Color(fg.r, fg.g, fg.b, 1.0)
	var guard: int = 0
	while contrast_ratio(c, bg) < min_ratio and guard < 40:
		c = c.lerp(target, 0.05)
		guard += 1
	return c


static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)


# --- fonts ---


## Oxanium at body weight (500).
static func body_font() -> Font:
	if _body == null:
		_body = _variation(BODY_WEIGHT, 0)
	return _body


## Oxanium bold with a little letter spacing: the wide capitals of titles and buttons.
static func bold_font() -> Font:
	if _bold == null:
		_bold = _variation(BOLD_WEIGHT, 2)
	return _bold


static func mono_font() -> Font:
	if _mono == null:
		_mono = load(FONT_MONO_PATH) as Font
	return _mono


static func _variation(weight: int, spacing: int) -> Font:
	var base: Font = load(FONT_BODY_PATH) as Font
	if base == null:
		return null
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {WEIGHT_TAG: weight}
	fv.spacing_glyph = spacing
	return fv


# --- style boxes ---


## A panel box whose four corners are cut by `chamfer` px (corner_detail 1 turns the rounded corner into a straight cut).
static func chamfer_box(fill: Color, rim_color: Color, chamfer: int = CHAMFER, rim_w: int = RIM_W) -> StyleBoxFlat:
	return corner_box(fill, rim_color, chamfer, chamfer, chamfer, chamfer, rim_w)


## Like chamfer_box with a separate cut per corner (top-left, top-right, bottom-right, bottom-left): the armory plates.
static func corner_box(
	fill: Color, rim_color: Color, tl: int, tr: int, br: int, bl: int, rim_w: int = RIM_W
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim_color
	sb.set_border_width_all(rim_w)
	sb.corner_radius_top_left = tl
	sb.corner_radius_top_right = tr
	sb.corner_radius_bottom_right = br
	sb.corner_radius_bottom_left = bl
	sb.corner_detail = 1
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	return sb
