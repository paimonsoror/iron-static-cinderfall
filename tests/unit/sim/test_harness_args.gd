extends GdUnitTestSuite
## HarnessArgs: the options shared by tools/sim_run.gd and tools/balance_run.gd.


func test_defaults() -> void:
	var a: HarnessArgs = HarnessArgs.parse(PackedStringArray())
	assert_str(a.error).is_empty()
	assert_int(a.runs).is_equal(20)
	assert_int(a.first_seed).is_equal(1)
	assert_str(a.policy).is_equal("greedy")
	assert_int(a.max_ticks).is_equal(SimHarness.DEFAULT_MAX_TICKS)
	assert_float(a.damage_mult).is_equal(1.0)
	assert_int(a.start_scrap).is_equal(0)
	assert_str(a.data_dir).is_equal("res://data")


func test_the_default_policy_comes_from_the_caller() -> void:
	assert_str(HarnessArgs.parse(PackedStringArray(), "both").policy).is_equal("both")


func test_every_flag() -> void:
	var raw: PackedStringArray = [
		"--runs", "5", "--seed", "42", "--policy", "none", "--max-ticks", "9000", "--damage-mult", "2.5", "--start-scrap", "300", "--data", "res://x"
	]
	var a: HarnessArgs = HarnessArgs.parse(raw)
	assert_str(a.error).is_empty()
	assert_int(a.runs).is_equal(5)
	assert_int(a.first_seed).is_equal(42)
	assert_str(a.policy).is_equal("none")
	assert_int(a.max_ticks).is_equal(9000)
	assert_float(a.damage_mult).is_equal(2.5)
	assert_int(a.start_scrap).is_equal(300)
	assert_str(a.data_dir).is_equal("res://x")


func test_bad_input_sets_an_error() -> void:
	for raw: PackedStringArray in [
		PackedStringArray(["--runs", "0"]),
		PackedStringArray(["--runs", "many"]),
		PackedStringArray(["--policy", "random"]),
		PackedStringArray(["--damage-mult", "0"]),
		PackedStringArray(["--max-ticks", "-4"]),
		PackedStringArray(["--start-scrap", "-1"]),
		PackedStringArray(["--frobnicate", "1"]),
		PackedStringArray(["--runs"]),
	]:
		assert_str(HarnessArgs.parse(raw).error).is_not_empty()


func test_policies_in_report_order() -> void:
	var both: HarnessArgs = HarnessArgs.parse(PackedStringArray(["--policy", "both"]))
	assert_array(both.policies()).is_equal([PolicyBot.Policy.NONE, PolicyBot.Policy.GREEDY])
	var one: HarnessArgs = HarnessArgs.parse(PackedStringArray(["--policy", "greedy"]))
	assert_array(one.policies()).is_equal([PolicyBot.Policy.GREEDY])
	assert_str(HarnessArgs.policy_name(PolicyBot.Policy.NONE)).is_equal("none")
	assert_str(HarnessArgs.policy_name(PolicyBot.Policy.GREEDY)).is_equal("greedy")
