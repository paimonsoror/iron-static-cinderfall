extends GdUnitTestSuite
## Strings.t / Strings.tf (ARCH 5.4) over the frozen baseline strings. The Content autoload's db is swapped for the
## baseline during each test and restored afterwards.

var _saved: ContentSet


func before_test() -> void:
	_saved = Content.db
	Content.db = TestContent.baseline()
	Content.db.strings["test.wave"] = "Wave %d of %d"
	Content.db.strings["test.percent"] = "%d%% armor"
	Content.db.strings["test.plain"] = "No placeholders"


func after_test() -> void:
	Content.db = _saved


func test_known_key_returns_its_text() -> void:
	assert_str(Strings.t("enemy.skitter.name")).is_equal("Skitter")
	assert_str(Strings.t("reason.insufficient_scrap")).is_equal("Not enough Scrap")


func test_missing_key_returns_the_key_in_hashes() -> void:
	assert_str(Strings.t("no.such.key")).is_equal("#no.such.key#")
	assert_str(Strings.t("no.such.key")).is_equal("#no.such.key#")  # the second call logs nothing and returns the same


func test_without_content_every_key_is_a_marker() -> void:
	Content.db = null
	assert_str(Strings.t("enemy.skitter.name")).is_equal("#enemy.skitter.name#")


func test_tf_formats_arguments() -> void:
	assert_str(Strings.tf("test.wave", [2, 5])).is_equal("Wave 2 of 5")
	assert_str(Strings.tf("test.percent", [30])).is_equal("30% armor")


func test_tf_without_arguments_returns_the_text() -> void:
	assert_str(Strings.tf("test.plain", [])).is_equal("No placeholders")
	assert_str(Strings.tf("test.percent", [])).is_equal("%d%% armor")


func test_tf_with_wrong_argument_count_returns_the_marker() -> void:
	assert_str(Strings.tf("test.wave", [2])).is_equal("#test.wave#")
	assert_str(Strings.tf("test.plain", [1])).is_equal("#test.plain#")


func test_tf_with_a_missing_key_returns_the_marker() -> void:
	assert_str(Strings.tf("no.such.key", [1])).is_equal("#no.such.key#")
