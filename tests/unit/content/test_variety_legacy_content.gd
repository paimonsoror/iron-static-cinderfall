extends GdUnitTestSuite


func test_golden() -> void:
	assert_str(VarietyDefDump.legacy_hash(TestContent.baseline())).is_equal("x")
	assert_str(VarietyDefDump.legacy_hash(ContentLoader.load_from_dir("res://data").content)).is_equal("y")
