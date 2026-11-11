extends GdUnitTestSuite
## Validator-stage bad fixtures (tests/fixtures/data_bad): the data loads, but a rule of ARCH 5.4 is broken. Each
## fixture produces exactly the expected error, with the source file and JSON path.


func _check(fixture_id: String) -> void:
	var f: BadDataFixture = BadDataFixture.run(fixture_id)
	assert_int(f.expect.size()).is_greater(0)
	assert_str("\n".join(f.errors)).is_equal("\n".join(f.expect))
	assert_str(f.stage).is_equal("validator")
	assert_str(f.expected_stage).is_equal("validator")


func test_negative_hp() -> void:
	_check("negative_hp")


func test_duplicate_wave_index() -> void:
	_check("duplicate_wave_index")


func test_missing_wave() -> void:
	_check("missing_wave")


func test_wave_index_out_of_range() -> void:
	_check("wave_index_out_of_range")


func test_waves_out_of_order() -> void:
	_check("wave_out_of_order")


func test_zero_count() -> void:
	_check("zero_count")


func test_zero_interval() -> void:
	_check("zero_interval")


func test_too_few_slots() -> void:
	_check("too_few_slots")


func test_negative_upgrade_cost() -> void:
	_check("negative_upgrade_cost")


func test_growth_below_one() -> void:
	_check("growth_below_one")


func test_zero_cooldown() -> void:
	_check("zero_cooldown")


func test_zero_enemy_cap() -> void:
	_check("zero_enemy_cap")


func test_obstacle_near_core() -> void:
	_check("obstacle_near_core")


func test_warden_outside_bounds() -> void:
	_check("warden_outside_bounds")


func test_turret_pad_outside_bounds() -> void:
	_check("pad_outside_bounds")


func test_every_fixture_file_has_a_passing_case() -> void:
	# Catches a fixture added without a named test above: every file must produce exactly its expectation.
	var ids: PackedStringArray = BadDataFixture.all_ids()
	assert_int(ids.size()).is_greater_equal(28)
	for fixture_id: String in ids:
		var f: BadDataFixture = BadDataFixture.run(fixture_id)
		assert_int(f.expect.size()).is_greater(0)
		assert_str("%s: %s" % [fixture_id, "\n".join(f.errors)]).is_equal("%s: %s" % [fixture_id, "\n".join(f.expect)])
		assert_str(f.stage).is_equal(f.expected_stage)
