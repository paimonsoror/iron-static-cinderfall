class_name MatLib
extends RefCounted
## Cached, shared flat-palette materials (ARCH 8). One instance per id, never per-instance shader data.
## ids: ceramic, gunmetal, dark_frame, rubber, concrete, steel_red, steel_grey, hazard,
##      emit_cyan, emit_amber, emit_red, flash_white, shadow_blob, add_cyan, add_amber, add_red, add_white
## W1-E additions (arena only): concrete_light (pale painted concrete for barriers); pool_amber, pool_lamp,
## pool_cyan, pool_red (additive light pools with a radial falloff, UV 0..1 across a quad); rain (faint additive
## streaks). All colors still come from the palette tokens.

const IDS: Array[StringName] = [
	&"ceramic",
	&"gunmetal",
	&"dark_frame",
	&"rubber",
	&"concrete",
	&"steel_red",
	&"steel_grey",
	&"hazard",
	&"emit_cyan",
	&"emit_amber",
	&"emit_red",
	&"flash_white",
	&"shadow_blob",
	&"add_cyan",
	&"add_amber",
	&"add_red",
	&"add_white",
	&"concrete_light",
	&"pool_amber",
	&"pool_lamp",
	&"pool_cyan",
	&"pool_red",
	&"rain",
]

## Palette defaults (data/visual_tokens.json) used until configure() supplies the real tokens.
const DEFAULT_PALETTE: Dictionary = {
	&"obsidian": Color("#101820"),
	&"warden_cyan": Color("#39C9DB"),
	&"core_amber": Color("#F1A34A"),
	&"chorus_red": Color("#D94D4D"),
	&"gunmetal": Color("#6C7882"),
	&"bone_ceramic": Color("#D8D3C5"),
}

static var _tokens: VisualTokens = null
static var _mats: Dictionary[StringName, StandardMaterial3D] = {}
static var _glow: ImageTexture = null


## Same instance for the same id. Unknown ids give a magenta material so mistakes are visible.
static func mat(id: StringName) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	_paint(m, id)
	_mats[id] = m
	return m


## Applies the palette tokens to every material, existing instances included.
static func configure(tokens: VisualTokens) -> void:
	_tokens = tokens
	for id: StringName in _mats.keys():
		_paint(_mats[id], id)


## Radial alpha falloff (white, alpha 1 at the center, 0 at the edge) shared by every light pool. Built once.
static func glow_texture() -> ImageTexture:
	if _glow == null:
		_glow = ImageTexture.create_from_image(glow_image())
	return _glow


## The CPU image behind `glow_texture` (also what the tests read).
static func glow_image() -> Image:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var dx: float = (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var r: float = sqrt(dx * dx + dy * dy)
			var a: float = pow(clampf(1.0 - r, 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return img


static func _pal(token: StringName) -> Color:
	if _tokens != null and _tokens.palette.has(token):
		return _tokens.palette[token]
	var c: Color = DEFAULT_PALETTE.get(token, Color.MAGENTA)
	return c


static func _paint(m: StandardMaterial3D, id: StringName) -> void:
	m.resource_name = String(id)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.emission_enabled = false
	m.metallic = 0.0
	m.roughness = 0.9
	match id:
		&"ceramic":
			m.albedo_color = _pal(&"bone_ceramic")
			m.roughness = 0.6
		&"gunmetal":
			m.albedo_color = _pal(&"gunmetal")
			m.metallic = 0.3
			m.roughness = 0.55
		&"dark_frame":
			m.albedo_color = _pal(&"obsidian").lerp(_pal(&"gunmetal"), 0.25)
		&"rubber":
			m.albedo_color = _pal(&"obsidian").lerp(Color.BLACK, 0.4)
		&"concrete":
			m.albedo_color = _pal(&"obsidian").lerp(_pal(&"gunmetal"), 0.45)
			m.roughness = 1.0
		&"concrete_light":
			m.albedo_color = _pal(&"bone_ceramic").lerp(_pal(&"gunmetal"), 0.45)
			m.roughness = 0.95
		&"steel_red":
			m.albedo_color = _pal(&"chorus_red").lerp(_pal(&"obsidian"), 0.5)
		&"steel_grey":
			m.albedo_color = _pal(&"gunmetal").lerp(_pal(&"obsidian"), 0.2)
			m.metallic = 0.2
		&"hazard":
			m.albedo_color = _pal(&"core_amber")
		&"emit_cyan":
			_emissive(m, _pal(&"warden_cyan"))
		&"emit_amber":
			_emissive(m, _pal(&"core_amber"))
		&"emit_red":
			_emissive(m, _pal(&"chorus_red"))
		&"flash_white":
			_emissive(m, Color.WHITE)
		&"shadow_blob":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
			m.no_depth_test = false
		&"add_cyan":
			_additive(m, _pal(&"warden_cyan"))
		&"add_amber":
			_additive(m, _pal(&"core_amber"))
		&"add_red":
			_additive(m, _pal(&"chorus_red"))
		&"add_white":
			_additive(m, Color.WHITE)
		&"pool_amber":
			_pool(m, _pal(&"core_amber"), 0.5)
		&"pool_lamp":
			_pool(m, _pal(&"core_amber"), 0.16)
		&"pool_cyan":
			_pool(m, _pal(&"warden_cyan"), 0.3)
		&"pool_red":
			_pool(m, _pal(&"chorus_red"), 0.2)
		&"rain":
			_additive(m, _pal(&"bone_ceramic").lerp(_pal(&"warden_cyan"), 0.45))
			m.albedo_color.a = 0.2
		_:
			m.albedo_color = Color.MAGENTA


static func _emissive(m: StandardMaterial3D, c: Color) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.0


static func _additive(m: StandardMaterial3D, c: Color) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c.r, c.g, c.b, 0.6)
	m.no_depth_test = false
	m.disable_receive_shadows = true


static func _pool(m: StandardMaterial3D, c: Color, peak: float) -> void:
	_additive(m, c)
	m.albedo_color = Color(c.r, c.g, c.b, peak)
	m.albedo_texture = glow_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
