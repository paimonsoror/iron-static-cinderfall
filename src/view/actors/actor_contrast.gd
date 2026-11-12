class_name ActorContrast
extends RefCounted
## High Contrast look of the enemies (GDD 10.3: "brightens enemy optics and rims"). Three shared variants of the enemy
## materials, built on demand from the current MatLib palette and applied as SURFACE overrides, so the hit flash
## (`material_override`) still wins and the pooled views keep one MeshInstance3D each:
##  - optic (`emit_red`): the palette red pushed to full value and 92 percent saturation with a stronger glow, so the
##    single optic is the hottest point of a silhouette. It is NOT whitened: a paler optic loses contrast against the
##    bone plates it sits on;
##  - frame (`gunmetal`, the legs and arms that make the silhouette edge): an emission lift, so the edge of the machine
##    separates from the wet dark ground even in an unlit corner;
##  - plates (`ceramic`): a small lift as well. Both also get the engine rim light (little effect on flat faces under
##    this camera, but it costs nothing and follows the material if the models become smooth).
## The hue never changes (red stays the enemy color); only brightness and saturation do.
## W3-D: in the hard-surface looks the enemies wear the look's materials (`LookActorsMat`), so `variant_for` builds the High
## Contrast twin of THOSE: a shader material with a stronger warm rim, fill and value gain (a baked StandardMaterial3D on LOW
## gets the emission lift and engine rim), and a hotter optic. Without it High Contrast would silently bring the old look back.

const OPTIC_ENERGY: float = 1.8
const OPTIC_SATURATION: float = 0.92
const PLATE_LIFT: float = 0.1
const FRAME_LIFT: float = 0.32
const RIM: float = 1.0
const RIM_TINT: float = 0.35

const LOOK_RIM_ADD: float = 1.2
const LOOK_FILL_ADD: float = 0.35
const LOOK_GAIN_MULT: float = 1.12
const LOOK_OPTIC_BOOST: float = 0.45
## The shader parameters of the enemy materials that a variant copies from its base every time it is asked for.
const LOOK_PARAMS: Array[StringName] = [
	&"albedo_tint", &"value_gain", &"fill_strength", &"roughness", &"spec_strength", &"rim_color", &"rim_strength",
	&"bounce_strength", &"wear_color", &"wear_strength", &"grit_strength", &"streak_strength", &"panel_strength",
]

static var _variants: Dictionary[StringName, StandardMaterial3D] = {}
static var _look_variants: Dictionary[String, Material] = {}


## Rebuilds the variants from the current MatLib materials (call after MatLib.configure).
static func rebuild() -> void:
	_variants.clear()
	_look_variants.clear()
	_variants[&"emit_red"] = _optic(MatLib.mat(&"emit_red"))
	_variants[&"ceramic"] = _lit(MatLib.mat(&"ceramic"), PLATE_LIFT)
	_variants[&"gunmetal"] = _lit(MatLib.mat(&"gunmetal"), FRAME_LIFT)


## The high-contrast twin of an enemy surface material, or null when it has none.
static func variant_of(base: Material) -> Material:
	if _variants.is_empty():
		rebuild()
	var key: StringName = StringName(base.resource_name)
	if _variants.has(key):
		return _variants[key]
	return null


## The High Contrast twin of the surface of role `role` of an enemy in `look` at `tier`: the old variant in CURRENT (or when the
## actor rollout is off), a twin of the look's shared material otherwise, null when the role has none. Shared per (role, look,
## shader class), repainted from the base on every call.
static func variant_for(role: StringName, look: int, tier: int) -> Material:
	if not LookActorsStyle.enabled(look):
		return variant_of(MatLib.mat(role))
	var base: Material = LookActorsMat.surface(role, look, tier)
	if base == MatLib.mat(role):
		return null
	var key: String = "%s|%d|%d" % [role, look, 1 if LookDevStyle.ramp_enabled(look, tier) else 0]
	if not _look_variants.has(key):
		_look_variants[key] = _look_twin(base)
	var twin: Material = _look_variants[key]
	_look_repaint(twin, base, role)
	return twin


## Relative luminance of a material's visible color (albedo plus emission); tests compare base and variant.
static func brightness(m: StandardMaterial3D) -> float:
	var c: Color = m.albedo_color
	if m.emission_enabled:
		c = Color(
			minf(c.r + m.emission.r * m.emission_energy_multiplier, 1.0),
			minf(c.g + m.emission.g * m.emission_energy_multiplier, 1.0),
			minf(c.b + m.emission.b * m.emission_energy_multiplier, 1.0)
		)
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


static func _optic(base: StandardMaterial3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	m.resource_name = "emit_red_hc"
	var hot: Color = Color.from_hsv(base.albedo_color.h, OPTIC_SATURATION, 1.0)
	m.albedo_color = hot
	m.emission = hot
	m.emission_energy_multiplier = OPTIC_ENERGY
	return m


static func _lit(base: StandardMaterial3D, lift: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	m.resource_name = String(base.resource_name) + "_hc"
	m.rim_enabled = true
	m.rim = RIM
	m.rim_tint = RIM_TINT
	m.emission_enabled = true
	m.emission = base.albedo_color
	m.emission_energy_multiplier = lift
	return m


static func _look_twin(base: Material) -> Material:
	var sm: ShaderMaterial = base as ShaderMaterial
	if sm != null:
		var twin: ShaderMaterial = ShaderMaterial.new()
		twin.shader = sm.shader
		twin.resource_name = String(sm.resource_name) + "_hc"
		return twin
	var std: StandardMaterial3D = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	std.resource_name = String(base.resource_name) + "_hc"
	return std


static func _look_repaint(twin: Material, base: Material, role: StringName) -> void:
	var sm: ShaderMaterial = twin as ShaderMaterial
	if sm != null:
		var src: ShaderMaterial = base as ShaderMaterial
		for param: StringName in LOOK_PARAMS:
			sm.set_shader_parameter(param, src.get_shader_parameter(param))
		var rim: float = src.get_shader_parameter(&"rim_strength")
		var fill: float = src.get_shader_parameter(&"fill_strength")
		var gain: float = src.get_shader_parameter(&"value_gain")
		sm.set_shader_parameter(&"rim_strength", rim + LOOK_RIM_ADD)
		sm.set_shader_parameter(&"fill_strength", fill + LOOK_FILL_ADD)
		sm.set_shader_parameter(&"value_gain", gain * LOOK_GAIN_MULT)
		return
	var std: StandardMaterial3D = twin as StandardMaterial3D
	var plain: StandardMaterial3D = base as StandardMaterial3D
	if role == &"emit_red":
		var hot: Color = Color.from_hsv(plain.albedo_color.h, 0.95, 1.0)
		var boost: float = maxf(plain.albedo_color.r, 1.0) + LOOK_OPTIC_BOOST
		std.albedo_color = Color(hot.r * boost, hot.g, hot.b, 1.0)
		return
	std.albedo_color = plain.albedo_color
	std.rim_enabled = true
	std.rim = RIM
	std.rim_tint = RIM_TINT
	std.emission_enabled = true
	std.emission = plain.albedo_color
	std.emission_energy_multiplier = PLATE_LIFT if role == &"ceramic" else FRAME_LIFT
