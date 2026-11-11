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

## MSAA samples per tier for the hard-surface looks (see docs/reports/lookdev/README.md, round 3: measured on an iGPU).
const MSAA_LOW: int = 0
const MSAA_MID: int = 2
const MSAA_HIGH: int = 4
const ACCENT_STYLISED: float = 0.97
const ACCENT_PLUS: float = 1.5

## Anti-aliasing investigation (sandbox `--msaa=0|2|4`, `--fxaa=0|1`): -1 = by look and tier.
static var msaa_override: int = -1
static var fxaa_override: int = -1

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


## Brightness of the emissive accents (visor, belt, lights, back panel; the albedo of an unshaded material is its colour):
## above 1 only where bloom may pick it up. STYLISED stays just under the clip point (the cyan reads as light, not as a
## white blob).
static func accent_energy(look: int, tier: int) -> float:
	if look == Look.CURRENT:
		return 1.0
	if look == Look.STYLISED_PLUS and tier >= SHADED_MIN_TIER:
		return ACCENT_PLUS
	return ACCENT_STYLISED


## Value gain of the plate and suit materials (round 3): vertex colours are 8 bit and cannot go above 1, so the steel is
## lifted here and the vertex tints only say lighter or darker. `bone` is the ceramic (bone) plates.
static func value_gain(look: int, bone: bool) -> float:
	if look == Look.CURRENT:
		return 1.0
	return 1.0 if bone else 2.4


## MSAA samples (0, 2 or 4) of the 3D viewport for a look at a tier. CURRENT keeps the project default (none): the hard-
## surface looks are where the jagged silhouettes of rounded armour show. `project.godot` stays untouched.
static func msaa_samples(look: int, tier: int) -> int:
	if msaa_override >= 0:
		return msaa_override
	if look == Look.CURRENT:
		return 0
	if tier >= VisualQuality.Tier.HIGH:
		return MSAA_HIGH
	if tier >= VisualQuality.Tier.MID:
		return MSAA_MID
	return MSAA_LOW


## FXAA (a post pass on the resolved image) for a look at a tier: only by the investigation flag so far.
static func fxaa_enabled(_look: int, _tier: int) -> bool:
	return fxaa_override == 1


## Sets the anti-aliasing of `viewport` for a look and tier (ArenaView calls it when the tier or the look changes).
static func apply_aa(viewport: Viewport, look: int, tier: int) -> void:
	if viewport == null:
		return
	match msaa_samples(look, tier):
		4:
			viewport.msaa_3d = Viewport.MSAA_4X
		2:
			viewport.msaa_3d = Viewport.MSAA_2X
		_:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = (
		Viewport.SCREEN_SPACE_AA_FXAA if fxaa_enabled(look, tier) else Viewport.SCREEN_SPACE_AA_DISABLED
	)


## Strength of the camera-side fill of the plate shader (round 3, MID and HIGH).
static func fill_strength(look: int) -> float:
	return 0.0 if look == Look.CURRENT else 0.6


static func rim_strength(look: int) -> float:
	if look == Look.STYLISED_PLUS:
		return 1.15
	if look == Look.STYLISED:
		return 0.95
	return 0.0
