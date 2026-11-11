extends GdUnitTestSuite
## Loader-stage bad fixtures (tests/fixtures/data_bad): structural problems are reported with the file and JSON path,
## exactly once each, and the loader returns no content.


func _check(fixture_id: String) -> void:
	var f: BadDataFixture = BadDataFixture.run(fixture_id)
	assert_int(f.expect.size()).is_greater(0)
	assert_str("\n".join(f.errors)).is_equal("\n".join(f.expect))
	assert_str(f.stage).is_equal("loader")
	assert_str(f.expected_stage).is_equal("loader")


func test_unknown_enemy_id() -> void:
	_check("unknown_enemy_id")


func test_nan_value() -> void:
	_check("nan_value")


func test_unknown_region() -> void:
	_check("unknown_region")


func test_wrong_schema_version() -> void:
	_check("wrong_schema_version")


func test_wrong_schema_version_in_arena() -> void:
	_check("wrong_arena_schema_version")


func test_missing_schema_version_is_reported_once() -> void:
	_check("missing_schema_version")


func test_tick_rate_mismatch() -> void:
	_check("tick_rate_mismatch")


func test_missing_palette_token() -> void:
	_check("missing_palette_token")


func test_palette_token_must_be_a_color() -> void:
	_check("bad_palette_color")


func test_unknown_top_level_key() -> void:
	_check("unknown_top_level_key")


func test_missing_required_key() -> void:
	_check("missing_required_key")


func test_wrong_value_type() -> void:
	_check("wrong_type")


func test_unknown_weapon_in_unlock() -> void:
	_check("unknown_weapon_unlock")


func test_loader_returns_no_content_on_error() -> void:
	var docs: Dictionary = {}
	for file: String in ContentLoader.FILES:
		docs[file] = BadDataFixture.read_json("%s/%s" % [TestContent.BASELINE_DIR, file])
	var waves: Dictionary = docs["waves.json"]
	waves["extra"] = true
	var balance: Dictionary = docs["vertical_slice_balance.json"]
	var tokens: Dictionary = docs["visual_tokens.json"]
	var ext: Dictionary = docs["content_ext.json"]
	var arena: Dictionary = docs["arena.json"]
	var r: ContentLoadResult = ContentLoader.build(balance, waves, tokens, ext, arena, BadDataFixture.baseline_strings())
	assert_object(r.content).is_null()
	assert_int(r.errors.size()).is_equal(1)


func test_several_problems_are_all_reported() -> void:
	var docs: Dictionary = {}
	for file: String in ContentLoader.FILES:
		docs[file] = BadDataFixture.read_json("%s/%s" % [TestContent.BASELINE_DIR, file])
	var waves: Dictionary = docs["waves.json"]
	waves["extra"] = true
	var balance: Dictionary = docs["vertical_slice_balance.json"]
	balance["schema_version"] = 9
	var arena: Dictionary = docs["arena.json"]
	arena.erase("approach_radius")
	var tokens: Dictionary = docs["visual_tokens.json"]
	var ext: Dictionary = docs["content_ext.json"]
	var r: ContentLoadResult = ContentLoader.build(balance, waves, tokens, ext, arena, BadDataFixture.baseline_strings())
	var text: String = "\n".join(r.errors)
	assert_str(text).contains("vertical_slice_balance.json: $.schema_version: expected 2, got 9")
	assert_str(text).contains("waves.json: $.extra: unknown key")
	assert_str(text).contains("arena.json: $.approach_radius: missing or not a number")


func test_malformed_json_file_is_reported_with_its_name() -> void:
	var r: ContentLoadResult = ContentLoader.load_from_dir(BadDataFixture.FIXTURE_DIR + "/dir_malformed")
	assert_object(r.content).is_null()
	assert_str("\n".join(r.errors)).contains("waves.json: not valid JSON (line ")


func test_missing_files_are_each_reported() -> void:
	var r: ContentLoadResult = ContentLoader.load_from_dir(BadDataFixture.FIXTURE_DIR + "/dir_malformed")
	assert_str("\n".join(r.errors)).contains("arena.json: file missing")
	assert_str("\n".join(r.errors)).contains("strings/content_en.json: file missing")


func test_non_string_text_value_is_reported() -> void:
	var docs: Dictionary = {}
	for file: String in ContentLoader.FILES:
		docs[file] = BadDataFixture.read_json("%s/%s" % [TestContent.BASELINE_DIR, file])
	var balance: Dictionary = docs["vertical_slice_balance.json"]
	balance["mission_id"] = 7
	var waves: Dictionary = docs["waves.json"]
	var tokens: Dictionary = docs["visual_tokens.json"]
	var ext: Dictionary = docs["content_ext.json"]
	var arena: Dictionary = docs["arena.json"]
	var r: ContentLoadResult = ContentLoader.build(balance, waves, tokens, ext, arena, BadDataFixture.baseline_strings())
	assert_str("\n".join(r.errors)).is_equal("vertical_slice_balance.json: $.mission_id: missing or not a string")
