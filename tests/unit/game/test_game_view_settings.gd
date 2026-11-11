extends GdUnitTestSuite
## GameViewSettings: saved settings and --quality reach the view; a forced --quality wins over the saved tier.


class SpyView extends BattleView:
	var tiers: Array[int] = []
	var flashes: Array[bool] = []
	var contrasts: Array[bool] = []

	func set_quality(tier: int) -> void:
		tiers.append(tier)

	func set_reduced_flash(on: bool) -> void:
		flashes.append(on)

	func set_high_contrast(on: bool) -> void:
		contrasts.append(on)


func before_test() -> void:
	GameRunKit.fresh_save()


func after_test() -> void:
	GameRunKit.reset_save()


func _spy() -> SpyView:
	var v: SpyView = SpyView.new()
	auto_free(v)
	return v


func test_the_saved_quality_is_used_when_nothing_is_forced() -> void:
	Save.set_setting(&"quality", 1)
	assert_int(GameViewSettings.quality_tier(DebugArgs.parse(PackedStringArray()))).is_equal(VisualQuality.Tier.MID)
	assert_int(GameViewSettings.quality_tier(null)).is_equal(VisualQuality.Tier.MID)


func test_the_quality_argument_overrides_the_saved_tier() -> void:
	Save.set_setting(&"quality", 2)
	var args: DebugArgs = DebugArgs.parse(PackedStringArray(["--quality=0"]))
	assert_int(GameViewSettings.quality_tier(args)).is_equal(VisualQuality.Tier.LOW)


func test_apply_pushes_all_three_settings_to_the_view() -> void:
	Save.set_setting(&"quality", 0)
	Save.set_setting(&"reduced_flash", true)
	Save.set_setting(&"high_contrast", true)
	var view: SpyView = _spy()
	GameViewSettings.apply_to_view(view, DebugArgs.parse(PackedStringArray()))
	assert_array(view.tiers).is_equal([VisualQuality.Tier.LOW])
	assert_array(view.flashes).is_equal([true])
	assert_array(view.contrasts).is_equal([true])


func test_apply_reflects_a_changed_setting_the_next_time() -> void:
	var view: SpyView = _spy()
	var args: DebugArgs = DebugArgs.parse(PackedStringArray())
	GameViewSettings.apply_to_view(view, args)
	Save.set_setting(&"high_contrast", true)
	Save.set_setting(&"quality", 1)
	GameViewSettings.apply_to_view(view, args)
	assert_array(view.contrasts).is_equal([false, true])
	assert_array(view.tiers).is_equal([VisualQuality.Tier.HIGH, VisualQuality.Tier.MID])


func test_a_forced_quality_survives_a_settings_change() -> void:
	var view: SpyView = _spy()
	var args: DebugArgs = DebugArgs.parse(PackedStringArray(["--quality=1"]))
	Save.set_setting(&"quality", 2)
	GameViewSettings.apply_to_view(view, args)
	assert_array(view.tiers).is_equal([VisualQuality.Tier.MID])


func test_a_missing_view_is_ignored() -> void:
	GameViewSettings.apply_to_view(null, DebugArgs.parse(PackedStringArray()))
	assert_bool(GameViewSettings.VIEW_KEYS.has(&"quality")).is_true()
	assert_bool(GameViewSettings.VIEW_KEYS.has(&"fps_cap")).is_false()


func test_setting_helpers_fall_back_on_a_wrong_or_missing_value() -> void:
	assert_bool(GameViewSettings.bool_setting(&"no_such_key", true)).is_true()
	assert_int(GameViewSettings.int_setting(&"no_such_key", 7)).is_equal(7)
	assert_int(GameViewSettings.int_setting(&"sound_on", 9)).is_equal(9)  # a bool is not an int
	assert_int(GameViewSettings.int_setting(&"fps_cap", 9)).is_equal(60)
