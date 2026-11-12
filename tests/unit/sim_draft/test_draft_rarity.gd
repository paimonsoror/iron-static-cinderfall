extends GdUnitTestSuite
## V2-B: rarity rolls, the rare pity, rw_rare_draft, the first-turret pity and the prototype lean after a boss
## (VARIETY_SPEC 4.3, CONTENT 1.1 and 3.7).


## The big pool with no pity, no corrupted slot and the weights of the act row `act` (1 to 3) as in CONTENT 1.1.
func _freq_content() -> ContentSet:
	var c: ContentSet = VarietyBKit.big_content()
	c.run.rare_pity = 0
	for a: ActDef in c.run.acts:
		a.corrupted_chance = 0.0
	return c


func _share(w: SimWorld, c: ContentSet, offers: int) -> Array[float]:
	var counts: Array[float] = [0.0, 0.0, 0.0]
	for n: int in offers:
		for index: int in VarietyBKit.offer_n(w, n):
			counts[c.directives[index].rarity] += 1.0
	var total: float = counts[0] + counts[1] + counts[2]
	var out: Array[float] = [counts[0] / total, counts[1] / total, counts[2] / total]
	return out


func test_rarity_frequencies_follow_the_weights_of_act_one() -> void:
	var c: ContentSet = _freq_content()
	var got: Array[float] = _share(VarietyBKit.world_after(c, 6, 11, 1), c, 5000)
	assert_float(got[0]).is_equal_approx(0.70, 0.03)
	assert_float(got[1]).is_equal_approx(0.26, 0.03)
	assert_float(got[2]).is_equal_approx(0.04, 0.03)


func test_rarity_frequencies_follow_the_weights_of_act_two() -> void:
	var c: ContentSet = _freq_content()
	var got: Array[float] = _share(VarietyBKit.world_after(c, 7, 12, 2), c, 5000)
	assert_float(got[0]).is_equal_approx(0.55, 0.03)
	assert_float(got[1]).is_equal_approx(0.35, 0.03)
	assert_float(got[2]).is_equal_approx(0.10, 0.03)


func test_rarity_frequencies_follow_the_weights_of_act_three() -> void:
	var c: ContentSet = _freq_content()
	var got: Array[float] = _share(VarietyBKit.world_after(c, 12, 13, 3), c, 5000)
	assert_float(got[0]).is_equal_approx(0.40, 0.03)
	assert_float(got[1]).is_equal_approx(0.42, 0.03)
	assert_float(got[2]).is_equal_approx(0.18, 0.03)


func test_an_empty_rarity_falls_to_the_next_lower_then_the_higher() -> void:
	var c: ContentSet = _freq_content()
	c.run.acts[0].rarity_weights = PackedFloat32Array([0.0, 0.0, 100.0])  # prototypes only
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	for index: int in c.directives.size():
		if c.directives[index].rarity == DirectiveDef.Rarity.PROTOTYPE:
			w.draft.stacks[index] = c.directives[index].max_stacks  # none left
	var lower: PackedInt32Array = VarietyBKit.offer_n(w, 0)
	assert_int(lower.size()).is_equal(3)
	for index: int in lower:
		assert_int(c.directives[index].rarity).is_equal(DirectiveDef.Rarity.RARE)  # next lower
	for index: int in c.directives.size():
		if c.directives[index].rarity == DirectiveDef.Rarity.RARE:
			w.draft.stacks[index] = c.directives[index].max_stacks
	for index: int in VarietyBKit.offer_n(w, 1):
		assert_int(c.directives[index].rarity).is_equal(DirectiveDef.Rarity.COMMON)
	c.run.acts[0].rarity_weights = PackedFloat32Array([100.0, 0.0, 0.0])
	var w2: SimWorld = VarietyBKit.world_after(c, 3)
	for index: int in c.directives.size():
		if c.directives[index].rarity == DirectiveDef.Rarity.COMMON:
			w2.draft.stacks[index] = c.directives[index].max_stacks
	for index: int in VarietyBKit.offer_n(w2, 0):
		assert_int(c.directives[index].rarity).is_equal(DirectiveDef.Rarity.RARE)  # none lower: the next higher


## Offers of a slice world with only commons rolled (rarity weights 100/0/0), at wave 1 (no turret pity).
func _commons_only_world() -> SimWorld:
	var c: ContentSet = TestContent.variety()
	c.run.acts[0].rarity_weights = PackedFloat32Array([100.0, 0.0, 0.0])
	return VarietyBKit.world_after(c, 1)


## Opens a draft on `w`, returns its offer and skips it (the next draft then starts from the counters left behind).
func _cycle(w: SimWorld) -> PackedInt32Array:
	w.phase_state.awaiting = PhaseState.Await.DRAFT
	DraftSystem.open(w)
	var offer: PackedInt32Array = w.draft.offer.duplicate()
	assert_int(DraftSystem.skip(w, 0)).is_equal(Reason.Id.OK)
	return offer


func _has_rare(c: ContentSet, offer: PackedInt32Array) -> bool:
	for index: int in offer:
		if c.directives[index].rarity == DirectiveDef.Rarity.RARE:
			return true
	return false


func test_rare_pity_fires_on_the_fourth_offer() -> void:
	var w: SimWorld = _commons_only_world()
	var rare: int = w.content.directive_index(&"incendiary_tips")
	for n: int in 3:
		var offer: PackedInt32Array = _cycle(w)
		assert_bool(_has_rare(w.content, offer)).override_failure_message("offer %d" % (n + 1)).is_false()
		assert_int(w.draft.offers_without_rare).is_equal(n + 1)
	var fourth: PackedInt32Array = _cycle(w)
	assert_int(fourth[0]).is_equal(rare)  # slot 1 is rare or better
	assert_int(fourth.size()).is_equal(3)


func test_the_pity_counter_starts_again_after_a_rare() -> void:
	var w: SimWorld = _commons_only_world()
	for _n: int in 4:
		var _offer: PackedInt32Array = _cycle(w)
	assert_int(w.draft.offers_without_rare).is_equal(0)
	var fifth: PackedInt32Array = _cycle(w)
	assert_bool(_has_rare(w.content, fifth)).is_false()
	assert_int(w.draft.offers_without_rare).is_equal(1)


func test_the_rare_pity_forces_slot_one_only() -> void:
	var w: SimWorld = _commons_only_world()
	w.draft.offers_without_rare = 3
	var offer: PackedInt32Array = _cycle(w)
	assert_int(w.content.directives[offer[0]].rarity).is_equal(DirectiveDef.Rarity.RARE)
	assert_int(w.content.directives[offer[1]].rarity).is_equal(DirectiveDef.Rarity.COMMON)
	assert_int(w.content.directives[offer[2]].rarity).is_equal(DirectiveDef.Rarity.COMMON)


func test_the_rare_pity_waits_when_no_rare_is_left() -> void:
	var w: SimWorld = _commons_only_world()
	var rare: int = w.content.directive_index(&"incendiary_tips")
	w.draft.stacks[rare] = w.content.directives[rare].max_stacks
	w.draft.offers_without_rare = 5
	var offer: PackedInt32Array = _cycle(w)
	assert_int(offer.size()).is_equal(3)
	assert_int(w.draft.offers_without_rare).is_equal(6)  # still owed


func test_a_rerolled_offer_counts_for_the_pity_too() -> void:
	var w: SimWorld = _commons_only_world()
	w.draft.free_rerolls = 3
	w.phase_state.awaiting = PhaseState.Await.DRAFT
	DraftSystem.open(w)
	assert_int(w.draft.offers_without_rare).is_equal(1)
	var want: Array[int] = [2, 3, 0]  # the third reroll is owed a rare, which resets the counter
	for n: int in 3:
		assert_int(DraftSystem.reroll(w, 0)).is_equal(Reason.Id.OK)
		assert_int(w.draft.offers_without_rare).is_equal(want[n])


func test_rw_rare_draft_makes_slot_one_rare_once() -> void:
	var w: SimWorld = _commons_only_world()
	DraftSystem.arm_next_rare(w)
	var first: PackedInt32Array = _cycle(w)
	assert_int(w.content.directives[first[0]].rarity).is_equal(DirectiveDef.Rarity.RARE)
	assert_bool(w.draft.next_rare).is_false()
	var second: PackedInt32Array = _cycle(w)
	assert_bool(_has_rare(w.content, second)).is_false()


func test_the_route_reward_arms_the_next_draft() -> void:
	var w: SimWorld = _commons_only_world()
	ModSystem.apply_reward(w, w.content.run.reward_index(&"rw_rare_draft"))
	assert_bool(w.draft.next_rare).is_true()
	assert_bool(w.mods.has_flag(&"next_draft_rare")).is_true()
	ModSystem.apply_reward(w, w.content.run.reward_index(&"rw_double_pick"))
	assert_bool(w.draft.next_double).is_true()
	assert_int(w.content.run.reward_index(&"rw_scrap")).is_greater_equal(0)


func test_prototype_weight_triples_after_a_boss_wave() -> void:
	var c: ContentSet = _freq_content()
	var normal: Array[float] = _share(VarietyBKit.world_after(c, 4, 21, 1), c, 4000)
	var boss: SimWorld = VarietyBKit.world_after(c, 5, 21, 1)
	boss.plan.waves[4].is_boss = true
	var lean: Array[float] = _share(boss, c, 4000)
	assert_float(normal[2]).is_equal_approx(0.04, 0.02)
	assert_float(lean[2]).is_equal_approx(12.0 / 108.0, 0.025)  # 70 / 26 / 4 x 3
	assert_float(lean[2]).is_greater(normal[2] + 0.04)


func test_the_first_turret_is_offered_in_slot_one_after_wave_two() -> void:
	var c: ContentSet = TestContent.variety()
	var turret: int = c.directive_index(&"turret_deploy")
	for run_seed: int in range(1, 31):
		var w: SimWorld = VarietyBKit.world_after(c, 2, run_seed)
		assert_int(VarietyBKit.offer_n(w, 0)[0]).override_failure_message("seed %d" % run_seed).is_equal(turret)
		assert_int(_distinct(VarietyBKit.offer_n(w, 0))).is_equal(3)


func _distinct(offer: PackedInt32Array) -> int:
	var seen: Dictionary[int, bool] = {}
	for index: int in offer:
		seen[index] = true
	return seen.size()


func test_there_is_no_turret_pity_after_wave_one() -> void:
	var c: ContentSet = TestContent.variety()
	var turret: int = c.directive_index(&"turret_deploy")
	var first: int = 0
	for run_seed: int in range(1, 31):
		if VarietyBKit.offer_n(VarietyBKit.world_after(c, 1, run_seed), 0)[0] == turret:
			first += 1
	assert_int(first).is_less(10)


func test_the_turret_pity_stops_once_it_was_offered_or_a_turret_stands() -> void:
	var c: ContentSet = TestContent.variety()
	var turret: int = c.directive_index(&"turret_deploy")
	var offered: int = 0
	var standing: int = 0
	var signal_kit: int = 0
	for run_seed: int in range(1, 31):
		var a: SimWorld = VarietyBKit.world_after(c, 3, run_seed)
		a.draft.turret_offered = true
		if VarietyBKit.offer_n(a, 0)[0] == turret:
			offered += 1
		var b: SimWorld = VarietyBKit.world_after(c, 3, run_seed)
		b.turrets.active[0] = 1
		if VarietyBKit.offer_n(b, 0)[0] == turret:
			standing += 1
		var d: SimWorld = VarietyBKit.world_after(c, 3, run_seed)
		d.mods.set_flag(&"no_turret_pity", true)
		if VarietyBKit.offer_n(d, 0)[0] == turret:
			signal_kit += 1
	assert_int(offered).is_less(10)
	assert_int(standing).is_less(10)
	assert_int(signal_kit).is_less(10)


func test_open_remembers_that_the_turret_was_offered() -> void:
	var c: ContentSet = TestContent.variety()
	var w: SimWorld = VarietyBKit.world_after(c, 2)
	assert_bool(w.draft.turret_offered).is_false()
	DraftSystem.open(w)
	assert_bool(w.draft.turret_offered).is_true()
	assert_bool(w.draft.offer.has(c.directive_index(&"turret_deploy"))).is_true()


func test_the_turret_pity_takes_slot_one_and_the_rare_pity_slot_two() -> void:
	var c: ContentSet = TestContent.variety()
	c.run.acts[0].rarity_weights = PackedFloat32Array([100.0, 0.0, 0.0])
	var w: SimWorld = VarietyBKit.world_after(c, 2)
	w.draft.offers_without_rare = 3
	var offer: PackedInt32Array = VarietyBKit.offer_n(w, 0)
	assert_int(offer[0]).is_equal(c.directive_index(&"turret_deploy"))
	assert_int(offer[1]).is_equal(c.directive_index(&"incendiary_tips"))
	assert_int(c.directives[offer[2]].rarity).is_equal(DirectiveDef.Rarity.COMMON)


func test_a_world_after_a_boss_without_a_plan_wave_just_rolls() -> void:
	var c: ContentSet = _freq_content()
	var w: SimWorld = VarietyBKit.world_after(c, 40)  # past the plan: no PlannedWave, no lean, no error
	assert_int(VarietyBKit.offer_n(w, 0).size()).is_equal(3)
