extends GdUnitTestSuite
## GameCameraFit: the camera is refitted between the HUD bands for every window shape.


class SpyView extends BattleView:
	var fits: Array[Dictionary] = []

	func fit_camera(viewport_size: Vector2, top_px: float, bottom_px: float) -> void:
		fits.append({"size": viewport_size, "top": top_px, "bottom": bottom_px})


func _spy() -> SpyView:
	var v: SpyView = SpyView.new()
	auto_free(v)
	return v


func test_without_a_hud_the_token_fractions_give_the_bands() -> void:
	var tokens: VisualTokens = TestContent.baseline().tokens
	var size: Vector2 = Vector2(1080.0, 1920.0)
	var bands: Vector2 = GameCameraFit.bands_for(null, size, tokens)
	assert_float(bands.x).is_equal_approx(1920.0 * tokens.top_hud_fraction, 0.01)
	assert_float(bands.y).is_equal_approx(1920.0 * tokens.bottom_controls_fraction, 0.01)


func test_with_a_hud_its_own_band_heights_are_used() -> void:
	var api: FakeRunApi = FakeRunApi.new()
	var hud: CombatHud = CombatHudTestKit.make_hud(self, api, Vector2(1080.0, 2400.0))
	var bands: Vector2 = GameCameraFit.bands_for(hud, Vector2(1080.0, 2400.0), TestContent.baseline().tokens)
	assert_float(bands.x).is_equal(hud.top_band_px())
	assert_float(bands.y).is_equal(hud.bottom_band_px())
	assert_float(bands.x).is_greater_equal(CombatHud.TOP_MIN)
	assert_float(bands.y).is_greater_equal(CombatHud.BOTTOM_MIN)


func test_refit_hands_the_viewport_size_and_the_bands_to_the_view() -> void:
	var view: SpyView = _spy()
	var tokens: VisualTokens = TestContent.baseline().tokens
	for size: Vector2 in [Vector2(1080.0, 1920.0), Vector2(1080.0, 2400.0), Vector2(1080.0, 1080.0), Vector2(1440.0, 1080.0)]:
		view.fits.clear()
		GameCameraFit.refit(view, null, size, tokens)
		assert_int(view.fits.size()).is_equal(1)
		assert_vector(view.fits[0]["size"]).is_equal(size)
		var bands: Vector2 = GameCameraFit.bands_for(null, size, tokens)
		assert_float(view.fits[0]["top"]).is_equal(bands.x)
		assert_float(view.fits[0]["bottom"]).is_equal(bands.y)


func test_refit_ignores_a_missing_view_and_a_degenerate_viewport() -> void:
	var view: SpyView = _spy()
	var tokens: VisualTokens = TestContent.baseline().tokens
	GameCameraFit.refit(null, null, Vector2(1080.0, 1920.0), tokens)
	GameCameraFit.refit(view, null, Vector2.ZERO, tokens)
	GameCameraFit.refit(view, null, Vector2(1.0, 1.0), tokens)
	assert_int(view.fits.size()).is_equal(0)


func test_a_real_camera_follows_the_hud_bands_when_the_window_changes_shape() -> void:
	var content: ContentSet = TestContent.baseline()
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate() as BattleView
	auto_free(view)
	add_child(view)
	view.setup(content)
	for size: Vector2 in [Vector2(1080.0, 1920.0), Vector2(1080.0, 2400.0), Vector2(1080.0, 1080.0)]:
		var hud: CombatHud = CombatHudTestKit.make_hud(self, FakeRunApi.new(), size)
		GameCameraFit.refit(view, hud, size, content.tokens)
		var solved: CameraFitResult = CameraFit.solve(content.arena, size, hud.top_band_px(), hud.bottom_band_px())
		assert_float(view.camera_rig.px_per_meter()).is_equal_approx(solved.px_per_meter, 0.001)
		assert_float(view.camera_rig.camera.size).is_equal_approx(solved.ortho_size, 0.001)
		# the arena stays between the HUD bands: its core is below the top band and above the bottom band
		var core: Vector2 = view.world_to_screen(content.arena.core_x, content.arena.core_z)
		assert_float(core.y).is_greater(hud.top_band_px())
		assert_float(core.y).is_less(size.y - hud.bottom_band_px())
