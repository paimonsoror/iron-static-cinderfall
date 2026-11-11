class_name LabelKit
extends RefCounted
## In-world text (the core's name plate, the "B-4" floor stencil) as Label3D. Sized in world meters: the pixel size
## is derived from the measured string width so the text spans `world_width_m` regardless of the font.

const FONT_PATH: String = "res://assets/fonts/Oxanium-Variable.ttf"

static var _font: Font = null


## A label of `text` that spans `world_width_m` meters. Not yet placed or rotated; unshaded; one-sided.
## `embolden` (0..1) thickens the strokes (the floor stencil).
static func make(text: String, world_width_m: float, color: Color, font_px: int = 64, embolden: float = 0.0) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	var font: Font = _get_font()
	var heavy: FontVariation = FontVariation.new()
	heavy.base_font = font
	heavy.variation_opentype = {"weight": 700}
	heavy.variation_embolden = embolden
	font = heavy
	label.font = font
	label.font_size = font_px
	label.outline_size = 0
	label.modulate = color
	label.shaded = false
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var width_px: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x
	label.pixel_size = world_width_m / width_px if width_px > 1.0 else 0.01
	return label


static func _get_font() -> Font:
	if _font != null:
		return _font
	var loaded: Resource = load(FONT_PATH)
	if loaded is Font:
		_font = loaded as Font
	else:
		_font = ThemeDB.fallback_font
	return _font
