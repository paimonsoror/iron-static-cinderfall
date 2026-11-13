extends GdUnitTestSuite
## B10: what GameRewards hands to Save.grant_run_reward: the extras of a finished run (best wave, bosses killed, kit,
## primary weapon, the Daily Run date), read from the run's summary and the live run, and the whole path from a summary
## to the profile (Data once, milestones once, the Daily Run record).

const RUN_ID: String = "1763000000-5"  # started 2025-11-13 UTC

var cs: ContentSet
var fs: MemorySaveFs
var _live: RunController = null


func before_test() -> void:
	cs = ArchiveTestTree.content()
	fs = MemorySaveFs.new()
	SaveTestData.boot_with(fs, cs)
	GameRewards.flush_pending = false


func after_test() -> void:
	Game.run = null
	_live = null
	SaveTestData.reset()


func _summary(result: int, waves: int, boss_killed: bool = false, weapons: Array[String] = ["pistol"], id: String = RUN_ID) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.run_id = id
	s.result = result
	s.waves_completed = waves
	s.core_hp = 300
	s.data_reward = 60
	s.act_reached = 2
	s.kills_by_type.resize(cs.enemies.size())
	if boss_killed:
		s.kills_by_type[cs.boss(&"siege_hulk").enemy_index] = 1
	for w: String in weapons:
		s.weapons.append(Ids.weapon_index(StringName(w)))
	return s


## Makes `run_id` the live run of the Game autoload, started the way the arguments say.
func _go_live(run_id: String, kit: StringName, daily: bool) -> void:
	var cfg: SimConfig = SimConfig.create(cs, 3)
	cfg.kit_index = cs.kit_index(kit)
	cfg.daily = daily
	_live = auto_free(RunController.new())
	_live.run_id = run_id
	_live.sim = SimWorld.new(cfg)
	Game.run = _live


func test_extras_name_the_waves_the_boss_the_kit_and_the_primary_weapon() -> void:
	var e: Dictionary = GameRewards.extras_of(_summary(RunResult.Id.VICTORY, 15, true, ["pistol", "arc_projector"]), cs, {"kit": &"k_breacher"})
	assert_int(e["best_wave"]).is_equal(15)
	assert_array(e["boss_kills"]).is_equal(["siege_hulk"])
	assert_str(e["kit"]).is_equal("k_breacher")
	assert_str(e["primary_weapon"]).is_equal("arc_projector")  # the highest tier carried
	assert_array(e["weapons"]).is_equal(["pistol", "arc_projector"])
	assert_bool(e.has("daily")).is_false()


func test_a_boss_counts_only_when_its_body_was_killed() -> void:
	var e: Dictionary = GameRewards.extras_of(_summary(RunResult.Id.DEFEAT, 5, false), cs)
	assert_array(e["boss_kills"]).is_equal([])


func test_the_primary_weapon_is_the_highest_tier_and_the_lower_slot_wins_a_tie() -> void:
	assert_str(String(GameRewards.primary_weapon(_summary(RunResult.Id.VICTORY, 15, false, ["lmg", "pistol"]), cs))).is_equal("lmg")
	assert_str(String(GameRewards.primary_weapon(_summary(RunResult.Id.VICTORY, 15, false, ["pistol", "rail_lance"]), cs))).is_equal("rail_lance")
	assert_str(String(GameRewards.primary_weapon(_summary(RunResult.Id.VICTORY, 15, false, ["hornet_rack", "assault_rifle"]), cs))).is_equal("hornet_rack")  # both tier 3
	assert_str(String(GameRewards.primary_weapon(_summary(RunResult.Id.VICTORY, 15, false, []), cs))).is_equal("")
	var s: RunSummary = _summary(RunResult.Id.VICTORY, 15, false, ["pistol"])
	s.weapons.append(-1)  # an empty slot
	s.weapons.append(99)  # not a weapon of this content
	assert_str(String(GameRewards.primary_weapon(s, cs))).is_equal("pistol")
	assert_array(Array(GameRewards.weapon_ids(s, cs))).is_equal(["pistol"])


func test_a_daily_run_carries_the_date_it_started_on() -> void:
	var e: Dictionary = GameRewards.extras_of(_summary(RunResult.Id.DEFEAT, 8), cs, {"kit": &"k_standard", "daily": true})
	assert_dict(e["daily"]).is_equal({"date": "2025-11-13"})


func test_a_run_that_is_not_live_was_a_plain_run_with_the_profiles_kit() -> void:
	Save.profile.unlocks.append("k_ledger")
	Save.set_kit(&"k_ledger")
	var launch: Dictionary = GameRewards.launch_of(_summary(RunResult.Id.DEFEAT, 3))
	assert_str(str(launch["kit"])).is_equal("k_ledger")
	assert_bool(launch["daily"]).is_false()


func test_the_live_run_says_which_kit_and_whether_it_was_daily() -> void:
	_go_live(RUN_ID, &"k_gunline", true)
	var launch: Dictionary = GameRewards.launch_of(_summary(RunResult.Id.DEFEAT, 3))
	assert_str(str(launch["kit"])).is_equal("k_gunline")
	assert_bool(launch["daily"]).is_true()
	var other: Dictionary = GameRewards.launch_of(_summary(RunResult.Id.DEFEAT, 3, false, ["pistol"], "999-1"))  # not this run
	assert_bool(other["daily"]).is_false()


func test_a_victory_pays_the_run_and_its_milestones_once() -> void:
	_go_live(RUN_ID, &"k_standard", false)
	var s: RunSummary = _summary(RunResult.Id.VICTORY, 15, true, ["pistol", "arc_projector"])
	assert_bool(GameRewards.grant(s)).is_true()
	assert_int(Save.profile.data).is_equal(60 + 50 + 200 + 75)
	assert_int(Save.profile.best_wave).is_equal(15)
	assert_int(Save.profile.boss_kills["siege_hulk"]).is_equal(1)
	assert_dict(Save.profile.victories_by_kit).is_equal({"k_standard": 1})
	assert_array(Array(Save.profile.victory_weapons)).is_equal(["arc_projector"])
	assert_bool(GameRewards.grant(s)).is_false()  # a second finish, a replayed results screen, a resume
	assert_int(Save.profile.data).is_equal(385)
	assert_int(Save.last_reward["total"]).is_equal(385)
	assert_bool(GameRewards.flush_pending).is_false()


func test_the_grant_and_its_milestones_reach_the_disk_together() -> void:
	_go_live(RUN_ID, &"k_standard", false)
	GameRewards.grant(_summary(RunResult.Id.VICTORY, 15, true))
	var disk: Profile = ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile
	assert_int(disk.data).is_equal(385)
	assert_array(Array(disk.claimed)).is_equal(["ms_first_boss_siege_hulk", "ms_first_victory", "ms_victory_kit_k_standard"])


func test_a_kit_victory_is_filed_under_the_kit_the_run_used() -> void:
	Save.profile.unlocks.append("k_ledger")
	_go_live(RUN_ID, &"k_ledger", false)
	GameRewards.grant(_summary(RunResult.Id.VICTORY, 15))
	assert_dict(Save.profile.victories_by_kit).is_equal({"k_ledger": 1})
	assert_bool(Save.profile.claimed.has("ms_victory_kit_k_ledger")).is_true()


func test_a_defeat_pays_a_boss_first_kill_but_no_victory_milestone() -> void:
	_go_live(RUN_ID, &"k_standard", false)
	GameRewards.grant(_summary(RunResult.Id.DEFEAT, 10, true))
	assert_int(Save.profile.data).is_equal(60 + 50)
	assert_int(Save.profile.missions_completed).is_equal(0)


func test_a_daily_run_is_recorded_and_the_second_attempt_pays_half() -> void:
	_go_live(RUN_ID, &"k_standard", true)
	GameRewards.grant(_summary(RunResult.Id.DEFEAT, 7))
	assert_dict(Save.profile.daily).is_equal({"date": "2025-11-13", "best_wave": 7, "won": false, "rewarded": true})
	assert_int(Save.profile.data).is_equal(60)
	_go_live("1763000100-5", &"k_standard", true)
	GameRewards.grant(_summary(RunResult.Id.DEFEAT, 9, false, ["pistol"], "1763000100-5"))
	assert_str(Save.last_reward["daily"]).is_equal("practice")
	assert_int(Save.profile.data).is_equal(60 + 30)
	assert_int(Save.profile.daily["best_wave"]).is_equal(9)


func test_an_abandoned_run_is_not_granted() -> void:
	assert_bool(GameRewards.grant(_summary(RunResult.Id.ABANDONED, 4))).is_false()
	assert_int(Save.profile.data).is_equal(0)
	assert_int(Save.profile.runs_played).is_equal(0)
