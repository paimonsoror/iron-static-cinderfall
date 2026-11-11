class_name LookDevStyle
extends RefCounted
## The look switch of the character art (W3-C look-dev spike). Three looks, one tier gate:
##  CURRENT        today's flat-palette boxes and prisms, untouched.
##  STYLISED       hard-surface Warden: bevelled and rounded forms, baked ambient occlusion and edge wear in the
##                 vertex colours, a soft lighting ramp, a cyan fresnel rim, emissive accents, secondary motion.
##  STYLISED_PLUS  STYLISED plus the "A-lite" touches: generated surface detail texture, stronger rim and specular,
##                 HDR accents with bloom on the WorldEnvironment, and a pooled muzzle light (HIGH only).
## The shipped default is CURRENT until the owner picks. The gates below decide what each look may switch on per
## quality tier (VisualQuality): LOW keeps only the baked vertex colours (free) on top of the new geometry.

enum Look { CURRENT, STYLISED, STYLISED_PLUS }

const NAMES: Array[String] = ["current", "stylised", "stylised_plus"]
## Lowest tier that gets the lighting ramp, rim, edge wear, HDR accents and secondary motion.
const SHADED_MIN_TIER: int = VisualQuality.Tier.MID
## Lowest tier with bloom (STYLISED_PLUS only). Measured on an Intel Iris Plus iGPU: see docs/reports/lookdev/README.md.
const GLOW_MIN_TIER: int = VisualQuality.Tier.MID
## Muzzle light (STYLISED_PLUS only).
const MUZZLE_LIGHT_TIER: int = VisualQuality.Tier.HIGH

## Look-dev measurement only (`--glow=0|1`): -1 = by look and tier, 0 = never, 1 = always (any look, any tier).
static var glow_override: int = -1

static var _current: int = Look.CURRENT


static func current() -> int:
	return _current


## Sets the process-wide look (clamped). Views that are already built apply it through `ActorLayer.set_look`.
static func set_current(look: int) -> void:
	_current = clampi(look, Look.CURRENT, Look.STYLISED_PLUS)


static func name_of(look: int) -> String:
	if look < 0 or look >= NAMES.size():
		return "unknown"
	return NAMES[look]


## `current`, `stylised` or `stylised_plus` (any case); anything else gives -1.
static func from_name(text: String) -> int:
	return NAMES.find(text.strip_edges().to_lower())


## New geometry and baked vertex colours (every tier).
static func styled_geometry(look: int) -> bool:
	return look != Look.CURRENT


static func ramp_enabled(look: int, tier: int) -> bool:
	return look != Look.CURRENT and tier >= SHADED_MIN_TIER


static func rim_enabled(look: int, tier: int) -> bool:
	return look != Look.CURRENT and tier >= SHADED_MIN_TIER


static func wear_enabled(look: int, tier: int) -> bool:
	return look != Look.CURRENT and tier >= SHADED_MIN_TIER


static func detail_enabled(look: int, tier: int) -> bool:
	return look == Look.STYLISED_PLUS and tier >= SHADED_MIN_TIER


static func glow_enabled(look: int, tier: int) -> bool:
	if glow_override >= 0:
		return glow_override == 1
	return look == Look.STYLISED_PLUS and tier >= GLOW_MIN_TIER


static func muzzle_light_enabled(look: int, tier: int) -> bool:
	return look == Look.STYLISED_PLUS and tier >= MUZZLE_LIGHT_TIER


## Springs, breathing and the reload pose move a few node transforms: no GPU cost, so every tier keeps them.
static func secondary_motion_enabled(look: int, _tier: int) -> bool:
	return look != Look.CURRENT


## Brightness of the emissive accents (visor, belt, lights): above 1 only where bloom may pick it up.
static func accent_energy(look: int, tier: int) -> float:
	if look == Look.CURRENT or tier < SHADED_MIN_TIER:
		return 1.0
	if look == Look.STYLISED_PLUS:
		return 2.2
	return 1.5


static func rim_strength(look: int) -> float:
	if look == Look.STYLISED_PLUS:
		return 0.8
	if look == Look.STYLISED:
		return 0.4
	return 0.0
