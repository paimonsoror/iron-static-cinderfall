extends GdUnitTestSuite
## V4-C: the shape of the 60 directives of data/directives.json (VARIETY_CONTENT 3) on the frozen variety fixture: the
## counts per category and rarity, the pools and the unlock packs that grant them, the hooks, and the validator.

var c: ContentSet

const SLICE_ORDER: Array[StringName] = [
	&"hot_loads", &"cyclic_tuning", &"penetrator_cores", &"turret_deploy", &"reinforced_cage", &"emp_capacitor",
	&"incendiary_tips", &"glass_cannon",
]
## Directives that name a hook (the 26 HOOK ones of CONTENT 3, plus executioner, field_weld and open_gate).
const HOOKED: Array[StringName] = [
	&"incendiary_tips", &"executioner", &"ricochet", &"kill_chain", &"shock_rounds", &"twin_link", &"overwatch",
	&"flak_heads", &"arc_pylons", &"mine_layer", &"field_weld", &"reactive_plating", &"core_lash", &"ember_vent",
	&"amber_surge", &"dead_mans_switch", &"emp_overload", &"aftershock", &"shield_burst", &"cascade",
	&"compound_interest", &"open_gate", &"overclocked_core", &"chorus_handshake", &"unstable_munitions",
	&"borrowed_time", &"static_pact", &"single_point", &"the_tally",
]


func before_test() -> void:
	c = TestContent.variety()


func _count(category: int) -> int:
	var n: int = 0
	for d: DirectiveDef in c.directives:
		if d.category == category:
			n += 1
	return n


func _count_rarity(rarity: int) -> int:
	var n: int = 0
	for d: DirectiveDef in c.directives:
		if d.rarity == rarity:
			n += 1
	return n


func test_sixty_directives_and_the_slice_ones_keep_their_index() -> void:
	assert_int(c.directives.size()).is_equal(60)
	for i: int in SLICE_ORDER.size():
		assert_str(String(c.directives[i].id)).is_equal(String(SLICE_ORDER[i]))
		assert_int(c.directives[i].index).is_equal(i)


func test_the_categories_and_rarities_are_those_of_the_design() -> void:
	assert_int(_count(DirectiveDef.Category.WEAPON)).is_equal(14)
	assert_int(_count(DirectiveDef.Category.TURRET)).is_equal(10)
	assert_int(_count(DirectiveDef.Category.CORE)).is_equal(8)
	assert_int(_count(DirectiveDef.Category.ABILITY)).is_equal(11)
	assert_int(_count(DirectiveDef.Category.ECONOMY)).is_equal(8)
	assert_int(_count(DirectiveDef.Category.CORRUPTED)).is_equal(9)
	assert_int(_count_rarity(DirectiveDef.Rarity.COMMON)).is_equal(18)
	assert_int(_count_rarity(DirectiveDef.Rarity.RARE)).is_equal(24)
	assert_int(_count_rarity(DirectiveDef.Rarity.PROTOTYPE)).is_equal(9)
	assert_int(_count_rarity(DirectiveDef.Rarity.CORRUPTED)).is_equal(9)


func test_31_directives_are_base_and_29_belong_to_the_seven_packs() -> void:
	var base: int = 0
	var packed: Dictionary[StringName, int] = {}
	for d: DirectiveDef in c.directives:
		if d.pool == &"base":
			base += 1
		else:
			packed[d.pool] = packed.get(d.pool, 0) + 1
	assert_int(base).is_equal(31)
	assert_dict(packed).is_equal({
		&"u_p_blast": 4, &"u_p_arc": 4, &"u_p_fortress": 4, &"u_p_gunline": 5, &"u_p_ledger": 4, &"u_p_corrupted": 4,
		&"u_p_proto": 4,
	})


func test_every_pack_unlock_grants_exactly_the_directives_that_name_it_as_their_pool() -> void:
	for u: UnlockDef in c.unlocks:
		if u.branch != UnlockDef.Branch.DIRECTIVES:
			continue
		var named: Array[StringName] = []
		for d: DirectiveDef in c.directives:
			if d.pool == u.id:
				named.append(d.id)
		var granted: Array[StringName] = u.grants.duplicate()
		named.sort()
		granted.sort()
		assert_array(granted).override_failure_message("pack %s" % String(u.id)).is_equal(named)


func test_base_pool_and_a_pack_decide_what_can_be_offered() -> void:
	var cfg: SimConfig = SimConfig.create(c, 1)
	var w: SimWorld = SimWorld.new(cfg)
	# 31 base directives, minus turret_servos and turret_heavy_slugs (they need a deployed turret)
	assert_int(DraftOffer.candidates(w).size()).is_equal(29)
	var shock: int = c.directive_index(&"shock_rounds")
	assert_bool(DraftOffer.candidates(w).has(shock)).is_false()
	cfg.unlocked = PackedStringArray(["u_p_arc"])
	# shock_rounds, emp_tether and emp_overload join; arc_pylons still needs a turret
	assert_int(DraftOffer.candidates(w).size()).is_equal(32)
	assert_bool(DraftOffer.candidates(w).has(shock)).is_true()
	assert_bool(DraftOffer.candidates(w).has(c.directive_index(&"overpressure"))).is_false()


func test_the_hooked_directives_and_their_hook_names() -> void:
	var hooked: Array[StringName] = []
	for d: DirectiveDef in c.directives:
		if d.hook != &"":
			hooked.append(d.id)
			assert_bool(ModRules.KNOWN_HOOKS.has(String(d.hook))).override_failure_message(
				"%s names the unknown hook %s" % [String(d.id), String(d.hook)]
			).is_true()
	assert_array(hooked).is_equal(HOOKED)
	assert_str(String(c.directive(&"open_gate").hook)).is_equal(String(ModSystem.HOOK_PLAN_PATCH))
	assert_str(String(c.directive(&"chorus_handshake").hook)).is_equal(String(ModSystem.HOOK_PLAN_PATCH))
	assert_str(String(c.directive(&"static_pact").hook)).is_equal(String(ModSystem.HOOK_PLAN_PATCH))


func test_requirements_and_corrupted_rules_of_the_table() -> void:
	assert_float(c.directive(&"ricochet").requires[&"weapon_kind"]).is_equal(float(WeaponDef.Kind.HITSCAN))
	assert_float(c.directive(&"twin_link").requires[&"weapons"]).is_equal(2.0)
	for id: StringName in [&"turret_servos", &"turret_heavy_slugs", &"overwatch", &"sentry_link", &"flak_heads", &"arc_pylons", &"mine_layer", &"pad_capacitors"]:
		assert_float(c.directive(id).requires[&"turrets"]).is_equal(1.0)
	assert_float(c.directive(&"turret_deploy").requires[&"free_pad"]).is_equal(1.0)
	for d: DirectiveDef in c.directives:
		assert_bool((d.rarity == DirectiveDef.Rarity.CORRUPTED) == (d.category == DirectiveDef.Category.CORRUPTED)).is_true()
		if d.rarity == DirectiveDef.Rarity.CORRUPTED or d.rarity == DirectiveDef.Rarity.PROTOTYPE:
			assert_int(d.max_stacks).override_failure_message(String(d.id)).is_equal(2 if d.id == &"overpressure" else 1)


func test_max_stacks_of_the_table() -> void:
	var want: Dictionary[StringName, int] = {
		&"extended_feed": 3, &"fast_hands": 3, &"first_strike": 3, &"heavy_barrel": 3, &"executioner": 2, &"ricochet": 2,
		&"kill_chain": 1, &"shock_rounds": 3, &"overpressure": 2, &"twin_link": 1, &"turret_servos": 4,
		&"turret_heavy_slugs": 4, &"overwatch": 1, &"sentry_link": 1, &"flak_heads": 2, &"arc_pylons": 2, &"mine_layer": 2,
		&"pad_capacitors": 1, &"last_stand_protocol": 1, &"field_weld": 3, &"ground_wire": 2, &"reactive_plating": 3,
		&"core_lash": 3, &"ember_vent": 1, &"amber_surge": 1, &"dead_mans_switch": 1, &"shield_lattice": 3,
		&"overdrive_coolant": 3, &"emp_tether": 2, &"emp_overload": 2, &"aftershock": 1, &"shield_burst": 1,
		&"deadfall_uplink": 2, &"signal_hijack": 1, &"bottomless": 1, &"cascade": 1, &"scavenger_protocol": 3,
		&"requisition_line": 2, &"black_box": 2, &"salvage_drone": 1, &"compound_interest": 1, &"data_siphon": 2,
		&"quartermaster": 1, &"scrap_rounds": 1, &"open_gate": 1, &"overclocked_core": 1, &"chorus_handshake": 1,
		&"unstable_munitions": 1, &"borrowed_time": 1, &"static_pact": 1, &"single_point": 1, &"the_tally": 1,
	}
	assert_int(want.size()).is_equal(52)  # every directive after the 8 of the slice
	for id: StringName in want:
		assert_int(c.directive(id).max_stacks).override_failure_message(String(id)).is_equal(want[id])


func test_the_fixture_with_all_60_directives_passes_the_validator() -> void:
	assert_array(Array(ContentValidator.validate(c))).is_empty()


## Pinned from the first run on the full fixture (VARIETY_SPEC 9.6: "the first offer of seed 1 with the base pool"): a change
## here means the draw sequence of 4.3 or the base pool changed.
func test_golden_first_offers_with_the_31_directive_base_pool() -> void:
	var first: Array = []
	for s: int in [1, 2, 3]:
		var w: SimWorld = VarietyBKit.world_after(TestContent.variety(), 1, s)
		DraftSystem.open(w)
		first.append(VarietyBKit.ids(w.content, w.draft.offer))
	assert_array(first).is_equal([
		[&"cyclic_tuning", &"first_strike", &"black_box"], [&"emp_capacitor", &"requisition_line", &"first_strike"],
		[&"ground_wire", &"deadfall_uplink", &"turret_deploy"],
	])
