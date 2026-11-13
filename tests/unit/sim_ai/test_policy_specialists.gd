extends GdUnitTestSuite
## V4-T: the four specialists (CONTENT 13): `hoarder` (weapon directives, the crate route, the two highest tiers),
## `spammer` (ability directives, every ability the tick it is ready), `turret_rush` (turret then core directives, the
## standard route) and `risk` (corrupted directives, the hot route). Hand-made states on TestContent.variety().

const WEAPON_OFFER: Array[StringName] = [&"reinforced_cage", &"hot_loads", &"emp_capacitor", &"turret_deploy"]


func _draft(offer: Array[StringName], wave_number: int = 1) -> SimWorld:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.DRAFT, wave_number)
	VarietyHKit.offer(w, offer)
	return w


func _only(w: SimWorld) -> SimCommand:
	assert_int(w.command_queue.size()).is_equal(1)
	return w.command_queue[0]


func _slot_of(w: SimWorld, id: StringName) -> int:
	return w.draft.offer.find(w.content.directive_index(id))


func _act(policy: int, w: SimWorld) -> SimCommand:
	PolicyBot.new(policy).act(w)
	return _only(w)


# --- drafts ---


func test_hoarder_takes_the_weapon_directive_over_better_scoring_cards() -> void:
	var w: SimWorld = _draft([&"reinforced_cage", &"emp_capacitor", &"hot_loads", &"glass_cannon"])
	var cmd: SimCommand = _act(PolicyBot.Policy.HOARDER, w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)
	assert_int(cmd.arg).is_equal(_slot_of(w, &"hot_loads"))


func test_spammer_takes_the_ability_directive() -> void:
	var w: SimWorld = _draft(WEAPON_OFFER)
	assert_int(_act(PolicyBot.Policy.SPAMMER, w).arg).is_equal(_slot_of(w, &"emp_capacitor"))


func test_turret_rush_takes_a_turret_directive_then_a_core_directive() -> void:
	var w: SimWorld = _draft(WEAPON_OFFER)
	assert_int(_act(PolicyBot.Policy.TURRET_RUSH, w).arg).is_equal(_slot_of(w, &"turret_deploy"))
	var no_turret: SimWorld = _draft([&"hot_loads", &"reinforced_cage", &"emp_capacitor"])
	assert_int(_act(PolicyBot.Policy.TURRET_RUSH, no_turret).arg).is_equal(_slot_of(no_turret, &"reinforced_cage"))


func test_risk_takes_every_corrupted_directive_it_is_offered() -> void:
	var w: SimWorld = _draft([&"incendiary_tips", &"glass_cannon", &"hot_loads"])
	assert_int(_act(PolicyBot.Policy.RISK, w).arg).is_equal(_slot_of(w, &"glass_cannon"))
	w.set_core_hp(w.core_max_hp * 0.2)  # even with a dying core: the taste does not depend on it
	w.command_queue.clear()
	assert_int(_act(PolicyBot.Policy.RISK, w).arg).is_equal(_slot_of(w, &"glass_cannon"))


func test_every_specialist_falls_back_to_the_balanced_pick_when_its_taste_is_not_offered() -> void:
	var offer: Array[StringName] = [&"hot_loads", &"cyclic_tuning", &"incendiary_tips"]  # weapon cards only
	for policy: int in [PolicyBot.Policy.SPAMMER, PolicyBot.Policy.TURRET_RUSH, PolicyBot.Policy.RISK]:
		var w: SimWorld = _draft(offer)
		var cmd: SimCommand = _act(policy, w)
		assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)
		assert_int(cmd.arg).is_equal(_slot_of(w, &"incendiary_tips"))  # the rare card scores highest


func test_a_favoured_category_chooses_by_score_inside_it() -> void:
	var w: SimWorld = _draft([&"hot_loads", &"incendiary_tips", &"cyclic_tuning"])
	assert_int(_act(PolicyBot.Policy.HOARDER, w).arg).is_equal(_slot_of(w, &"incendiary_tips"))


func test_hoarder_rerolls_without_a_weapon_card_when_it_holds_200_scrap() -> void:
	var offer: Array[StringName] = [&"reinforced_cage", &"emp_capacitor", &"turret_deploy"]
	var poor: SimWorld = _draft(offer)
	poor.add_scrap(199)
	var pick: SimCommand = _act(PolicyBot.Policy.HOARDER, poor)
	assert_int(pick.kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)  # 199 is not enough, and it does not patch or reroll like balanced
	var rich: SimWorld = _draft(offer)
	rich.add_scrap(200)
	assert_int(_act(PolicyBot.Policy.HOARDER, rich).kind).is_equal(SimCommand.Kind.REROLL)
	var free: SimWorld = _draft(offer)
	free.draft.free_rerolls = 1
	free.add_scrap(100)
	assert_int(_act(PolicyBot.Policy.HOARDER, free).kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)


func test_hoarder_does_not_reroll_a_locked_draft_or_forever() -> void:
	var offer: Array[StringName] = [&"reinforced_cage", &"emp_capacitor", &"turret_deploy"]
	var w: SimWorld = _draft(offer)
	w.add_scrap(900)
	w.draft.reroll_locked = true
	assert_int(_act(PolicyBot.Policy.HOARDER, w).kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)
	var open: SimWorld = _draft(offer)
	open.add_scrap(900)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.HOARDER)
	for _n: int in PolicyScoring.MAX_REROLLS_PER_DRAFT:
		open.command_queue.clear()
		bot.act(open)
		assert_int(_only(open).kind).is_equal(SimCommand.Kind.REROLL)
	open.command_queue.clear()
	bot.act(open)
	assert_int(_only(open).kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)  # the cap of a draft


func test_an_empty_offer_is_skipped_by_every_specialist() -> void:
	for policy: int in [PolicyBot.Policy.HOARDER, PolicyBot.Policy.SPAMMER, PolicyBot.Policy.TURRET_RUSH, PolicyBot.Policy.RISK]:
		var w: SimWorld = _draft([&"", &"", &""])
		assert_int(_act(policy, w).kind).is_equal(SimCommand.Kind.SKIP_DRAFT)


# --- routes ---


func _route(policy: int, rewards: Array[StringName], hot_flags: Array[bool]) -> int:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE, 2)
	var options: Array[RouteOption] = []
	for i: int in rewards.size():
		options.append(VarietyHKit.option(w, &"pack_tide" if i == 0 else &"pack_column", rewards[i], hot_flags[i]))
	VarietyHKit.route(w, 3, options)
	var cmd: SimCommand = _act(policy, w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_ROUTE)
	return cmd.arg


func test_hoarder_takes_the_crate_route_else_the_hot_one() -> void:
	assert_int(_route(PolicyBot.Policy.HOARDER, [&"rw_scrap", &"rw_crate"], [false, true])).is_equal(1)
	assert_int(_route(PolicyBot.Policy.HOARDER, [&"rw_crate", &"rw_scrap"], [false, true])).is_equal(0)  # the crate wins over hot
	assert_int(_route(PolicyBot.Policy.HOARDER, [&"rw_scrap", &"rw_patch"], [false, true])).is_equal(1)  # no crate: hot
	assert_int(_route(PolicyBot.Policy.HOARDER, [&"rw_scrap", &"rw_patch"], [false, false])).is_equal(0)


func test_spammer_takes_option_a_and_turret_rush_the_standard_option() -> void:
	assert_int(_route(PolicyBot.Policy.SPAMMER, [&"rw_scrap", &"rw_crate"], [true, false])).is_equal(0)
	assert_int(_route(PolicyBot.Policy.TURRET_RUSH, [&"rw_scrap", &"rw_crate"], [true, false])).is_equal(1)
	assert_int(_route(PolicyBot.Policy.TURRET_RUSH, [&"rw_scrap", &"rw_crate"], [true, true])).is_equal(0)  # none is standard


func test_risk_always_takes_the_hot_route() -> void:
	assert_int(_route(PolicyBot.Policy.RISK, [&"rw_scrap", &"rw_crate"], [false, true])).is_equal(1)
	assert_int(_route(PolicyBot.Policy.RISK, [&"rw_crate", &"rw_scrap"], [true, false])).is_equal(0)
	assert_int(_route(PolicyBot.Policy.RISK, [&"rw_crate", &"rw_scrap"], [false, false])).is_equal(0)


func test_a_forced_route_mode_overrides_balanced_only() -> void:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.ROUTE, 2)
	VarietyHKit.route(w, 3, [VarietyHKit.option(w, &"pack_tide", &"rw_scrap", false), VarietyHKit.option(w, &"pack_column", &"rw_crate", true)])
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.BALANCED)
	bot.route_mode = PolicyBot.RouteMode.STANDARD
	bot.act(w)
	assert_int(_only(w).arg).is_equal(0)
	w.command_queue.clear()
	var hot_bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.BALANCED)
	hot_bot.route_mode = PolicyBot.RouteMode.HOT
	hot_bot.act(w)
	assert_int(_only(w).arg).is_equal(1)


# --- crates ---


func _crate_arg(policy: int, carried: Array[StringName], crate: Array[StringName]) -> int:
	var w: SimWorld = VarietyHKit.awaiting(PhaseState.Await.SALVAGE)
	for slot: int in carried.size():
		VarietyHKit.carry(w, slot, carried[slot])
	VarietyHKit.crate(w, crate)
	return _act(policy, w).arg


func test_hoarder_keeps_the_two_highest_tiers() -> void:
	assert_int(_crate_arg(PolicyBot.Policy.HOARDER, [&"pistol"], [&"smg"])).is_equal(1)  # the empty slot
	assert_int(_crate_arg(PolicyBot.Policy.HOARDER, [&"pistol", &"smg"], [&"lmg"])).is_equal(0)  # replaces the pistol (T1)
	assert_int(_crate_arg(PolicyBot.Policy.HOARDER, [&"lmg", &"smg"], [&"assault_rifle"])).is_equal(1)  # T3 replaces T2
	assert_int(_crate_arg(PolicyBot.Policy.HOARDER, [&"lmg", &"arc_projector"], [&"assault_rifle"])).is_equal(SalvageSystem.ACTION_SCRAP)


func test_hoarder_levels_up_a_duplicate_and_takes_the_best_of_a_boss_crate() -> void:
	assert_int(_crate_arg(PolicyBot.Policy.HOARDER, [&"lmg", &"smg"], [&"smg"])).is_equal(SalvageSystem.ACTION_LEVEL_UP)
	assert_int(_crate_arg(PolicyBot.Policy.HOARDER, [&"pistol"], [&"smg", &"rail_lance"])).is_equal(1 * 16 + 1)
	assert_int(_crate_arg(PolicyBot.Policy.HOARDER, [&"lmg", &"smg"], [&"pistol"])).is_equal(SalvageSystem.ACTION_SCRAP)


func test_spammer_and_turret_rush_take_crates_like_greedy() -> void:
	for policy: int in [PolicyBot.Policy.SPAMMER, PolicyBot.Policy.TURRET_RUSH, PolicyBot.Policy.GREEDY]:
		assert_int(_crate_arg(policy, [&"pistol"], [&"arc_projector"])).is_equal(1)
		assert_int(_crate_arg(policy, [&"pistol", &"smg"], [&"lmg"])).is_equal(0)  # the emptiest slot is the pistol's


func _same_as_balanced(crate: Array[StringName]) -> void:
	var balanced: int = _crate_arg(PolicyBot.Policy.BALANCED, [&"pistol", &"smg"], crate)
	assert_int(_crate_arg(PolicyBot.Policy.RISK, [&"pistol", &"smg"], crate)).is_equal(balanced)


func test_risk_takes_crates_like_balanced() -> void:
	_same_as_balanced([&"smg"])
	_same_as_balanced([&"scattergun"])
	_same_as_balanced([&"smg", &"rail_lance"])
