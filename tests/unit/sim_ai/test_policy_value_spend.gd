extends GdUnitTestSuite
## V4-T: what `balanced` thinks a card is worth (PolicyValue: the points of its effects, read from the data), what it does
## with Scrap that has no other use (PolicySpend: buy a second card, patch the core) and that a hook directive's counter is
## never read as stacks. Hand-made states on TestContent.variety().

var w: SimWorld
var bot: PolicyBot


func before_test() -> void:
	w = VarietyHKit.awaiting(PhaseState.Await.DRAFT, 4)  # the draft before wave 5, the last of the slice run
	bot = PolicyBot.new(PolicyBot.Policy.BALANCED)


func _value(id: StringName) -> float:
	return PolicyValue.of(w, w.content.directive(id))


func _only() -> SimCommand:
	assert_int(w.command_queue.size()).is_equal(1)
	return w.command_queue[0]


# --- the value of a card ---


func test_a_damage_level_is_two_points_and_the_other_stat_cards_follow() -> void:
	assert_float(_value(&"hot_loads")).is_equal_approx(2.0, 0.001)  # lvl_damage +1
	assert_float(_value(&"cyclic_tuning")).is_equal_approx(1.5, 0.001)  # lvl_fire_rate +1
	assert_float(_value(&"penetrator_cores")).is_equal_approx(1.0, 0.001)
	assert_float(_value(&"emp_capacitor")).is_equal_approx(0.45, 0.001)  # a shorter EMP cooldown
	assert_float(_value(&"incendiary_tips")).is_equal_approx(2.0, 0.001)  # burn 8 per second


func test_a_hook_directive_is_worth_the_default_of_its_category_when_it_has_no_ops() -> void:
	var def: DirectiveDef = DirectiveDef.new()
	def.index = 0
	def.max_stacks = 1
	def.category = DirectiveDef.Category.WEAPON
	assert_float(PolicyValue.of(w, def)).is_equal(PolicyValue.HOOK_DEFAULT[DirectiveDef.Category.WEAPON])
	def.category = DirectiveDef.Category.ECONOMY
	assert_float(PolicyValue.of(w, def)).is_equal(PolicyValue.HOOK_DEFAULT[DirectiveDef.Category.ECONOMY])


func test_each_stack_held_is_worth_less_than_the_one_before() -> void:
	var first: float = _value(&"hot_loads")
	VarietyHKit.hold(w, &"hot_loads", 1)
	assert_float(_value(&"hot_loads")).is_equal_approx(first * PolicyValue.STACK_DECAY, 0.001)
	VarietyHKit.hold(w, &"hot_loads", 3)
	assert_float(_value(&"hot_loads")).is_equal_approx(first * pow(PolicyValue.STACK_DECAY, 3.0), 0.001)


func test_a_turret_card_is_worth_four_and_a_turret_upgrade_waits_for_a_turret() -> void:
	assert_float(_value(&"turret_deploy")).is_equal_approx(4.0, 0.001)
	var upgrade: OpDef = OpDef.new()
	upgrade.kind = OpDef.Kind.ADD
	upgrade.target = &"t_dmg_mul"
	upgrade.value = 0.3
	var without: float = PolicyValue.op_value(w, upgrade)
	w.mods.turrets = 1.0
	assert_float(PolicyValue.op_value(w, upgrade)).is_equal_approx(without / PolicyValue.NO_TURRET_FACTOR, 0.001)


func test_a_repair_is_worth_what_it_restores() -> void:
	assert_float(_value(&"reinforced_cage")).is_equal_approx(1.5, 0.001)  # +150 core, nothing to repair at full
	w.set_core_hp(w.core_max_hp * 0.5)
	assert_float(_value(&"reinforced_cage")).is_equal_approx(3.0, 0.001)  # and 150 of the 500 missing


func test_glass_cannon_trades_damage_for_core_and_the_value_is_capped() -> void:
	assert_float(_value(&"glass_cannon")).is_equal_approx(5.0, 0.001)  # +80% damage (8) against -30% core (-3)
	var big: DirectiveDef = DirectiveDef.new()
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.ADD
	op.target = &"w_dmg_mul"
	op.value = 5.0
	big.ops = [op]
	big.max_stacks = 1
	assert_float(PolicyValue.of(w, big)).is_equal(PolicyValue.MAX_VALUE)


func test_a_card_that_does_nothing_for_this_run_loses_to_a_damage_level() -> void:
	VarietyHKit.offer(w, [&"scavenger_protocol", &"hot_loads", &"black_box"])
	assert_int(PolicyScoring.best_slot(w)).is_equal(1)


# --- a hook directive's counter is not a stack ---


func test_the_stacks_of_a_directive_never_exceed_its_maximum() -> void:
	var cannon: DirectiveDef = w.content.directive(&"glass_cannon")  # max 1
	w.draft.stacks[cannon.index] = 7  # HookMemory keeps counters in the stack count
	assert_int(PolicySenses.stacks_of(w, cannon)).is_equal(1)
	assert_int(PolicyScoring.shared_stacks(w, cannon)).is_equal(1)
	var tags: PackedStringArray = BuildSignature.top_tags(w)
	assert_array(Array(tags)).contains(["bullet"])
	w.draft.stacks[cannon.index] = 0
	assert_int(PolicySenses.stacks_of(w, cannon)).is_equal(0)


# --- spending Scrap ---


func _open(ids: Array[StringName], scrap: int, core_fraction: float = 1.0) -> void:
	VarietyHKit.offer(w, ids)
	w.scrap = scrap
	w.set_core_hp(w.core_max_hp * core_fraction)


func test_the_last_draft_before_the_final_wave_is_known() -> void:
	assert_bool(PolicySpend.is_last_draft(w)).is_true()
	w.wave = 2
	assert_bool(PolicySpend.is_last_draft(w)).is_false()
	assert_int(PolicySpend.reserve(w)).is_equal(PolicySpend.MID_RESERVE)
	w.wave = 4
	assert_int(PolicySpend.spare(w)).is_equal(w.scrap)


func test_a_second_card_is_bought_with_scrap_that_has_no_other_use() -> void:
	_open([&"hot_loads", &"cyclic_tuning", &"penetrator_cores"], 249)
	assert_bool(PolicySpend.wants_buyout(w)).is_false()  # the buy-out costs 250
	w.scrap = 250
	assert_bool(PolicySpend.wants_buyout(w)).is_true()
	bot.act(w)
	var cmd: SimCommand = _only()
	assert_int(cmd.kind).is_equal(SimCommand.Kind.BUY_OUT)
	assert_int(cmd.arg).is_equal(0)  # the best card, hot_loads


func test_before_the_last_draft_a_reserve_of_150_is_kept() -> void:
	w.wave = 2
	_open([&"hot_loads", &"cyclic_tuning", &"penetrator_cores"], 399)
	assert_bool(PolicySpend.wants_buyout(w)).is_false()
	w.scrap = 400
	assert_bool(PolicySpend.wants_buyout(w)).is_true()


func test_a_card_not_worth_having_is_not_bought_and_nothing_is_bought_twice() -> void:
	_open([&"hot_loads", &"black_box", &"scavenger_protocol"], 900)  # the second best is worth under 1.5
	assert_bool(PolicySpend.wants_buyout(w)).is_false()
	_open([&"hot_loads", &"cyclic_tuning", &"penetrator_cores"], 900)
	w.draft.bought_out = true
	assert_bool(PolicySpend.wants_buyout(w)).is_false()
	w.draft.bought_out = false
	VarietyHKit.offer(w, [&"", &"cyclic_tuning", &"penetrator_cores"])  # a card was already taken
	assert_bool(PolicySpend.wants_buyout(w)).is_false()


func test_a_wounded_core_is_patched_with_spare_scrap_up_to_three_times_a_draft() -> void:
	_open([&"hot_loads", &"cyclic_tuning", &"penetrator_cores"], 180, 0.8)
	assert_bool(PolicySpend.wants_patch(w, bot)).is_true()
	w.scrap = 179
	assert_bool(PolicySpend.wants_patch(w, bot)).is_false()
	w.scrap = 900
	w.set_core_hp(w.core_max_hp * 0.95)
	assert_bool(PolicySpend.wants_patch(w, bot)).is_false()  # healthy enough
	w.set_core_hp(w.core_max_hp * 0.8)
	bot.draft_patches = 3
	assert_bool(PolicySpend.wants_patch(w, bot)).is_false()
	bot.draft_patches = 0
	w.draft.reroll_locked = true
	assert_bool(PolicySpend.wants_patch(w, bot)).is_false()  # no breather: no patch


func test_the_draft_buys_then_patches_then_picks() -> void:
	_open([&"hot_loads", &"cyclic_tuning", &"penetrator_cores"], 900, 0.8)
	bot.act(w)
	assert_int(_only().kind).is_equal(SimCommand.Kind.BUY_OUT)
	w.command_queue.clear()
	w.draft.bought_out = true  # the sim has taken the card
	w.draft.offer[0] = -1
	bot.act(w)
	assert_int(_only().kind).is_equal(SimCommand.Kind.PATCH_CORE)
	w.command_queue.clear()
	bot.draft_patches = PolicySpend.MAX_PATCHES
	bot.act(w)
	var cmd: SimCommand = _only()
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PICK_DIRECTIVE)
	assert_int(cmd.arg).is_equal(1)
