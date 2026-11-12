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


## Size of the directional shadow atlas in pixels. The engine default (4096, 16 bit) costs 32 MB of video memory on HIGH
## (measured: vid_mb 58.8 on MID, 100.5 on HIGH); one orthogonal light over a 28 m yard needs a quarter of that.
static func shadow_atlas_size(tier: int) -> int:
	if tier == Tier.HIGH:
		return 2048
	return 1024


## Rain streaks only on HIGH.
static func rain_enabled(tier: int) -> bool:
	return tier == Tier.HIGH


## 3D render scale (the UI stays at full resolution): the 30 FPS fallback tier draws fewer pixels.
static func render_scale(tier: int) -> float:
	if tier == Tier.LOW:
		return 0.75
	return 1.0


## Applies the render scale to a viewport. Never touches the tick rate or any outcome.
static func apply_render_scale(viewport: Viewport, tier: int) -> void:
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale(tier)


# --- VARIETY_SPEC 10.3 and 10.4: what each tier draws of the chaos effects. The pools are allocated once for the HIGH size and
# limited below it (`VfxPool.set_limit`), so a tier change never allocates; the sim is identical on every tier. ---

## Blast rings (FLAT, one pool per colour), blast flashes (BILLBOARD, none on LOW), debris streaks per blast (HIGH only), arc
## segments (3 per jump), telegraph decals (never tier-gated: what can hurt you is always drawn), mini bodies (one MultiMesh per type).
const BLAST_RING_CAP: Array[int] = [8, 12, 16]
const BLAST_FLASH_CAP: Array[int] = [0, 8, 12]
const BLAST_STREAKS: Array[int] = [0, 0, 4]
const ARC_SEGMENT_CAP: Array[int] = [18, 30, 45]
const TELEGRAPH_CAP: Array[int] = [8, 8, 8]
const MINI_CAP: Array[int] = [40, 40, 40]


static func blast_rings(tier: int) -> int:
	return BLAST_RING_CAP[clampi(tier, Tier.LOW, Tier.HIGH)]


static func blast_flashes(tier: int) -> int:
	return BLAST_FLASH_CAP[clampi(tier, Tier.LOW, Tier.HIGH)]


static func blast_streaks(tier: int) -> int:
	return BLAST_STREAKS[clampi(tier, Tier.LOW, Tier.HIGH)]


static func arc_segments(tier: int) -> int:
	return ARC_SEGMENT_CAP[clampi(tier, Tier.LOW, Tier.HIGH)]


static func telegraph_decals(tier: int) -> int:
	return TELEGRAPH_CAP[clampi(tier, Tier.LOW, Tier.HIGH)]


static func mini_bodies(tier: int) -> int:
	return MINI_CAP[clampi(tier, Tier.LOW, Tier.HIGH)]
