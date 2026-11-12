extends GdUnitTestSuite
## ContentValidator on typed ContentSets built in code (no JSON): finite numbers, ids, regions, palette, strings,
## the reachability rule, and the shipped data.

var c: ContentSet


func before_test() -> void:
	c = TestContent.baseline()


func _joined(errors: PackedStringArray) -> String:
	return "\n".join(errors)


func test_baseline_has_no_errors() -> void:
	assert_str(_joined(ContentValidator.validate(c))).is_empty()


func test_shipped_data_loads_and_validates() -> void:
	# Integrity only (no values asserted): whatever Wave 2 tunes in res://data/ must still pass every rule.
	var r: ContentLoadResult = ContentLoader.load_from_dir("res://data")
	assert_str(_joined(r.errors)).is_empty()
	assert_str(_joined(ContentValidator.validate(r.content))).is_empty()


func test_null_content_is_an_error() -> void:
	assert_int(ContentValidator.validate(null).size()).is_equal(1)
	assert_int(ContentValidator.validate(ContentSet.new()).size()).is_equal(1)


func test_nan_and_infinity_are_not_finite() -> void:
	c.enemies[0].hp = NAN
	c.weapons[1].range_m = INF
	var text: String = _joined(ContentValidator.validate(c))
	assert_str(text).contains("vertical_slice_balance.json: $.enemies.skitter.hp: not a finite number (got nan)")
	assert_str(text).contains("vertical_slice_balance.json: $.weapons.smg.range_m: not a finite number (got inf)")


func test_each_problem_is_one_error() -> void:
	c.enemies[2].hp = -1.0
	c.abilities[0].cooldown_ticks = 0
	c.mission.core_max_hp = 0.0
	assert_int(ContentValidator.validate(c).size()).is_equal(3)


func test_enemy_index_outside_the_roster() -> void:
	c.waves[0].groups[0].enemy_index = 9
	assert_str(_joined(ContentValidator.validate(c))).is_equal("waves.json: $.waves[0].groups[0].enemy: unknown enemy id (index 9)")


func test_region_that_does_not_exist() -> void:
	c.waves[3].groups[0].region_id = &"orbit"
	assert_str(_joined(ContentValidator.validate(c))).is_equal("waves.json: $.waves[3].groups[0].region: unknown spawn region 'orbit'")


func test_weapon_unlock_must_name_a_weapon() -> void:
	c.upgrade(&"smg_unlock").weapon_index = 5
	assert_str(_joined(ContentValidator.validate(c))).is_equal("content_ext.json: $.upgrades.smg_unlock.weapon: unknown weapon (index 5)")


func test_palette_needs_all_six_tokens() -> void:
	c.tokens.palette.erase(&"bone_ceramic")
	assert_str(_joined(ContentValidator.validate(c))).is_equal("visual_tokens.json: $.palette.bone_ceramic: palette token missing")


func test_every_name_needs_a_string() -> void:
	c.strings.erase("enemy.skitter.name")
	c.strings.erase("reason.paused")
	var text: String = _joined(ContentValidator.validate(c))
	assert_str(text).contains("strings/content_en.json: $.enemy.skitter.name: missing string (needed by $.enemies.skitter)")
	assert_str(text).contains("strings/content_en.json: $.reason.paused: missing string (needed by Reason)")


func test_slot_ring_must_match_slot_positions() -> void:
	c.arena.slot_ring.resize(10)
	assert_str(_joined(ContentValidator.validate(c))).contains("$.slots: 64 attack slots (10 ring entries)")


func test_flow_field_is_found_by_path() -> void:
	var field: Object = ContentValidator.build_flow_field(c.arena)
	assert_object(field).is_not_null()
	assert_bool(field is FlowField).is_true()  # the validator and FlowField.build agree on the class


func test_content_autoload_reloads_the_shipped_data() -> void:
	assert_bool(Content.reload()).is_true()
	assert_int(Content.load_errors.size()).is_equal(0)
	assert_int(Content.db.enemies.size()).is_equal(Ids.ENEMIES.size())  # the shipped data is variety content
	assert_int(Content.db.waves.size()).is_equal(5)


func test_reachability_is_skipped_without_cells() -> void:
	var stub: ValidatorFakeField = ValidatorFakeField.with_cells(0, 7)  # the W0 stub has no cells and reports 0
	assert_int(ContentValidator.reachability_errors(c.arena, stub).size()).is_equal(0)
	assert_int(stub.asked).is_equal(0)
	assert_int(ContentValidator.reachability_errors(c.arena, null).size()).is_equal(0)


func test_reachability_reports_unreachable_spawn_cells() -> void:
	var field: ValidatorFakeField = ValidatorFakeField.with_cells(100, 12)
	var errors: PackedStringArray = ContentValidator.reachability_errors(c.arena, field)
	assert_str(_joined(errors)).is_equal("arena.json: $.spawn_regions: 12 spawn-region cells cannot reach the core in the flow field")


func test_reachability_passes_when_all_cells_reach() -> void:
	var field: ValidatorFakeField = ValidatorFakeField.with_cells(100, 0)
	assert_int(ContentValidator.reachability_errors(c.arena, field).size()).is_equal(0)
	assert_int(field.asked).is_equal(1)


func test_flow_field_walls_off_a_spawn_region() -> void:
	# A wall across the whole yard leaves the 'right' spawn region without a path to the core.
	var wall: ObstacleDef = ObstacleDef.new()
	wall.id = &"wall"
	wall.shape = ObstacleDef.Shape.BOX
	wall.x = 0.0
	wall.z = -2.0
	wall.size_x = 1.0
	wall.size_z = 60.0
	c.arena.obstacles.append(wall)
	assert_int(FlowField.build(c.arena).cost.size()).is_greater(0)
	assert_str(_joined(ContentValidator.validate(c))).contains("spawn-region cells cannot reach the core in the flow field")


func test_baseline_flow_field_reaches_the_core() -> void:
	var field: FlowField = FlowField.build(c.arena)
	assert_int(field.cost.size()).is_greater(0)
	assert_int(field.unreachable_spawn_cells(c.arena)).is_equal(0)
