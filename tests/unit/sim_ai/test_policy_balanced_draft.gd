extends GdUnitTestSuite
## V2-H: the `balanced` bot's draft and route (CONTENT 13): the score of a card, the order of ties, the reroll and
## patch rules, the hot-route rule. Hand-made states on TestContent.variety(): wave 1 means "the draft after wave 1"
## (the wave that starts next is 2, so no gap is open yet).

## Three cards that are worth under 2 points (a Scrap card, a reroll card, a Scrap card): the offer a bot rerolls.
const WEAK_OFFER: Array[StringName] = [&"black_box", &"requisition_line", &"scavenger_protocol"]

var w: SimWorld
var bot: PolicyBot


func before_test() -> void:
	w = VarietyHKit.awaiting(PhaseState.Await.DRAFT, 1)
	bot = PolicyBot.new(PolicyBot.Policy.BALANCED)


func _score(id: StringName) -> float:
	return PolicyScoring.score(w, w.content.directive_index(id))


func _only() -> SimCommand:
	assert_int(w.command_queue.size()).is_equal(1)
	return w.command_queue[0]


# --- the score ---


func test_rarity_is_worth_one_point_per_step() -> void:
	assert_float(_score(&"hot_loads")).is_equal(0.0)  # common
	assert_float(_score(&"incendiary_tips")).is_equal(1.0)  # rare
	assert_float(_score(&"glass_cannon")).is_equal(3.0)  # corrupted, the core is whole


func test_a_tag_shared_with_two_held_stacks_adds_three() -> void:
	VarietyHKit.hold(w, &"hot_loads", 1)
	assert_float(_score(&"cyclic_tuning")).is_equal(0.0)  # one stack is not enough
	VarietyHKit.hold(w, &"hot_loads", 2)
	assert_float(_score(&"cyclic_tuning")).is_equal(3.0)  # bullet
	assert_float(_score(&"incendiary_tips")).is_equal(4.0)  # rare 1 + bullet 3
	assert_float(_score(&"reinforced_cage")).is_equal(0.0)  # fortress is not held


func test_two_different_directives_with_a_common_tag_count_together() -> void:
	VarietyHKit.hold(w, &"hot_loads", 1)
	VarietyHKit.hold(w, &"cyclic_tuning", 1)
	assert_float(_score(&"penetrator_cores")).is_equal(3.0)


func test_no_area_source_by_wave_four_makes_blast_and_arc_cards_worth_two_more() -> void:
	w.wave = 2  # the wave that starts next is 3: no gap yet
	assert_float(_score(&"incendiary_tips")).is_equal(1.0)
	w.wave = 3  # next is 4
	assert_float(_score(&"incendiary_tips")).is_equal(3.0)
	assert_float(_score(&"emp_capacitor")).is_equal(2.0)  # arc
	assert_float(_score(&"hot_loads")).is_equal(0.0)


func test_an_area_weapon_or_an_area_directive_closes_the_area_gap() -> void:
	w.wave = 3
	VarietyHKit.carry(w, 1, &"scattergun")
	assert_float(_score(&"incendiary_tips")).is_equal(1.0)
	VarietyHKit.carry(w, 1, &"smg")
	assert_float(_score(&"emp_capacitor")).is_equal(2.0)
	VarietyHKit.hold(w, &"emp_capacitor", 1)  # an arc directive is an area source
	assert_float(_score(&"incendiary_tips")).is_equal(1.0)


func test_no_armor_answer_by_wave_six_makes_penetrator_cores_worth_two_more() -> void:
	w.wave = 4
	assert_float(_score(&"penetrator_cores")).is_equal(0.0)
	w.wave = 5
	assert_float(_score(&"penetrator_cores")).is_equal(2.0)
	VarietyHKit.carry(w, 1, &"rail_lance")  # armor_ignore
	assert_float(_score(&"penetrator_cores")).is_equal(0.0)


func test_no_turret_by_wave_three_makes_a_turret_card_worth_two_more() -> void:
	w.wave = 1
	assert_float(_score(&"turret_deploy")).is_equal(0.0)
	w.wave = 2
	assert_float(_score(&"turret_deploy")).is_equal(2.0)
	w.mods.turrets = 1.0
	assert_float(_score(&"turret_deploy")).is_equal(0.0)
	w.mods.turrets = 0.0
	w.turrets.active[0] = 1
	assert_float(_score(&"turret_deploy")).is_equal(0.0)


func test_a_hurt_core_wants_a_core_directive() -> void:
	assert_float(_score(&"reinforced_cage")).is_equal(0.0)
	w.set_core_hp(w.core_max_hp * 0.59)
	assert_float(_score(&"reinforced_cage")).is_equal(2.0)
	assert_float(_score(&"hot_loads")).is_equal(0.0)


func test_a_corrupted_card_costs_four_while_the_core_is_below_half() -> void:
	w.set_core_hp(w.core_max_hp * 0.5)
	assert_float(_score(&"glass_cannon")).is_equal(3.0)
	w.set_core_hp(w.core_max_hp * 0.49)
	assert_float(_score(&"glass_cannon")).is_equal(-1.0)


# --- the pick ---


func test_the_best_score_wins_whatever_its_slot() -> void:
	VarietyHKit.hold(w, &"hot_loads", 2)
	VarietyHKit.offer(w, [&"reinforced_cage", &"emp_capacitor", &"incendiary_tips"])
	assert_int(PolicyScoring.best_slot(w)).is_equal(2)
	bot.act(w)
	var cmd: SimCommand = _only()
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)
	assert_int(cmd.arg).is_equal(2)


func test_the_best_worth_wins_and_equal_worth_goes_leftmost() -> void:
	VarietyHKit.offer(w, [&"reinforced_cage", &"emp_capacitor", &"hot_loads"])  # worth 1.5, 0.45, 2.0
	assert_int(PolicyScoring.best_slot(w)).is_equal(2)  # the damage level
	VarietyHKit.offer(w, [&"hot_loads", &"hot_loads", &"cyclic_tuning"])  # the same card twice is a tie
	assert_int(PolicyScoring.best_slot(w)).is_equal(0)  # leftmost
	assert_float(PolicyScoring.worth(w, w.content.directive_index(&"hot_loads"))).is_equal_approx(2.0, 0.001)


func test_what_a_card_does_decides_between_two_cards_the_spec_scores_alike() -> void:
	# Spec score 0 for all three; the effects tell a damage level from a Scrap card in a run with no shop.
	VarietyHKit.offer(w, [&"scavenger_protocol", &"black_box", &"hot_loads"])
	assert_int(PolicyScoring.best_slot(w)).is_equal(2)
	assert_float(PolicyScoring.score(w, w.content.directive_index(&"scavenger_protocol"))).is_equal(0.0)


func test_a_taken_slot_is_not_a_candidate() -> void:
	VarietyHKit.offer(w, [&"", &"hot_loads", &""])
	assert_int(PolicyScoring.best_slot(w)).is_equal(1)
	VarietyHKit.offer(w, [&"", &""])
	assert_int(PolicyScoring.best_slot(w)).is_equal(-1)
	bot.act(w)
	assert_int(_only().kind).is_equal(SimCommand.Kind.SKIP_DRAFT)


# --- reroll and patch ---


func test_a_weak_offer_is_rerolled_when_a_free_charge_is_left() -> void:
	VarietyHKit.offer(w, WEAK_OFFER)  # best worth about 0.9
	w.draft.free_rerolls = 1
	bot.act(w)
	assert_int(_only().kind).is_equal(SimCommand.Kind.REROLL)
	assert_int(bot.draft_rerolls).is_equal(1)


func test_a_strong_offer_is_not_rerolled() -> void:
	VarietyHKit.hold(w, &"hot_loads", 2)
	VarietyHKit.offer(w, [&"cyclic_tuning", &"reinforced_cage", &"emp_capacitor"])  # best 3
	w.draft.free_rerolls = 2
	bot.act(w)
	assert_int(_only().kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)


func test_a_paid_reroll_needs_150_scrap_and_the_price() -> void:
	VarietyHKit.offer(w, WEAK_OFFER)
	w.scrap = 149
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 60)).is_false()
	w.scrap = 150
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 60)).is_true()
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 200)).is_false()  # 150 does not cover 200
	w.scrap = 400
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 200)).is_true()
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 0)).is_false()  # price 0 and no free charge: nothing to buy


func test_rerolls_stop_at_three_per_draft_and_never_after_a_pick_or_when_locked() -> void:
	VarietyHKit.offer(w, WEAK_OFFER)
	w.scrap = 900
	bot.draft_rerolls = 2
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 60)).is_true()
	bot.draft_rerolls = 3
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 60)).is_false()
	bot.draft_rerolls = 0
	w.draft.reroll_locked = true
	assert_bool(PolicyBalanced.reroll_pays(w, bot, 60)).is_false()
	w.draft.reroll_locked = false
	w.draft.free_rerolls = 1
	VarietyHKit.offer(w, [&"", &"cyclic_tuning", &"reinforced_cage"])  # the first card of a double pick was taken
	bot.act(w)
	assert_int(_only().kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)


func test_the_reroll_counter_starts_again_with_a_new_offer() -> void:
	bot.note_draft(4)
	bot.draft_rerolls = 3
	bot.note_draft(4)
	assert_int(bot.draft_rerolls).is_equal(3)
	bot.note_draft(5)
	assert_int(bot.draft_rerolls).is_equal(0)


func test_a_hurt_core_is_patched_when_150_scrap_is_left_over() -> void:
	VarietyHKit.hold(w, &"hot_loads", 2)
	VarietyHKit.offer(w, [&"cyclic_tuning", &"reinforced_cage", &"emp_capacitor"])
	w.set_core_hp(w.core_max_hp * 0.5)
	w.scrap = 329
	assert_bool(PolicyBalanced.patch_pays(w, bot, 180)).is_false()
	w.scrap = 330
	assert_bool(PolicyBalanced.patch_pays(w, bot, 180)).is_true()
	bot.draft_patches = 1
	assert_bool(PolicyBalanced.patch_pays(w, bot, 180)).is_false()  # one patch per draft
	bot.draft_patches = 0
	w.set_core_hp(w.core_max_hp * 0.6)
	assert_bool(PolicyBalanced.patch_pays(w, bot, 180)).is_false()  # healthy enough


# --- the route ---


func _opt(pack_id: StringName, reward_id: StringName, hot: bool) -> RouteOption:
	return VarietyHKit.option(w, pack_id, reward_id, hot)


func _route(first: RouteOption, second: RouteOption) -> void:
	var options: Array[RouteOption] = [first, second]
	VarietyHKit.route(w, 3, options)


func test_hot_when_the_core_is_healthy_and_the_reward_is_a_crate() -> void:
	_route(_opt(&"pack_tide", &"rw_scrap", false), _opt(&"pack_powder", &"rw_crate", true))
	assert_int(PolicyScoring.route_choice(w)).is_equal(1)
	bot.act(w)
	var cmd: SimCommand = _only()
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_ROUTE)
	assert_int(cmd.arg).is_equal(1)


func test_a_double_pick_or_a_rare_draft_also_justify_the_hot_route() -> void:
	_route(_opt(&"pack_tide", &"rw_scrap", false), _opt(&"pack_powder", &"rw_double_pick", true))
	assert_int(PolicyScoring.route_choice(w)).is_equal(1)
	_route(_opt(&"pack_tide", &"rw_scrap", false), _opt(&"pack_powder", &"rw_rare_draft", true))
	assert_int(PolicyScoring.route_choice(w)).is_equal(1)


func test_any_other_hot_reward_is_not_worth_it() -> void:
	_route(_opt(&"pack_tide", &"rw_scrap", false), _opt(&"pack_powder", &"rw_data", true))
	assert_int(PolicyScoring.route_choice(w)).is_equal(0)
	_route(_opt(&"pack_tide", &"rw_scrap", false), _opt(&"pack_powder", &"rw_charge", true))
	assert_int(PolicyScoring.route_choice(w)).is_equal(0)


func test_below_seventy_percent_core_takes_the_standard_route() -> void:
	_route(_opt(&"pack_tide", &"rw_scrap", false), _opt(&"pack_powder", &"rw_crate", true))
	w.set_core_hp(w.core_max_hp * 0.69)
	assert_int(PolicyScoring.route_choice(w)).is_equal(0)
	w.set_core_hp(w.core_max_hp * 0.7)
	assert_int(PolicyScoring.route_choice(w)).is_equal(1)


func test_the_standard_option_is_found_wherever_it_stands_and_two_hot_ones_take_a() -> void:
	_route(_opt(&"pack_powder", &"rw_scrap", true), _opt(&"pack_tide", &"rw_scrap", false))
	w.set_core_hp(w.core_max_hp * 0.4)
	assert_int(PolicyScoring.route_choice(w)).is_equal(1)
	_route(_opt(&"pack_powder", &"rw_scrap", true), _opt(&"pack_column", &"rw_scrap", true))
	assert_int(PolicyScoring.route_choice(w)).is_equal(0)
