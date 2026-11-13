extends GdUnitTestSuite
## V4-C: the validator rules that guard the new content (directives, packs, modifiers, kits, unlock packs), each shown with
## a bad variant of the frozen variety fixture built in memory (the files of tests/fixtures/data_bad_variety belong to
## V1-S). The validator itself is a frozen file; the rule for a `hook` name lives here, against ModRules.KNOWN_HOOKS.

var docs: Dictionary


func before_test() -> void:
	docs = VarietyBadData.docs()


func _dir(index: int) -> Dictionary:
	var file: Dictionary = docs["directives.json"]
	var rows: Array = file["directives"]
	var row: Dictionary = rows[index]
	return row


func _run() -> Dictionary:
	var file: Dictionary = docs["run.json"]
	return file


## The loader errors of the patched docs, else the validator errors.
func _errors(strings: Dictionary = {}) -> PackedStringArray:
	var variety: Dictionary = {}
	for file: String in VarietyLoader.FILES:
		if docs.has(file):
			variety[file] = docs[file]
	var text: Dictionary = strings if not strings.is_empty() else VarietyBadData.strings()
	var balance: Dictionary = docs["vertical_slice_balance.json"]
	var waves: Dictionary = docs["waves.json"]
	var tokens: Dictionary = docs["visual_tokens.json"]
	var ext: Dictionary = docs["content_ext.json"]
	var arena: Dictionary = docs["arena.json"]
	var res: ContentLoadResult = ContentLoader.build(balance, waves, tokens, ext, arena, text, variety)
	if not res.errors.is_empty():
		return res.errors
	return ContentValidator.validate(res.content)


func _has(errors: PackedStringArray, part: String) -> bool:
	for e: String in errors:
		if e.contains(part):
			return true
	return false


func _unknown_hooks(c: ContentSet) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: DirectiveDef in c.directives:
		if d.hook != &"" and not ModRules.KNOWN_HOOKS.has(String(d.hook)):
			out.append("%s: %s" % [String(d.id), String(d.hook)])
	return out


func test_the_unpatched_content_is_clean() -> void:
	assert_array(Array(_errors())).is_empty()


func test_a_directive_op_must_name_a_real_stat() -> void:
	_dir(8)["ops"] = [{"stat": "no_such_stat", "add": 1}]
	var errors: PackedStringArray = _errors()
	assert_bool(_has(errors, "directives.json: $.directives[8].ops[0].stat: unknown stat 'no_such_stat'")).is_true()


func test_a_directive_flag_and_grant_must_be_real() -> void:
	_dir(20)["ops"] = [{"flag": "no_such_flag"}]
	_dir(21)["ops"] = [{"grant": "weapon", "n": 1, "id": "no_such_weapon"}]
	var errors: PackedStringArray = _errors()
	assert_bool(_has(errors, "$.directives[20].ops[0].flag: unknown flag 'no_such_flag'")).is_true()
	assert_bool(_has(errors, "$.directives[21].ops[0].id: unknown id 'no_such_weapon' for grant 'weapon'")).is_true()


func test_a_directive_pool_must_be_base_or_an_unlock() -> void:
	_dir(16)["pool"] = "u_p_nope"
	assert_bool(_has(_errors(), "$.directives[16].pool: unknown unlock id 'u_p_nope'")).is_true()


func test_directive_ids_are_unique_and_a_corrupted_one_is_corrupted_twice() -> void:
	_dir(9)["id"] = "extended_feed"
	_dir(59)["category"] = "weapon"
	var errors: PackedStringArray = _errors()
	assert_bool(_has(errors, "$.directives[9].id: duplicate id 'extended_feed'")).is_true()
	assert_bool(_has(errors, "$.directives[59]: category and rarity must both be corrupted, or neither")).is_true()


func test_a_directive_needs_at_least_one_stack() -> void:
	_dir(30)["max"] = 0
	assert_bool(_has(_errors(), "$.directives[30].max: must be >= 1")).is_true()


func test_a_directive_needs_a_name_and_a_description_string() -> void:
	var strings: Dictionary = VarietyBadData.strings()
	strings.erase("directive.cascade.name")
	strings.erase("directive.the_tally.desc")
	var errors: PackedStringArray = _errors(strings)
	assert_bool(_has(errors, "$.directive.cascade.name: missing string")).is_true()
	assert_bool(_has(errors, "$.directive.the_tally.desc: missing string")).is_true()


func test_a_pack_must_have_shares_that_sum_to_one_and_a_real_region() -> void:
	var run: Dictionary = _run()
	var packs: Array = run["packs"]
	var pack: Dictionary = packs[3]
	var groups: Array = pack["groups"]
	var group: Dictionary = groups[0]
	group["share"] = 0.9
	assert_bool(_has(_errors(), "$.packs[3].groups: shares must sum to 1 (got 1.4)")).is_true()
	group["share"] = 0.5
	group["region"] = "nowhere"
	assert_bool(_has(_errors(), "$.packs[3].groups[0].region: unknown spawn region 'nowhere'")).is_true()


func test_a_pack_cannot_use_a_type_without_a_threat_cost() -> void:
	var run: Dictionary = _run()
	var packs: Array = run["packs"]
	var pack: Dictionary = packs[11]  # pack_hunt
	var groups: Array = pack["groups"]
	var group: Dictionary = groups[0]
	group["enemy"] = "ward_pylon"
	assert_bool(_has(_errors(), "$.packs[11].groups[0].enemy: 'ward_pylon' has no threat cost")).is_true()


func test_a_modifier_must_use_real_stats_and_flags() -> void:
	var run: Dictionary = _run()
	var modifiers: Array = run["modifiers"]
	var plated: Dictionary = modifiers[1]
	plated["ops"] = [{"stat": "armor", "add": 4}]
	var twin: Dictionary = modifiers[3]
	twin["ops"] = [{"flag": "two_gates"}]
	var errors: PackedStringArray = _errors()
	assert_bool(_has(errors, "$.modifiers[1].ops[0].stat: unknown stat 'armor'")).is_true()
	assert_bool(_has(errors, "$.modifiers[3].ops[0].flag: unknown flag 'two_gates'")).is_true()


func test_every_pack_and_modifier_needs_a_name_string() -> void:
	var strings: Dictionary = VarietyBadData.strings()
	strings.erase("pack.hunt.name")
	strings.erase("modifier.no_breather.name")
	var errors: PackedStringArray = _errors(strings)
	assert_bool(_has(errors, "$.pack.hunt.name: missing string")).is_true()
	assert_bool(_has(errors, "$.modifier.no_breather.name: missing string")).is_true()


func test_an_unlock_pack_grants_only_directives_that_exist_and_each_only_once() -> void:
	var file: Dictionary = docs["unlocks.json"]
	var unlocks: Array = file["unlocks"]
	var arc: Dictionary = unlocks[6]  # u_p_arc
	var grants: Array = arc["grants"]
	grants.append("no_such_directive")
	grants.append("overpressure")  # u_p_blast grants it already
	var errors: PackedStringArray = _errors()
	assert_bool(_has(errors, "unknown item 'no_such_directive' for branch directives")).is_true()
	assert_bool(_has(errors, "'overpressure' is already granted by 'u_p_blast'")).is_true()


func test_a_kit_may_only_grant_real_things() -> void:
	var file: Dictionary = docs["unlocks.json"]
	var kits: Array = file["kits"]
	kits.append({"id": "k_bad", "name_key": "kit.standard.name", "cost": 10, "ops": [
		{"grant": "weapon", "n": 1, "id": "no_such_weapon"}, {"grant": "event_charge", "n": 1, "id": "no_such_event"},
		{"stat": "no_such_stat", "add": 1},
	]})
	var errors: PackedStringArray = _errors()
	assert_bool(_has(errors, "$.kits[1].ops[0].id: unknown id 'no_such_weapon' for grant 'weapon'")).is_true()
	assert_bool(_has(errors, "$.kits[1].ops[1].id: unknown id 'no_such_event' for grant 'event_charge'")).is_true()
	assert_bool(_has(errors, "$.kits[1].ops[2].stat: unknown stat 'no_such_stat'")).is_true()


func test_the_shipped_hook_names_are_all_known_and_a_misspelt_one_is_caught() -> void:
	var c: ContentSet = TestContent.variety()
	assert_array(Array(_unknown_hooks(c))).is_empty()
	c.directives[10].hook = &"on_warden_kil"
	assert_array(Array(_unknown_hooks(c))).is_equal(["first_strike: on_warden_kil"])
