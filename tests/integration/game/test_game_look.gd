extends GdUnitTestSuite
## The character look at boot (W3-C hand-off): `Game.boot` sets the shipped look (or `--look=`) before any BattleView is
## built, and takes it back when the Game leaves the tree, so no test leaks its look into the next one.

var _h: GameHarness


func before_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func test_boot_sets_the_shipped_look_and_dispose_restores_the_previous_one() -> void:
	_h = GameHarness.create(self)
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.CURRENT)  # nothing before boot
	_h.boot()
	assert_int(LookDevStyle.current()).is_equal(GameViewSettings.SHIPPED_LOOK)
	assert_int(GameViewSettings.SHIPPED_LOOK).is_not_equal(LookDevStyle.Look.CURRENT)
	_h.dispose()
	_h = null
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.CURRENT)


func test_the_look_flag_overrides_the_shipped_look() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--look=stylised_plus"]))
	_h.boot()
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.STYLISED_PLUS)
	_h.dispose()
	_h = null
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.CURRENT)


func test_look_current_can_be_forced_for_a_comparison_run() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--look=current"]))
	_h.boot()
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.CURRENT)
