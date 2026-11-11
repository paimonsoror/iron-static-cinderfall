class_name VisualQuality
extends RefCounted
## Quality tiers change the view only (shadows, omni lights, particle counts, rain, render scale).
## They never change the tick rate or any outcome (ARCH 13).

enum Tier { LOW, MID, HIGH }


## Maps the profile setting `quality` (0..2) to a tier; out-of-range values are clamped.
static func from_setting(value: int) -> int:
	return clampi(value, Tier.LOW, Tier.HIGH)


static func name_of(tier: int) -> String:
	match tier:
		Tier.LOW:
			return "LOW"
		Tier.MID:
			return "MID"
		Tier.HIGH:
			return "HIGH"
	return "UNKNOWN"


## Max unshadowed OmniLight3D nodes (ARCH 8): 4 on HIGH, 0 on LOW.
static func omni_light_budget(tier: int) -> int:
	match tier:
		Tier.HIGH:
			return 4
		Tier.MID:
			return 2
	return 0


## Directional shadows for static props only on HIGH.
static func shadows_enabled(tier: int) -> bool:
	return tier == Tier.HIGH
