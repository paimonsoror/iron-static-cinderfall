extends GdUnitTestSuite
## V1-S: the validator rules of VARIETY_SPEC 13.1, each with a bad fixture (tests/fixtures/data_bad_variety): the
## variety fixture plus one broken value produces exactly the expected error, with the source file and JSON path.

const MIN_FIXTURES: int = 28


func _check(fixture_id: String) -> void:
	var f: VarietyBadData = VarietyBadData.run(fixture_id)
	assert_int(f.expect.size()).is_greater(0)
	assert_str("%s: %s" % [fixture_id, "\n".join(f.errors)]).is_equal("%s: %s" % [fixture_id, "\n".join(f.expect)])
	assert_str(f.stage).is_equal(f.expected_stage)


func test_the_unpatched_variety_fixture_is_clean() -> void:
	var res: ContentLoadResult = VarietyBadData.build(VarietyBadData.docs())
	assert_str("\n".join(res.errors)).is_empty()
	assert_str("\n".join(ContentValidator.validate(res.content))).is_empty()


func test_pack_shares_sum_to_one() -> void:
	_check("pack_shares")


func test_every_wave_has_a_pack_for_its_act() -> void:
	_check("no_pack_for_act")


func test_a_boss_wave_needs_a_boss_in_its_act_pool() -> void:
	_check("no_boss_for_act")


func test_alive_cap_is_at_least_one() -> void:
	_check("alive_cap_zero")


func test_weights_are_not_all_zero() -> void:
	_check("rarity_weights_zero")
	_check("route_weights_zero")
	_check("tier_weights_zero")
	_check("world_event_weights_zero")


func test_ops_name_real_stats_flags_and_grants() -> void:
	_check("op_unknown_stat")
	_check("op_unknown_flag")
	_check("op_unknown_grant_id")


func test_every_referenced_id_exists() -> void:
	_check("unlock_unknown_item")
	_check("directive_unknown_pool")
	_check("pack_unknown_enemy")
	_check("duplicate_directive_id")


func test_unlock_grants_are_disjoint_and_kit_zero_is_free() -> void:
	_check("unlock_grants_overlap")
	_check("kit_zero_costs")


func test_points_are_free_cells_that_reach_the_core() -> void:
	_check("drop_point_in_obstacle")
	_check("breach_point_outside")


func test_rail_lines_cross_no_pad_no_core_no_warden() -> void:
	_check("rail_crosses_pad")
	_check("rail_crosses_warden")
	_check("rail_crosses_core")


func test_standoff_rings() -> void:
	_check("standoff_inside_slots")


func test_minis_need_a_swarm_cap_and_heat_weapons_a_vent() -> void:
	_check("mini_without_swarm_cap")
	_check("heat_weapon_without_vent")


func test_every_name_has_a_string() -> void:
	_check("missing_string")


func test_loader_stage_fixtures() -> void:
	_check("variety_unknown_key")
	_check("variety_schema_version")
	_check("arena_schema_one_with_variety")
	_check("op_bad_shape")


func test_every_fixture_file_has_a_passing_case() -> void:
	var ids: PackedStringArray = VarietyBadData.all_ids()
	assert_int(ids.size()).is_greater_equal(MIN_FIXTURES)
	for fixture_id: String in ids:
		_check(fixture_id)
