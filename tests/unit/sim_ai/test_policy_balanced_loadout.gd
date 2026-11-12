extends GdUnitTestSuite
## V2-H: the `balanced` bot's weapons (CONTENT 13): the best tier per role, level-ups of duplicates, scrapping a crate
## that would lower the loadout, and swapping to the area weapon on a crowd. Hand-made arsenals on
## TestContent.variety() (slot 0 holds the pistol, slot 1 is empty).

var w: SimWorld
var bot: PolicyBot


func before_test() -> void:
	w = VarietyHKit.awaiting(PhaseState.Await.SALVAGE)
	bot = PolicyBot.new(PolicyBot.Policy.BALANCED)


func _arg(weapon_ids: Array[StringName]) -> int:
	VarietyHKit.crate(w, weapon_ids)
	return PolicyLoadout.balanced_salvage_arg(w)


func test_roles_split_area_and_chain_weapons_from_single_target_ones() -> void:
	for id: StringName in [&"scattergun", &"hornet_rack", &"slag_mortar", &"arc_projector"]:
		assert_int(PolicyLoadout.role_of(w.content.weapons[Ids.WEAPONS.find(id)])).is_equal(PolicyLoadout.Role.AREA)
	for id: StringName in [&"pistol", &"smg", &"assault_rifle", &"lmg", &"cutting_torch", &"rail_lance"]:
		assert_int(PolicyLoadout.role_of(w.content.weapons[Ids.WEAPONS.find(id)])).is_equal(PolicyLoadout.Role.SINGLE)


func test_a_crate_goes_into_the_empty_slot() -> void:
	assert_int(_arg([&"scattergun"])).is_equal(1)
	assert_int(_arg([&"rail_lance"])).is_equal(1)


func test_the_second_weapon_replaces_the_one_that_fills_the_same_role_worse() -> void:
	VarietyHKit.carry(w, 1, &"smg")  # pistol (T1 single) and smg (T2 single)
	assert_int(_arg([&"scattergun"])).is_equal(0)  # the area role is empty: the pistol makes room


func test_a_crate_that_would_lower_the_loadout_is_scrapped() -> void:
	VarietyHKit.carry(w, 0, &"lmg")
	VarietyHKit.carry(w, 1, &"arc_projector")
	assert_int(_arg([&"smg"])).is_equal(SalvageSystem.ACTION_SCRAP)
	assert_int(_arg([&"scattergun"])).is_equal(SalvageSystem.ACTION_SCRAP)


func test_a_better_weapon_of_the_same_role_replaces_the_weaker() -> void:
	VarietyHKit.carry(w, 0, &"smg")
	VarietyHKit.carry(w, 1, &"scattergun")
	assert_int(_arg([&"lmg"])).is_equal(0)  # T4 single replaces T2 single


func test_a_duplicate_is_levelled_up_until_level_three() -> void:
	VarietyHKit.carry(w, 1, &"smg", 2)
	assert_int(_arg([&"smg"])).is_equal(SalvageSystem.ACTION_LEVEL_UP)
	VarietyHKit.carry(w, 1, &"smg", 3)
	assert_int(_arg([&"smg"])).is_equal(SalvageSystem.ACTION_SCRAP)  # nothing left to gain from it


func test_a_boss_crate_picks_the_weapon_that_helps_most() -> void:
	assert_int(_arg([&"smg", &"rail_lance"])).is_equal(1 * 16 + 1)  # the rail lance, into the empty slot
	assert_int(_arg([&"lmg", &"arc_projector"])).is_equal(1 * 16 + 1)  # T5 area beats T4 single
	VarietyHKit.carry(w, 1, &"scattergun")
	assert_int(_arg([&"smg", &"rail_lance"])).is_equal(1 * 16 + 0)  # replaces the pistol


func test_a_big_step_beats_a_level_up() -> void:
	VarietyHKit.carry(w, 1, &"smg")
	assert_int(_arg([&"smg", &"rail_lance"])).is_equal(1 * 16 + 0)  # T5 for the pistol: +3 tiers against +1


func test_an_empty_or_unknown_crate_is_scrapped() -> void:
	VarietyHKit.crate(w, [])
	assert_int(PolicyLoadout.balanced_salvage_arg(w)).is_equal(SalvageSystem.ACTION_SCRAP)
	bot.act(w)
	assert_int(w.command_queue[0].kind).is_equal(SimCommand.Kind.SALVAGE)


func test_the_answer_goes_out_as_a_salvage_command() -> void:
	VarietyHKit.crate(w, [&"smg", &"rail_lance"])
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(1)
	assert_int(w.command_queue[0].kind).is_equal(SimCommand.Kind.SALVAGE)
	assert_int(w.command_queue[0].arg).is_equal(17)


# --- swapping ---


func _armed(active: int) -> void:
	VarietyHKit.carry(w, 0, &"pistol")
	VarietyHKit.carry(w, 1, &"scattergun")
	w.arsenal.active = active
	w.phase = GameState.Id.SPAWNING
	w.phase_state.awaiting = PhaseState.Await.NONE


func test_the_area_weapon_comes_out_at_twelve_enemies_near_the_core() -> void:
	_armed(0)
	assert_int(PolicyLoadout.swap_target(w, 11)).is_equal(-1)
	assert_int(PolicyLoadout.swap_target(w, 12)).is_equal(1)


func test_the_single_target_weapon_comes_back_at_five() -> void:
	_armed(1)
	assert_int(PolicyLoadout.swap_target(w, 6)).is_equal(-1)
	assert_int(PolicyLoadout.swap_target(w, 5)).is_equal(0)
	assert_int(PolicyLoadout.swap_target(w, 40)).is_equal(-1)  # a crowd keeps the area weapon


func test_nothing_to_swap_to_when_the_other_slot_is_empty_or_the_same_role() -> void:
	VarietyHKit.carry(w, 0, &"pistol")
	w.arsenal.slot_weapon[1] = -1
	assert_int(PolicyLoadout.swap_target(w, 30)).is_equal(-1)
	VarietyHKit.carry(w, 1, &"smg")
	assert_int(PolicyLoadout.swap_target(w, 30)).is_equal(-1)


func test_a_crowd_in_the_field_sends_one_swap_and_then_waits() -> void:
	_armed(0)
	VarietyHKit.crowd(w, 12)
	w.tick = 600
	bot.act(w)
	var kinds: Array[int] = VarietyHKit.kinds(w)
	assert_array(kinds).contains([SimCommand.Kind.SWAP_WEAPON])
	var swap: SimCommand = w.command_queue[kinds.find(SimCommand.Kind.SWAP_WEAPON)]
	assert_int(swap.arg).is_equal(1)
	w.command_queue.clear()
	bot.act(w)
	assert_array(VarietyHKit.kinds(w)).not_contains([SimCommand.Kind.SWAP_WEAPON])  # SWAP_PAUSE_TICKS
	w.tick = 600 + PolicyLoadout.SWAP_PAUSE_TICKS
	bot.act(w)
	assert_array(VarietyHKit.kinds(w)).contains([SimCommand.Kind.SWAP_WEAPON])  # the crowd is still there


func test_the_crowd_is_only_looked_at_every_sixth_tick_and_not_during_a_swap() -> void:
	_armed(0)
	VarietyHKit.crowd(w, 12)
	w.tick = 601
	bot.act(w)
	assert_array(VarietyHKit.kinds(w)).not_contains([SimCommand.Kind.SWAP_WEAPON])
	w.tick = 606
	w.arsenal.swap_left = 10
	bot.act(w)
	assert_array(VarietyHKit.kinds(w)).not_contains([SimCommand.Kind.SWAP_WEAPON])


func test_enemies_far_from_the_core_are_not_a_crowd() -> void:
	_armed(0)
	VarietyHKit.crowd(w, 12, 14.0)
	w.tick = 600
	bot.act(w)
	assert_array(VarietyHKit.kinds(w)).not_contains([SimCommand.Kind.SWAP_WEAPON])


func test_slot_helpers_read_the_arsenal() -> void:
	VarietyHKit.carry(w, 1, &"lmg", 2)
	assert_int(PolicyLoadout.weapon_in(w, 1)).is_equal(Ids.WP_LMG)
	assert_int(PolicyLoadout.tier_in(w, 1)).is_equal(4)
	assert_int(PolicyLoadout.carried_slot(w, Ids.WP_LMG)).is_equal(1)
	assert_int(PolicyLoadout.carried_slot(w, Ids.WP_RAIL_LANCE)).is_equal(-1)
	assert_int(PolicyLoadout.weapon_in(w, 2)).is_equal(-1)  # the third slot does not exist
	assert_int(PolicyLoadout.emptiest_slot(w)).is_equal(0)  # pistol T1 is the weakest of two
