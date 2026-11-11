class_name GameCameraFit
extends RefCounted
## Keeps the battle camera between the HUD bands (ARCH 8, 9): the playable rectangle sits below the top bar and above
## the bottom controls at every window shape from 9:20 to 1:1. The HUD reports its own band heights (they include the
## safe area); without a HUD (menu backdrops, tests) the token fractions are used.


## Fits the view's camera for a viewport of `viewport_size` (viewport units, i.e. 1080 wide base pixels).
static func refit(view: BattleView, hud: CombatHud, viewport_size: Vector2, tokens: VisualTokens) -> void:
	if view == null or viewport_size.x < 2.0 or viewport_size.y < 2.0:
		return
	var bands: Vector2 = bands_for(hud, viewport_size, tokens)
	view.fit_camera(viewport_size, bands.x, bands.y)


## (top_px, bottom_px).
static func bands_for(hud: CombatHud, viewport_size: Vector2, tokens: VisualTokens) -> Vector2:
	if hud != null and is_instance_valid(hud):
		return Vector2(hud.top_band_px(), hud.bottom_band_px())
	return Vector2(
		HudLayout.top_band_px(viewport_size, Vector4.ZERO, tokens),
		HudLayout.bottom_band_px(viewport_size, Vector4.ZERO, tokens)
	)
