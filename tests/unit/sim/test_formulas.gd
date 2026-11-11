extends GdUnitTestSuite
## Golden values of ARCH 6.5 / GDD 5.2.


func _costs(base: int, growth: float, levels: int) -> Array[int]:
	var out: Array[int] = []
	for level: int in levels:
		out.append(Formulas.upgrade_cost(base, growth, level))
	return out


func test_damage_costs() -> void:
	assert_array(_costs(175, 1.7, 5)).is_equal([175, 298, 506, 860, 1462])


func test_fire_rate_costs() -> void:
	assert_array(_costs(150, 1.6, 5)).is_equal([150, 240, 384, 614, 983])


func test_armor_piercing_costs() -> void:
	assert_array(_costs(200, 1.8, 5)).is_equal([200, 360, 648, 1166, 2100])


func test_turret_and_smg_costs() -> void:
	assert_array(_costs(350, 2.0, 2)).is_equal([350, 700])
	assert_int(Formulas.upgrade_cost(300, 1.0, 0)).is_equal(300)


func test_hit_damage_golden_values() -> void:
	assert_float(Formulas.hit_damage(30.0, 0, 0.2, 8.0)).is_equal(22.0)
	assert_float(Formulas.hit_damage(15.0, 0, 0.2, 12.0)).is_equal(3.0)
	assert_float(Formulas.hit_damage(12.0, 0, 0.0, 12.0)).is_equal(1.0)


func test_hit_damage_scales_with_damage_level() -> void:
	assert_float(Formulas.hit_damage(30.0, 5, 0.2, 0.0)).is_equal_approx(60.0, 0.0001)


func test_effective_armor_golden_values() -> void:
	assert_float(Formulas.effective_armor(12.0, 5, 0.15, 0.9)).is_equal_approx(3.0, 0.0001)
	assert_float(Formulas.effective_armor(12.0, 6, 0.15, 0.9)).is_equal_approx(1.2, 0.0001)
	assert_float(Formulas.effective_armor(12.0, 0, 0.15, 0.9)).is_equal(12.0)
	assert_float(Formulas.effective_armor(0.0, 5, 0.15, 0.9)).is_equal(0.0)


func test_shots_per_second_milli() -> void:
	assert_int(Formulas.sps_milli(2000, 0, 0.15, 1000)).is_equal(2000)
	assert_int(Formulas.sps_milli(2000, 1, 0.15, 1000)).is_equal(2300)
	assert_int(Formulas.sps_milli(2000, 0, 0.15, 2000)).is_equal(4000)
	assert_int(Formulas.sps_milli(6000, 5, 0.15, 1000)).is_equal(10500)


func test_ticks_conversion() -> void:
	assert_int(Formulas.ticks(1.0)).is_equal(60)
	assert_int(Formulas.ticks(0.4)).is_equal(24)
	assert_int(Formulas.ticks(1.25)).is_equal(75)
	assert_int(Formulas.ticks(1.7)).is_equal(102)
	assert_int(Formulas.ticks(8.0)).is_equal(480)


func test_data_reward() -> void:
	var m: MissionDef = TestContent.baseline().mission
	assert_int(Formulas.data_reward(RunResult.Id.VICTORY, 5, 1000.0, m)).is_equal(150)
	assert_int(Formulas.data_reward(RunResult.Id.VICTORY, 5, 399.0, m)).is_equal(119)
	assert_int(Formulas.data_reward(RunResult.Id.VICTORY, 5, 1.0, m)).is_equal(100)
	assert_int(Formulas.data_reward(RunResult.Id.DEFEAT, 3, 0.0, m)).is_equal(30)
	assert_int(Formulas.data_reward(RunResult.Id.DEFEAT, 0, 0.0, m)).is_equal(0)
	assert_int(Formulas.data_reward(RunResult.Id.ABANDONED, 2, 500.0, m)).is_equal(0)
