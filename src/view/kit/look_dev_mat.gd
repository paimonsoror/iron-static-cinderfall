class_name LookDevMat
extends RefCounted
## The shared materials of the stylised actor looks (W3-C), one instance per (role, look, tier class), never per
## instance, no per-instance shader data. Roles are the MatLib ids of the surfaces of a mesh:
##  ceramic / gunmetal / dark_frame  on MID and HIGH a ShaderMaterial (look_dev_actor.gdshader: soft ramp, cyan fresnel rim,
##                                   edge wear, optional detail texture); on LOW a StandardMaterial3D that only shows
##                                   the baked vertex colours (no rim, no ramp, no detail)
##  emit_cyan                        a StandardMaterial3D, unshaded, HDR above 1 where bloom may pick it up
## Anything else is returned as the plain MatLib material. Palette colors come from MatLib (so the tokens stay the
## single source); `refresh` repaints after `MatLib.configure`.

const SHADER_PATH: String = "res://src/view/kit/look_dev_actor.gdshader"
const FRAME_ROLES: Array[StringName] = [&"ceramic", &"gunmetal", &"dark_frame"]

## Look-dev tuning: shader parameter overrides applied after the defaults (sandbox flag `--tune=name:value,...`).
static var overrides: Dictionary[StringName, float] = {}

static var _shader: Shader = null
static var _cache: Dictionary[String, Material] = {}


## The material for a surface of role `base_id` in `look` at quality `tier`.
static func surface(base_id: StringName, look: int, tier: int) -> Material:
	var plain: StandardMaterial3D = MatLib.mat(base_id)
	if look == LookDevStyle.Look.CURRENT:
		return plain
	var is_frame: bool = FRAME_ROLES.has(base_id)
	var is_accent: bool = base_id == &"emit_cyan"
	if not is_frame and not is_accent:
		return plain
	var shaded: bool = LookDevStyle.ramp_enabled(look, tier)
	var key: String = "%s|%d|%d" % [base_id, look, 1 if shaded else 0]
	if not _cache.has(key):
		_cache[key] = _build(base_id, look, shaded, is_accent)
	var m: Material = _cache[key]
	_paint(m, base_id, look, tier)
	return m


## Repaints every cached material from the current MatLib palette.
static func refresh() -> void:
	for key: String in _cache.keys():
		var parts: PackedStringArray = key.split("|")
		var m: Material = _cache[key]
		_paint(m, StringName(parts[0]), parts[1].to_int(), VisualQuality.Tier.MID if parts[2] == "1" else VisualQuality.Tier.LOW)


static func cached_count() -> int:
	return _cache.size()


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


static func _build(base_id: StringName, look: int, shaded: bool, is_accent: bool) -> Material:
	var name_text: String = "%s_%s_%s" % [base_id, LookDevStyle.name_of(look), "shaded" if shaded else "baked"]
	if is_accent:
		var e: StandardMaterial3D = StandardMaterial3D.new()
		e.resource_name = name_text
		e.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		e.emission_enabled = true
		return e
	if shaded:
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.resource_name = name_text
		sm.shader = shader()
		return sm
	var b: StandardMaterial3D = StandardMaterial3D.new()
	b.resource_name = name_text
	b.vertex_color_use_as_albedo = true
	b.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return b


static func _paint(m: Material, base_id: StringName, look: int, tier: int) -> void:
	var plain: StandardMaterial3D = MatLib.mat(base_id)
	var color: Color = plain.albedo_color
	var sm: ShaderMaterial = m as ShaderMaterial
	if sm != null:
		_paint_shader(sm, base_id, look, tier, color)
		return
	var std: StandardMaterial3D = m as StandardMaterial3D
	if base_id == &"emit_cyan":
		std.albedo_color = color
		std.emission = color
		std.emission_energy_multiplier = LookDevStyle.accent_energy(look, tier)
		return
	std.albedo_color = color
	std.roughness = plain.roughness
	std.metallic = plain.metallic


static func _paint_shader(sm: ShaderMaterial, base_id: StringName, look: int, tier: int, color: Color) -> void:
	var plus: bool = look == LookDevStyle.Look.STYLISED_PLUS
	var metal: bool = base_id != &"ceramic"
	var cyan: Color = MatLib.mat(&"emit_cyan").albedo_color
	sm.set_shader_parameter(&"albedo_tint", color)
	sm.set_shader_parameter(&"roughness", 0.4 if metal else 0.62)
	sm.set_shader_parameter(&"spec_strength", (0.8 if metal else 0.22) * (1.4 if plus else 1.0))
	sm.set_shader_parameter(&"rim_color", cyan)
	var rim: float = LookDevStyle.rim_strength(look) if LookDevStyle.rim_enabled(look, tier) else 0.0
	sm.set_shader_parameter(&"rim_strength", rim * (0.75 if metal else 1.0))
	sm.set_shader_parameter(&"wear_color", Color(0.74, 0.77, 0.8) if metal else Color(0.93, 0.92, 0.88))
	sm.set_shader_parameter(&"wear_strength", (0.75 if metal else 0.55) if LookDevStyle.wear_enabled(look, tier) else 0.0)
	var detail: bool = LookDevStyle.detail_enabled(look, tier)
	sm.set_shader_parameter(&"detail_tex", LookDevTex.texture() if detail else null)
	sm.set_shader_parameter(&"detail_strength", 1.0 if detail else 0.0)
	for key: StringName in overrides:
		sm.set_shader_parameter(key, overrides[key])
