extends GdUnitTestSuite
## The values of unlocks.json (CONTENT 11 and 12): the complete tree adds up to the design numbers, its kits are valid
## ops, and the shipped data/unlocks.json (with its byte copy in the variety fixture) holds exactly rows of that tree.

const SHIPPED: String = "res://data/unlocks.json"
const FIXTURE: String = "res://tests/fixtures/data_variety/unlocks.json"

var cs: ContentSet


func before_test() -> void:
	cs = ArchiveTestTree.content()


func _row(content: ContentSet, id: StringName) -> String:
	var u: UnlockDef = content.unlock(id)
	return "%s|%d|%d|%d|%s" % [u.id, u.branch, u.tier, u.cost, ",".join(PackedStringArray(u.grants.map(func(g: StringName) -> String: return String(g))))]


func test_24_unlocks_cost_5250_and_4650_without_the_stretch_turrets() -> void:
	assert_int(cs.unlocks.size()).is_equal(24)
	var total: int = 0
	for u: UnlockDef in cs.unlocks:
		total += u.cost
	assert_int(total).is_equal(ArchiveTestTree.TOTAL_COST)
	assert_int(total - cs.unlock(&"u_f_turret_arc").cost - cs.unlock(&"u_f_turret_mortar").cost).is_equal(4650)


func test_each_branch_and_tier_has_the_design_rows() -> void:
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.ARMORY, 1).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.ARMORY, 2).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.ARMORY, 3).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.DIRECTIVES, 1).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.DIRECTIVES, 2).size()).is_equal(3)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.DIRECTIVES, 3).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.KITS, 1).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.KITS, 2).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.KITS, 3).size()).is_equal(1)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.FIELD, 1).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.FIELD, 2).size()).is_equal(2)
	assert_int(ArchiveTestTree.ids_at(cs, UnlockDef.Branch.FIELD, 3).size()).is_equal(2)


func test_the_gates_and_the_cheapest_first_unlock() -> void:
	assert_array(Array(cs.run.tier_gates)).is_equal([3, 8])
	var cheapest: int = 1 << 30
	for u: UnlockDef in cs.unlocks:
		cheapest = mini(cheapest, u.cost)
	assert_int(cheapest).is_equal(80)  # SPEC 8.3: the first unlock is 80 Data


func test_the_directive_packs_name_the_directives_of_content_3() -> void:
	assert_int(cs.unlock(&"u_p_blast").grants.size()).is_equal(4)
	assert_bool(cs.unlock(&"u_p_gunline").grants.has(&"mine_layer")).is_true()
	assert_bool(cs.unlock(&"u_p_ledger").grants.has(&"data_siphon")).is_true()
	var granted: int = 0
	for u: UnlockDef in cs.unlocks:
		if u.branch == UnlockDef.Branch.DIRECTIVES:
			granted += u.grants.size()
	assert_int(granted).is_equal(29)  # 60 directives, 31 in the base pool


func test_six_kits_the_first_is_free_and_every_kit_op_is_valid() -> void:
	assert_int(cs.kits.size()).is_equal(6)
	assert_int(cs.kits[0].cost).is_equal(0)
	assert_str(String(cs.kits[0].id)).is_equal("k_standard")
	assert_int(cs.kits[0].ops.size()).is_equal(0)
	var errors: PackedStringArray = PackedStringArray()
	for k: KitDef in cs.kits:
		VarietyValidator.check_ops(errors, cs, "unlocks.json", "$.kits[%d]" % k.index, k.ops, false)
		assert_str(k.name_key).is_equal("kit.%s.name" % String(k.id).trim_prefix("k_"))
	assert_str("\n".join(errors)).is_empty()
	assert_int(cs.kit_index(&"k_gambler")).is_equal(5)


func test_kit_ops_follow_the_kit_table() -> void:
	var breacher: KitDef = cs.kit(&"k_breacher")
	assert_int(breacher.ops.size()).is_equal(3)
	assert_str(String(breacher.ops[0].target)).is_equal("weapon")
	assert_str(String(breacher.ops[0].arg)).is_equal("scattergun")
	assert_float(breacher.ops[2].value).is_equal_approx(-0.15, 0.0001)  # core max -15%
	var ledger: KitDef = cs.kit(&"k_ledger")
	assert_float(ledger.ops[0].value).is_equal(400.0)
	assert_float(ledger.ops[1].value).is_equal(2.0)
	var gunline: KitDef = cs.kit(&"k_gunline")
	assert_float(gunline.ops[0].value).is_equal(2.0)
	assert_str(String(gunline.ops[1].target)).is_equal("w_dmg_mul")
	var signal_kit: KitDef = cs.kit(&"k_signal")
	assert_str(String(signal_kit.ops[0].arg)).is_equal("deadfall_strike")
	assert_str(String(signal_kit.ops[2].target)).is_equal("no_turret_pity")
	var gambler: KitDef = cs.kit(&"k_gambler")
	assert_str(String(gambler.ops[0].arg)).is_equal("corrupted")
	assert_str(String(gambler.ops[1].arg)).is_equal("prototype")


func test_13_milestones_pay_1050() -> void:
	assert_int(cs.run.milestones.size()).is_equal(13)
	var total: int = 0
	for id: StringName in cs.run.milestones:
		total += cs.run.milestones[id]
	assert_int(total).is_equal(ArchiveTestTree.MILESTONE_TOTAL)
	assert_int(cs.run.milestones[&"ms_first_victory"]).is_equal(200)
	assert_int(cs.run.milestones[&"ms_three_builds"]).is_equal(150)
	for kit: KitDef in cs.kits:
		assert_int(cs.run.milestones[StringName("ms_victory_kit_" + String(kit.id))]).is_equal(75)


func test_the_milestone_ids_match_what_the_game_layer_sends() -> void:
	for b: BossDef in cs.bosses:
		assert_bool(cs.run.milestones.has(StringName(RewardLedger.MS_FIRST_BOSS + String(b.id)))).is_true()
	assert_bool(cs.run.milestones.has(RewardLedger.MS_FIRST_VICTORY)).is_true()
	assert_bool(cs.run.milestones.has(RewardLedger.MS_THREE_BUILDS)).is_true()


# --- the shipped file ---


func test_the_shipped_file_and_its_fixture_copy_are_byte_identical() -> void:
	assert_bool(FileAccess.get_file_as_bytes(SHIPPED) == FileAccess.get_file_as_bytes(FIXTURE)).is_true()


func test_every_shipped_row_is_a_row_of_the_complete_tree() -> void:
	var shipped: ContentSet = TestContent.variety()
	assert_int(shipped.unlocks.size()).is_equal(12)
	for u: UnlockDef in shipped.unlocks:
		assert_str(_row(shipped, u.id)).is_equal(_row(cs, u.id))
	assert_array(Array(shipped.run.tier_gates)).is_equal(Array(cs.run.tier_gates))
	assert_dict(shipped.run.milestones).is_equal(cs.run.milestones)
	assert_str(String(shipped.kits[0].id)).is_equal("k_standard")


func test_the_shipped_unlocks_hold_back_only_weapons_and_field_options() -> void:
	var shipped: ContentSet = TestContent.variety()
	for u: UnlockDef in shipped.unlocks:
		assert_bool(u.branch == UnlockDef.Branch.ARMORY or u.branch == UnlockDef.Branch.FIELD).is_true()
	assert_bool(shipped.unlock(&"u_w_arc") != null).is_true()
	assert_str("\n".join(ContentValidator.validate(shipped))).is_empty()  # the shipped rows validate on their own
