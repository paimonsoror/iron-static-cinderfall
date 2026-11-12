class_name LookActorsMat
extends RefCounted
## The shared materials of the CHORUS machines in the hard-surface looks (W3-D): one instance per (role, look, shaded class),
## never per instance and never with per-instance shader data (the 108 pooled enemies share them; the hit flash is a
## `material_override` and wins over these surface overrides).
##  ceramic / gunmetal  MID and HIGH: a ShaderMaterial on look_actors_enemy.gdshader (ramp, warm rim and bounce, grit);
##                      LOW: a StandardMaterial3D that shows the baked vertex colours (grime, chips, AO) and nothing else.
##  emit_red            the single optic: an unshaded StandardMaterial3D that takes the vertex colour (the dim halo band is
##                      a darker tint of the same surface). Above 1 in the red channel only where bloom may pick it up.
## The turret is friendly and uses LookDevMat (the Warden's roles and cyan accents). `refresh` repaints after `MatLib.configure`.

const SHADER_PATH: String = "res://src/view/kit/look_actors_enemy.gdshader"
const ROLES: Array[StringName] = [&"ceramic", &"gunmetal", &"dark_frame"]
const OPTIC: StringName = &"emit_red"
## Value gain of the dark frame (vertex tints of 0.1 to 0.5 become a readable gunmetal) and the share of it LOW takes.
const FRAME_GAIN: float = 2.4
const LOW_FRAME_SCALE: float = 0.8
const PLATE_GAIN: float = 1.15

static var _shader: Shader = null
static var _cache: Dictionary[String, Material] = {}


## The material for a surface of role `base_id` of an enemy in `look` at `tier`; the plain MatLib material for anything else
## (and for CURRENT, or when the rollout is off).
static func surface(base_id: StringName, look: int, tier: int) -> Material:
	var plain: StandardMaterial3D = MatLib.mat(base_id)
	if not LookActorsStyle.enabled(look):
		return plain
	var is_frame: bool = ROLES.has(base_id)
	var is_optic: bool = base_id == OPTIC
	if not is_frame and not is_optic:
		return plain
	var shaded: bool = LookDevStyle.ramp_enabled(look, tier)
	var key: String = "%s|%d|%d" % [base_id, look, 1 if shaded else 0]
	if not _cache.has(key):
		_cache[key] = _build(base_id, look, shaded, is_optic)
	var m: Material = _cache[key]
	_paint(m, base_id, look, tier)
	return m


static func refresh() -> void:
	for key: String in _cache.keys():
		var parts: PackedStringArray = key.split("|")
		var tier: int = VisualQuality.Tier.MID if parts[2] == "1" else VisualQuality.Tier.LOW
		_paint(_cache[key], StringName(parts[0]), parts[1].to_int(), tier)


## The materials the boot warm-up must draw once (ShaderWarmup, with a vertex colour like the real meshes): the shaded and
## the baked variant of every role, the optic, and the hit-flash material (it is drawn over the same vertex format).
static func warm_materials(look: int) -> Array[Material]:
	var out: Array[Material] = []
	if not LookActorsStyle.enabled(look):
		return out
	for role: StringName in [&"ceramic", &"gunmetal", OPTIC]:
		for tier: int in [VisualQuality.Tier.MID, VisualQuality.Tier.LOW]:
			var m: Material = surface(role, look, tier)
			if not out.has(m):
				out.append(m)
	out.append(MatLib.mat(&"flash_white"))
	return out


static func cached_count() -> int:
	return _cache.size()


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


static func _build(base_id: StringName, look: int, shaded: bool, is_optic: bool) -> Material:
	var name_text: String = "%s_%s_%s" % [base_id, LookDevStyle.name_of(look), "shaded" if shaded else "baked"]
	if is_optic:
		var e: StandardMaterial3D = StandardMaterial3D.new()
		e.resource_name = name_text
		e.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		e.vertex_color_use_as_albedo = true
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
	var sm: ShaderMaterial = m as ShaderMaterial
	if sm != null:
		_paint_shader(sm, base_id, look, tier, plain.albedo_color)
		return
	var std: StandardMaterial3D = m as StandardMaterial3D
	if base_id == OPTIC:
		std.albedo_color = LookActorsStyle.optic_color(plain.albedo_color, LookActorsStyle.optic_energy(look, tier))
		return
	var gain: float = 1.0 if base_id == &"ceramic" else FRAME_GAIN * LOW_FRAME_SCALE
	var c: Color = plain.albedo_color
	std.albedo_color = Color(c.r * gain, c.g * gain, c.b * gain, 1.0)
	std.roughness = plain.roughness
	std.metallic = 0.0


static func _paint_shader(sm: ShaderMaterial, base_id: StringName, look: int, tier: int, color: Color) -> void:
	var plate: bool = base_id == &"ceramic"
	var rim: float = LookActorsStyle.warm_rim_strength(look, tier)
	sm.set_shader_parameter(&"albedo_tint", color)
	sm.set_shader_parameter(&"value_gain", PLATE_GAIN if plate else FRAME_GAIN)
	sm.set_shader_parameter(&"fill_strength", 0.32 if plate else 0.5)
	sm.set_shader_parameter(&"roughness", 0.72 if plate else 0.6)
	sm.set_shader_parameter(&"spec_strength", 0.08 if plate else 0.14)
	sm.set_shader_parameter(&"rim_color", LookActorsStyle.WARM_RIM)
	sm.set_shader_parameter(&"rim_strength", rim * (0.9 if plate else 1.3))
	sm.set_shader_parameter(&"bounce_strength", 0.9 if plate else 0.6)
	sm.set_shader_parameter(&"wear_color", Color(0.15, 0.14, 0.15) if plate else Color(0.66, 0.68, 0.7))
	sm.set_shader_parameter(&"wear_strength", 0.85 if plate else 0.75)
	var grit: float = 0.0
	if LookActorsStyle.grit_enabled(look, tier):
		grit = 0.85 if plate else 0.6
	sm.set_shader_parameter(&"grit_strength", grit)
	sm.set_shader_parameter(&"streak_strength", 0.6 if grit > 0.0 else 0.0)
	sm.set_shader_parameter(&"panel_strength", (0.45 if plate else 0.3) if grit > 0.0 else 0.0)
	for key: StringName in LookDevMat.overrides:  # look-dev tuning: `--tune=e_<uniform>:<value>` reaches the enemies only
		if String(key).begins_with("e_"):
			sm.set_shader_parameter(StringName(String(key).substr(2)), LookDevMat.overrides[key])
