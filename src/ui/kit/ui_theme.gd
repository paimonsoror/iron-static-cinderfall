class_name UiTheme
extends RefCounted
## Theme with the two project fonts and the palette (ARCH 9). Wave 0 basic version. TODO(W2-B): chamfered
## panels, cyan rim, amber accents, final high-contrast variant. Sizes are in 1080-wide base pixels.

const TOUCH_MIN: int = 132
const BTN_PRIMARY_H: int = 148
const FONT_SMALL: int = 30
const FONT_BODY: int = 38
const FONT_LARGE: int = 52
const FONT_TITLE: int = 84

const FONT_BODY_PATH: String = "res://assets/fonts/Oxanium-Variable.ttf"
const FONT_MONO_PATH: String = "res://assets/fonts/ShareTechMono-Regular.ttf"

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


static func build(tokens: VisualTokens, high_contrast: bool) -> Theme:
	_tokens = tokens
	var t: Theme = Theme.new()
	var body: Font = load(FONT_BODY_PATH) as Font
	var mono: Font = load(FONT_MONO_PATH) as Font
	t.default_font = body
	t.default_font_size = FONT_BODY
	var text: Color = color(&"bone_ceramic")
	if high_contrast:
		text = Color.WHITE
	t.set_color("font_color", "Label", text)
	t.set_color("font_color", "Button", text)
	t.set_color("font_hover_color", "Button", color(&"warden_cyan"))
	t.set_color("font_pressed_color", "Button", color(&"core_amber"))
	t.set_color("font_disabled_color", "Button", color(&"gunmetal"))
	t.set_stylebox("normal", "Button", _box(color(&"obsidian").lerp(color(&"gunmetal"), 0.25), color(&"warden_cyan")))
	t.set_stylebox("hover", "Button", _box(color(&"obsidian").lerp(color(&"gunmetal"), 0.4), color(&"warden_cyan")))
	t.set_stylebox("pressed", "Button", _box(color(&"obsidian"), color(&"core_amber")))
	t.set_stylebox("disabled", "Button", _box(color(&"obsidian"), color(&"gunmetal")))
	t.set_stylebox("panel", "PanelContainer", _box(color(&"obsidian").lerp(color(&"gunmetal"), 0.15), color(&"warden_cyan")))
	t.add_type(&"Mono")
	t.set_type_variation(&"Mono", &"Label")
	t.set_font("font", &"Mono", mono)
	return t


## A palette color by token name. Magenta for an unknown token.
static func color(token: StringName) -> Color:
	if _tokens != null and _tokens.palette.has(token):
		return _tokens.palette[token]
	var c: Color = _DEFAULTS.get(token, Color.MAGENTA)
	return c


static func _box(fill: Color, rim: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb
