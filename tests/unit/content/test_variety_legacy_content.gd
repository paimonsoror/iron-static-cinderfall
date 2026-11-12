extends GdUnitTestSuite
## V1-S: content built WITHOUT the variety files is exactly the content the game had before the variety milestone
## (VARIETY_SPEC 13.9). The golden hash was recorded on main 9705a77 with VarietyDefDump, before any loader change.

const GOLDEN_BASELINE: String = "1a86a35d2dc4fff0ce3e41d3bd288efe745c499ee6ad3d5b6a0d0832a989e9bb"

var c: ContentSet


func before_test() -> void:
	c = TestContent.baseline()


func _json(file: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TestContent.BASELINE_DIR + "/" + file))
	return d


func test_the_legacy_fixture_gives_the_same_defs_as_before_the_scaffold() -> void:
	assert_str(VarietyDefDump.legacy_hash(c)).is_equal(GOLDEN_BASELINE)


func test_the_legacy_fixture_files_are_untouched() -> void:
	# sha256 of the fixture files as they were on main 9705a77 (the fixture stays byte-identical).
	var want: Dictionary[String, String] = VarietyDefDump.BASELINE_FILE_HASHES
	assert_int(want.size()).is_equal(9)
	for file: String in want:
		var got: String = FileAccess.get_sha256(TestContent.BASELINE_DIR + "/" + file)
		assert_str(got).override_failure_message("%s changed" % file).is_equal(want[file])


func test_the_seventh_parameter_defaults_to_the_legacy_content() -> void:
	var six: ContentLoadResult = ContentLoader.build(
		_json("vertical_slice_balance.json"), _json("waves.json"), _json("visual_tokens.json"), _json("content_ext.json"),
		_json("arena.json"), BadDataFixture.baseline_strings()
	)
	var seven: ContentLoadResult = ContentLoader.build(
		_json("vertical_slice_balance.json"), _json("waves.json"), _json("visual_tokens.json"), _json("content_ext.json"),
		_json("arena.json"), BadDataFixture.baseline_strings(), {}
	)
	assert_str("\n".join(six.errors)).is_empty()
	assert_str(VarietyDefDump.legacy_hash(six.content)).is_equal(GOLDEN_BASELINE)
	assert_str(VarietyDefDump.legacy_hash(seven.content)).is_equal(GOLDEN_BASELINE)


func test_legacy_content_has_no_variety_parts() -> void:
	assert_bool(c.is_variety()).is_false()
	assert_object(c.run).is_null()
	assert_int(c.enemies.size()).is_equal(Ids.LEGACY_ENEMY_COUNT)
	assert_int(c.weapons.size()).is_equal(Ids.LEGACY_WEAPON_COUNT)
	assert_int(c.directives.size() + c.events.size() + c.unlocks.size() + c.affixes.size()).is_equal(0)
	assert_int(c.bosses.size() + c.kits.size() + c.turret_types.size()).is_equal(0)
	assert_int(c.directive_index(&"hot_loads")).is_equal(-1)
	assert_int(c.kit_index(&"k_standard")).is_equal(-1)


func test_new_def_fields_keep_their_legacy_defaults() -> void:
	assert_int(c.mission.swarm_cap).is_equal(0)
	assert_int(c.mission.breather_ticks).is_equal(0)
	assert_bool(c.mission.shop_enabled).is_true()
	for e: EnemyDef in c.enemies:
		assert_int(e.enemy_class).is_equal(EnemyDef.BodyClass.BODIED)
		assert_int(e.alive_cap).is_equal(0)
		assert_float(e.cost).is_equal(0.0)
		assert_bool(e.is_mini()).is_false()
		assert_int(e.behaviour.size()).is_equal(0)
	for w: WeaponDef in c.weapons:
		assert_int(w.kind).is_equal(WeaponDef.Kind.HITSCAN)
		assert_int(w.tier).is_equal(1)
		assert_bool(w.is_heat()).is_false()
	assert_int(c.arena.standoff_points.size() + c.arena.drop_points.size() + c.arena.breach_points.size()).is_equal(0)
	assert_int(c.arena.drum_points.size() + c.arena.rail_z.size()).is_equal(0)


func test_legacy_content_still_validates() -> void:
	assert_str("\n".join(ContentValidator.validate(c))).is_empty()


func test_a_legacy_world_has_no_plan_and_the_old_store_size() -> void:
	var w: SimWorld = TestContent.world(1)
	assert_object(w.plan).is_null()
	assert_int(w.enemies.capacity).is_equal(c.mission.enemy_cap + 8)
	assert_int(w.stats.kills_by_type.size()).is_equal(4)
	assert_int(w.phase_state.awaiting).is_equal(PhaseState.Await.NONE)
