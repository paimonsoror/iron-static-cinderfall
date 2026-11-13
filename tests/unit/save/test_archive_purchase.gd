extends GdUnitTestSuite
## B10: Archive purchases are atomic (tier gate, not owned, funds, then debit + add + flush), tier gates open at 3 and 8
## unlocks, and a kit can only be picked when it is free or owned. Runs on the complete tree (ArchiveTestTree).

var fs: MemorySaveFs
var cs: ContentSet
var _changed: int = 0
var _bought: Array[StringName] = []


func before_test() -> void:
	cs = ArchiveTestTree.content()
	fs = MemorySaveFs.new()
	SaveTestData.boot_with(fs, cs)
	_changed = 0
	_bought = []
	Events.profile_changed.connect(_on_changed)
	Events.unlock_purchased.connect(_on_bought)


func after_test() -> void:
	if Events.profile_changed.is_connected(_on_changed):
		Events.profile_changed.disconnect(_on_changed)
	if Events.unlock_purchased.is_connected(_on_bought):
		Events.unlock_purchased.disconnect(_on_bought)
	SaveTestData.reset()


func _on_changed() -> void:
	_changed += 1


func _on_bought(id: StringName) -> void:
	_bought.append(id)


## The profile after a fresh load from disk: what a restart would see.
func _reloaded() -> Profile:
	return ProfileCodec.decode(fs.read(SaveTestData.MAIN)).profile


func test_a_purchase_debits_adds_saves_and_announces() -> void:
	Save.profile.data = 200
	assert_int(Save.purchase_unlock(&"u_w_lmg")).is_equal(Reason.Id.OK)
	assert_int(Save.profile.data).is_equal(80)
	assert_bool(Save.has_unlock(&"u_w_lmg")).is_true()
	var disk: Profile = _reloaded()
	assert_int(disk.data).is_equal(80)
	assert_array(Array(disk.unlocks)).is_equal(["u_w_lmg"])
	assert_int(_changed).is_equal(1)
	assert_array(_bought).is_equal([&"u_w_lmg"])


func test_buying_with_exactly_the_price_leaves_zero() -> void:
	Save.profile.data = 120
	assert_int(Save.purchase_unlock(&"u_w_lmg")).is_equal(Reason.Id.OK)
	assert_int(Save.profile.data).is_equal(0)


func test_too_little_data_changes_nothing() -> void:
	Save.profile.data = 119
	var files_before: int = fs.files.size()
	assert_int(Save.purchase_unlock(&"u_w_lmg")).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_int(Save.profile.data).is_equal(119)
	assert_int(Save.profile.unlocks.size()).is_equal(0)
	assert_int(fs.files.size()).is_equal(files_before)  # nothing was written
	assert_int(_changed).is_equal(0)
	assert_int(_bought.size()).is_equal(0)


func test_an_unknown_id_changes_nothing() -> void:
	Save.profile.data = 9999
	assert_int(Save.purchase_unlock(&"u_nothing")).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(Save.purchase_unlock(&"")).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(Save.purchase_unlock(&"k_standard")).is_equal(Reason.Id.UNKNOWN_ID)  # the free kit is not for sale
	assert_int(Save.profile.data).is_equal(9999)
	assert_int(Save.profile.unlocks.size()).is_equal(0)


func test_buying_twice_charges_once() -> void:
	Save.profile.data = 1000
	assert_int(Save.purchase_unlock(&"u_w_hornet")).is_equal(Reason.Id.OK)
	assert_int(Save.purchase_unlock(&"u_w_hornet")).is_equal(Reason.Id.DUPLICATE_COMMAND)
	assert_int(Save.profile.data).is_equal(920)
	assert_int(Save.profile.unlocks.size()).is_equal(1)
	assert_int(_bought.size()).is_equal(1)


func test_tier_two_stays_shut_until_three_unlocks_are_owned() -> void:
	Save.profile.data = 5000
	assert_int(Save.purchase_unlock(&"u_w_mortar")).is_equal(Reason.Id.PREREQ_NOT_MET)  # tier 2 with Data to spare
	assert_int(ArchiveRules.unlocks_needed(cs, 2)).is_equal(3)
	Save.purchase_unlock(&"u_w_hornet")
	Save.purchase_unlock(&"u_w_lmg")
	assert_int(Save.purchase_unlock(&"u_w_mortar")).is_equal(Reason.Id.PREREQ_NOT_MET)  # two are not three
	assert_bool(ArchiveRules.tier_open(Save.profile, cs, 2)).is_false()
	assert_int(Save.purchase_unlock(&"u_p_blast")).is_equal(Reason.Id.OK)  # a tier 1 unlock of another branch counts
	assert_bool(ArchiveRules.tier_open(Save.profile, cs, 2)).is_true()
	assert_int(Save.purchase_unlock(&"u_w_mortar")).is_equal(Reason.Id.OK)


func test_tier_three_opens_at_eight_unlocks_of_any_kind() -> void:
	Save.profile.data = 5000
	var first_seven: Array[StringName] = [&"u_w_hornet", &"u_w_lmg", &"u_p_blast", &"u_w_mortar", &"u_w_torch", &"u_p_gunline", &"u_p_arc"]
	assert_int(ArchiveTestTree.buy_all(first_seven, 5000)).is_equal(Reason.Id.OK)
	assert_int(ArchiveRules.owned_count(Save.profile, cs)).is_equal(7)
	assert_int(Save.purchase_unlock(&"u_w_rail")).is_equal(Reason.Id.PREREQ_NOT_MET)
	assert_int(Save.purchase_unlock(&"u_f_reroll")).is_equal(Reason.Id.OK)  # the eighth
	assert_int(ArchiveRules.unlocks_needed(cs, 3)).is_equal(8)
	assert_int(Save.purchase_unlock(&"u_w_rail")).is_equal(Reason.Id.OK)
	assert_int(Save.purchase_unlock(&"u_w_arc")).is_equal(Reason.Id.OK)


func test_a_tier_the_content_does_not_have_is_closed() -> void:
	assert_bool(ArchiveRules.tier_open(Save.profile, cs, 4)).is_false()
	assert_int(ArchiveRules.unlocks_needed(cs, 4)).is_equal(-1)
	assert_int(ArchiveRules.unlocks_needed(cs, 0)).is_equal(-1)
	assert_int(ArchiveRules.unlocks_needed(cs, 1)).is_equal(0)


func test_unknown_ids_in_the_profile_do_not_count_toward_a_tier() -> void:
	Save.profile.unlocks = PackedStringArray(["u_x_from_a_newer_build", "u_y_from_a_newer_build", "u_z_from_a_newer_build"])
	Save.profile.data = 5000
	assert_int(ArchiveRules.owned_count(Save.profile, cs)).is_equal(0)
	assert_int(Save.purchase_unlock(&"u_w_mortar")).is_equal(Reason.Id.PREREQ_NOT_MET)


func test_the_order_of_the_checks_is_unknown_owned_tier_funds() -> void:
	Save.profile.data = 0
	assert_int(ArchiveRules.block_reason(Save.profile, cs, &"u_w_rail")).is_equal(Reason.Id.PREREQ_NOT_MET)  # tier before funds
	Save.profile.unlocks.append("u_w_rail")
	assert_int(ArchiveRules.block_reason(Save.profile, cs, &"u_w_rail")).is_equal(Reason.Id.DUPLICATE_COMMAND)  # owned before tier
	assert_int(ArchiveRules.block_reason(Save.profile, cs, &"u_w_nope")).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(ArchiveRules.block_reason(Save.profile, cs, &"u_w_hornet")).is_equal(Reason.Id.INSUFFICIENT_SCRAP)


func test_a_failed_write_never_leaves_half_a_purchase_on_disk() -> void:
	Save.profile.data = 300
	Save.flush()
	fs.fail_writes = true
	assert_int(Save.purchase_unlock(&"u_w_lmg")).is_equal(Reason.Id.OK)
	assert_bool(Save.profile_dirty()).is_true()
	assert_int(Save.profile.data).is_equal(180)  # in memory both halves happened together
	assert_bool(Save.has_unlock(&"u_w_lmg")).is_true()
	fs.fail_writes = false
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)  # the process died before a write succeeded
	assert_int(Save.profile.data).is_equal(300)  # neither half reached the disk
	assert_bool(Save.has_unlock(&"u_w_lmg")).is_false()


func test_a_failed_write_is_kept_in_memory_and_the_next_flush_writes_both_halves() -> void:
	Save.profile.data = 300
	fs.fail_writes = true
	Save.purchase_unlock(&"u_w_lmg")
	fs.fail_writes = false
	assert_bool(Save.flush()).is_true()
	var disk: Profile = _reloaded()
	assert_int(disk.data).is_equal(180)
	assert_array(Array(disk.unlocks)).is_equal(["u_w_lmg"])
	assert_int(Save.purchase_unlock(&"u_w_lmg")).is_equal(Reason.Id.DUPLICATE_COMMAND)  # not charged again


func test_a_purchase_survives_a_restart() -> void:
	Save.profile.data = 500
	Save.purchase_unlock(&"u_f_reroll")
	Save.purchase_unlock(&"u_p_arc")
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)
	assert_int(Save.profile.data).is_equal(280)
	assert_array(Array(Save.profile.unlocks)).is_equal(["u_f_reroll", "u_p_arc"])


func test_data_lifetime_is_not_spent() -> void:
	Save.grant_run_reward("run-a", RunResult.Id.DEFEAT, 400, 0)
	Save.purchase_unlock(&"u_w_lmg")
	assert_int(Save.profile.data).is_equal(280)
	assert_int(Save.profile.data_lifetime).is_equal(400)


func test_the_whole_archive_costs_5250_and_leaves_nothing() -> void:
	var all: Array[StringName] = []
	for tier: int in [1, 2, 3]:
		for branch: int in 4:
			all.append_array(ArchiveTestTree.ids_at(cs, branch, tier))
	assert_int(all.size()).is_equal(24)
	assert_int(ArchiveTestTree.buy_all(all, ArchiveTestTree.TOTAL_COST)).is_equal(Reason.Id.OK)
	assert_int(Save.profile.data).is_equal(0)
	assert_int(Save.profile.unlocks.size()).is_equal(24)
	assert_int(_bought.size()).is_equal(24)


func test_no_content_means_no_purchase() -> void:
	SaveTestData.boot_with(MemorySaveFs.new(), ContentSet.new())
	Save.profile.data = 999
	assert_int(Save.purchase_unlock(&"u_w_lmg")).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(Save.profile.data).is_equal(999)


# --- kits ---


func test_a_kit_the_content_does_not_know_is_refused() -> void:
	Save.set_kit(&"k_nothing")
	assert_str(String(Save.profile.kit)).is_equal("k_standard")
	Save.profile.data = 150
	assert_int(Save.purchase_unlock(&"k_breacher")).is_equal(Reason.Id.OK)
	Save.set_kit(&"k_breacher")
	assert_str(String(Save.profile.kit)).is_equal("k_breacher")
	assert_str(String(_reloaded().kit)).is_equal("k_breacher")  # saved at once
	Save.set_kit(&"k_standard")  # the free kit is always there
	assert_str(String(Save.profile.kit)).is_equal("k_standard")


func test_the_archive_rule_says_a_locked_kit_is_not_ready() -> void:
	assert_bool(ArchiveRules.kit_ready(Save.profile, cs, &"k_standard")).is_true()
	assert_bool(ArchiveRules.kit_ready(Save.profile, cs, &"k_breacher")).is_false()
	assert_bool(ArchiveRules.kit_ready(Save.profile, cs, &"k_nothing")).is_false()
	Save.profile.unlocks.append("k_breacher")
	assert_bool(ArchiveRules.kit_ready(Save.profile, cs, &"k_breacher")).is_true()


func test_a_kit_the_profile_cannot_start_is_the_standard_kit_after_loading() -> void:
	Save.profile.kit = &"k_gambler"  # a file edited by hand, or a profile from another state
	Save.flush()
	assert_int(Save.load_profile()).is_equal(Save.LoadStatus.OK)
	assert_str(String(Save.profile.kit)).is_equal("k_standard")
	Save.profile.unlocks.append("k_gambler")
	Save.profile.kit = &"k_gambler"
	Save.flush()
	Save.load_profile()
	assert_str(String(Save.profile.kit)).is_equal("k_gambler")  # owned: kept


func test_the_kit_unlock_and_the_kit_cost_agree() -> void:
	for u: UnlockDef in cs.unlocks:
		if u.branch == UnlockDef.Branch.KITS:
			assert_int(cs.kit(u.grants[0]).cost).is_equal(u.cost)
			assert_str(String(u.grants[0])).is_equal(String(u.id))


# --- the Daily Run gate ---


func test_the_daily_run_opens_with_the_first_act_one_boss_kill() -> void:
	assert_bool(ArchiveRules.daily_open(Save.profile, cs)).is_false()
	Save.profile.boss_kills["siege_hulk"] = 1
	assert_bool(ArchiveRules.daily_open(Save.profile, cs)).is_true()
	Save.profile.boss_kills = {"brood_carrier": 3}  # not a boss of this content
	assert_bool(ArchiveRules.daily_open(Save.profile, cs)).is_false()
