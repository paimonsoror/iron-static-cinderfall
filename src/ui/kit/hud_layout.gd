class_name HudLayout
extends RefCounted
## Heights of the HUD bands, used to fit the camera into the space between them (ARCH 9).


## Top band: top_hud_fraction of the height plus the top safe-area margin.
static func top_band_px(viewport_size: Vector2, margins: Vector4, tokens: VisualTokens) -> float:
	return viewport_size.y * tokens.top_hud_fraction + margins.y


## Bottom band: bottom_controls_fraction of the height plus the bottom safe-area margin.
static func bottom_band_px(viewport_size: Vector2, margins: Vector4, tokens: VisualTokens) -> float:
	return viewport_size.y * tokens.bottom_controls_fraction + margins.w
