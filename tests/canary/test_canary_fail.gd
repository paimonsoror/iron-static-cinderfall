extends GdUnitTestSuite
## Valid GDScript whose only test always fails. `tools/test.ps1 -Canary` runs it in a copy of the project and
## requires exit code 1, which proves the wrapper detects failures. It is not under tests/unit, so normal
## runs never execute it.


func test_canary_always_fails() -> void:
	assert_int(1 + 1).is_equal(3)
