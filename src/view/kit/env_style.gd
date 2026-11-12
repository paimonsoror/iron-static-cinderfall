class_name EnvStyle
extends RefCounted
## The gates of the environment grit pass (W3-E): which effects of the new gritty yard each (look, tier) may switch on.
## Rule: `LookDevStyle.Look.CURRENT` gets nothing (today's yard, untouched); STYLISED and STYLISED_PLUS get the pass.
## Every effect has a lowest tier; LOW stays cheap and static. Nothing here changes the sim or an outcome.
## `only` / `no` are look-dev measurement overrides (sandbox `--env=off|only:a,b|no:a,b`): the cost of an effect is measured
## with `only` (the effect alone over the old yard) and with `no` (everything except the effect).

const FLOOR: StringName = &"floor"  ## darker asphalt: detail texture, slabs, seams, cracks, patches, stains, markings
const WET: StringName = &"wet"  ## puddle mask and fake reflections of the lit sources (a shader term; LOW keeps a baked wet tone)
const PROPS: StringName = &"props"  ## detailed containers, crates, barrels, barriers, lamp posts (geometry and baked colours)
const PROP_SHADER: StringName = &"prop_shader"  ## prop shading: grime streaks, warm bounce, wet gloss
const REACTOR: StringName = &"reactor"  ## lit panels, ring lights and a halo on the core
const SPILL: StringName = &"spill"  ## warm pools and halos of the lamps, cool pools of the pads
const VIGNETTE: StringName = &"vignette"  ## dark screen edges
const GRADE: StringName = &"grade"  ## tonemap, contrast and saturation on the Environment
const GLOW: StringName = &"glow"  ## bloom on the HDR lamps and reactor windows
const RIPPLES: StringName = &"ripples"  ## rain rings on the puddles
const FLICKER: StringName = &"flicker"  ## lamp and reactor flicker reaches the reflections

const ALL: Array[StringName] = [
	FLOOR, WET, PROPS, PROP_SHADER, REACTOR, SPILL, VIGNETTE, GRADE, GLOW, RIPPLES, FLICKER
]

## Lowest tier of every effect (VisualQuality.Tier). Measured on the dev iGPU: docs/reports/lookdev/README.md, round 5.
const MIN_TIER: Dictionary[StringName, int] = {
	FLOOR: VisualQuality.Tier.LOW,
	WET: VisualQuality.Tier.MID,
	PROPS: VisualQuality.Tier.LOW,
	PROP_SHADER: VisualQuality.Tier.MID,
	REACTOR: VisualQuality.Tier.LOW,
	SPILL: VisualQuality.Tier.LOW,
	VIGNETTE: VisualQuality.Tier.LOW,
	GRADE: VisualQuality.Tier.LOW,
	GLOW: VisualQuality.Tier.HIGH,
	RIPPLES: VisualQuality.Tier.HIGH,
	FLICKER: VisualQuality.Tier.MID,
}

## Look-dev overrides. `only` non-empty: just those effects; `no`: never those. Both empty: by look and tier.
static var only: Array[StringName] = []
static var no: Array[StringName] = []


## True when effect `fx` is on for `look` at `tier`.
static func on(fx: StringName, look: int, tier: int) -> bool:
	if look == LookDevStyle.Look.CURRENT:
		return false
	if not only.is_empty() and not only.has(fx):
		return false
	if no.has(fx):
		return false
	return tier >= MIN_TIER.get(fx, VisualQuality.Tier.HIGH)


## The sandbox flag: `off`, `only:a,b`, `no:a,b` (anything else resets to the default gates).
static func set_override(text: String) -> void:
	only = []
	no = []
	var t: String = text.strip_edges().to_lower()
	if t == "off":
		only = [&"none"]
		return
	var colon: int = t.find(":")
	if colon < 0:
		return
	var names: Array[StringName] = []
	for part: String in t.substr(colon + 1).split(",", false):
		names.append(StringName(part.strip_edges()))
	if t.begins_with("only"):
		only = names
	elif t.begins_with("no"):
		no = names


## Colour adjustment of the Environment (GRADE): a little contrast, slightly muted colour. The tonemapper stays LINEAR on purpose: a filmic or
## ACES curve lifted the pad's amber glow and rolled the Warden's highlights off, and the Warden's contrast against its pad fell under the
## legibility floor (round 5 measurement: pixel contrast 0.155 with filmic against 0.208 before). The HDR lamp heads clip to a warm white
## and the bloom (HIGH) carries them.
const GRADE_TONEMAP: int = Environment.TONE_MAPPER_LINEAR
const GRADE_EXPOSURE: float = 0.92
const GRADE_WHITE: float = 1.0
const GRADE_CONTRAST: float = 1.06
const GRADE_SATURATION: float = 0.94

## Bloom of the styled yard: only values above 1.0 glow (the HDR lamp heads and reactor windows).
const LAMP_GAIN: float = 2.2
const REACTOR_GAIN: float = 0.95
const WINDOW_GAIN: float = 1.7

## Peak alpha of the additive halos (reactor, lamps, turret pads).
## The core's own light pool under the Warden's pad: below 1 on purpose (the Warden's contrast against its pad is the legibility floor).
const CORE_POOL_GAIN: float = 0.75
const REACTOR_HALO: float = 0.42
const LAMP_HALO: float = 0.5
const PAD_HALO: float = 0.3
