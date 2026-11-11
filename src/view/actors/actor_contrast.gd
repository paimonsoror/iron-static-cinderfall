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

const OPTIC_ENERGY: float = 1.8
const OPTIC_SATURATION: float = 0.92
const PLATE_LIFT: float = 0.1
const FRAME_LIFT: float = 0.32
const RIM: float = 1.0
const RIM_TINT: float = 0.35

static var _variants: Dictionary[StringName, StandardMaterial3D] = {}


## Rebuilds the variants from the current MatLib materials (call after MatLib.configure).
static func rebuild() -> void:
	_variants.clear()
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
