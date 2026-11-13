extends GdUnitTestSuite
## B10: the Daily Run seed (VARIETY_SPEC 8.5). One seed per UTC date, hashed in the game layer; the sim only ever sees
## the number. The same date gives the same seed (and so the same plan), another date another seed.

const NOV_12: String = "2026-11-12"
const NOV_13: String = "2026-11-13"


func test_the_same_date_gives_the_same_seed() -> void:
	assert_int(GameLaunch.daily_seed(NOV_12)).is_equal(GameLaunch.daily_seed(NOV_12))
	assert_int(GameLaunch.daily_seed(String(NOV_12))).is_equal(GameLaunch.daily_seed("2026-11-12"))


func test_the_seed_is_a_golden_value_of_sha256_over_daily_and_the_date() -> void:
	# sha256("daily|2026-11-12") starts 0162276b; the seed keeps 31 bits. Same on every machine and build.
	assert_int(GameLaunch.daily_seed(NOV_12)).is_equal(23209835)
	assert_int(GameLaunch.daily_seed(NOV_13)).is_equal(141161535)  # 0x8869f43f without its top bit


func test_other_dates_give_other_seeds() -> void:
	assert_int(GameLaunch.daily_seed(NOV_12)).is_not_equal(GameLaunch.daily_seed(NOV_13))
	var seen: Dictionary[int, String] = {}
	var day: int = 1767225600  # 2026-01-01 00:00 UTC
	for i: int in 400:
		var date: String = GameLaunch.utc_date(day + i * 86400)
		var seed_value: int = GameLaunch.daily_seed(date)
		assert_int(seed_value).is_between(0, 0x7FFFFFFF)
		assert_bool(seen.has(seed_value)).is_false()  # no two days of 400 share a seed
		seen[seed_value] = date


func test_a_malformed_date_has_no_seed() -> void:
	for bad: String in ["", "today", "2026-11", "2026/11/12", "2026-11-12T00:00"]:
		assert_int(GameLaunch.daily_seed(bad)).is_equal(-1)


func test_the_utc_date_of_a_unix_time() -> void:
	assert_str(GameLaunch.utc_date(0)).is_equal("1970-01-01")
	assert_str(GameLaunch.utc_date(1763000000)).is_equal("2025-11-13")
	assert_str(GameLaunch.utc_date(1767225599)).is_equal("2025-12-31")  # one second before the day changes
	assert_str(GameLaunch.utc_date(1767225600)).is_equal("2026-01-01")
	assert_bool(Profile.is_date(GameLaunch.utc_date())).is_true()  # the clock form


func test_the_start_date_of_a_run_comes_from_its_id() -> void:
	assert_str(GameLaunch.run_date("1763000000-5")).is_equal("2025-11-13")
	assert_str(GameLaunch.run_date("1763000000-5-2")).is_equal("2025-11-13")  # the counter of a repeated id
	assert_str(GameLaunch.run_date("run-1")).is_equal("")
	assert_str(GameLaunch.run_date("")).is_equal("")
	var used: Dictionary[String, bool] = {}
	var id: String = GameLaunch.make_run_id(GameLaunch.daily_seed(NOV_12), used, PackedStringArray())
	assert_bool(Profile.is_date(GameLaunch.run_date(id))).is_true()


func test_the_daily_kit_is_the_standard_kit() -> void:
	assert_str(String(GameLaunch.DAILY_KIT)).is_equal("k_standard")
	assert_int(TestContent.variety().kit_index(GameLaunch.DAILY_KIT)).is_equal(0)


func _plan_world(date: String) -> SimWorld:
	var cfg: SimConfig = SimConfig.create(TestContent.variety(), GameLaunch.daily_seed(date))
	cfg.daily = true
	cfg.kit_index = 0
	return SimWorld.new(cfg)


func test_the_same_date_builds_the_same_run_plan() -> void:
	var a: SimWorld = _plan_world(NOV_12)
	var b: SimWorld = _plan_world(NOV_12)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_array(a.plan.to_dict().get("waves", [])).is_equal(b.plan.to_dict().get("waves", []))


func test_another_date_builds_another_run_plan() -> void:
	var a: SimWorld = _plan_world(NOV_12)
	var b: SimWorld = _plan_world(NOV_13)
	assert_str(a.state_hash()).is_not_equal(b.state_hash())
	assert_array(a.plan.to_dict().get("waves", [])).is_not_equal(b.plan.to_dict().get("waves", []))


func test_a_daily_run_ignores_the_profiles_unlocks() -> void:
	var cfg: SimConfig = SimConfig.create(TestContent.variety(), GameLaunch.daily_seed(NOV_12))
	assert_bool(cfg.has_unlock("u_w_arc")).is_false()
	cfg.daily = true
	assert_bool(cfg.has_unlock("u_w_arc")).is_true()  # the full pool whatever the profile owns
