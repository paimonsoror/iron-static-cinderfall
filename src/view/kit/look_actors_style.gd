class_name LookActorsStyle
extends RefCounted
## Gates of the actor rollout (W3-D): the hard-surface look of the turret, the three pooled enemies and the Hulk. Every
## decision is a function of (look, tier) here and in `LookDevStyle`; CURRENT answers "off" to all of them.
##  - `enabled(look)`: the actors use their styled meshes and materials. `rollout_override` (sandbox `--rollout=0|1`) is a
##    measurement switch only: 0 keeps the actors in CURRENT while the Warden is styled (the state of main before W3-D).
##  - `grit_enabled`: the per-pixel weathering of the enemy shader (scratches, chips, speckle). LOW keeps only the baked
##    vertex colours (grime, edge wear, ambient occlusion), which cost nothing.
##  - `optic_energy`: brightness of the red optic. Above 1 only where bloom (`LookDevStyle.glow_enabled`) may pick it up, and
##    only in the red channel, so a halo is red and never white.

## -1 = by look, 0 = actors stay CURRENT, 1 = actors styled in any look except CURRENT.
static var rollout_override: int = -1

const OPTIC_SATURATION: float = 0.8
const OPTIC_GLOW: float = 1.6
const OPTIC_PLAIN: float = 1.0
## Orange of the fires and the muzzle flashes (rim and bounce on the enemy plates).
const WARM_RIM: Color = Color(0.98, 0.52, 0.2, 1.0)


static func enabled(look: int) -> bool:
	if look == LookDevStyle.Look.CURRENT:
		return false
	return rollout_override != 0


static func grit_enabled(look: int, tier: int) -> bool:
	return enabled(look) and tier >= LookDevStyle.SHADED_MIN_TIER


## The warm orange rim of the enemy plates (MID and HIGH).
static func warm_rim_strength(look: int, tier: int) -> float:
	if not enabled(look) or tier < LookDevStyle.SHADED_MIN_TIER:
		return 0.0
	return 0.85 if look == LookDevStyle.Look.STYLISED_PLUS else 0.7


static func optic_energy(look: int, tier: int) -> float:
	if enabled(look) and LookDevStyle.glow_enabled(look, tier):
		return OPTIC_GLOW
	return OPTIC_PLAIN


## The colour of the optic at brightness `energy`: the palette red pushed to a hot, saturated value (not whitened: a paler
## optic loses contrast against the bone plates it sits on).
static func optic_color(base: Color, energy: float) -> Color:
	var hot: Color = Color.from_hsv(base.h, OPTIC_SATURATION, 1.0)
	return Color(hot.r * energy, hot.g * minf(energy, 1.0), hot.b * minf(energy, 1.0), 1.0)
