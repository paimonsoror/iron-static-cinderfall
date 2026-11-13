extends GdUnitTestSuite
## V2-B: how an offer is rolled (VARIETY_SPEC 4.3): candidates, size, duplicates, requirements, the unlocked pool,
## streams and the corrupted slot. The pity and rarity frequencies are in test_draft_rarity.gd.


func _slice_world(wave_number: int = 3, run_seed: int = 1) -> SimWorld:
	return VarietyBKit.world_after(VarietyBKit.slice_content(), wave_number, run_seed)


func _index(w: SimWorld, id: StringName) -> int:
	return w.content.directive_index(id)


func test_an_offer_has_three_distinct_directives() -> void:
	var w: SimWorld = _slice_world()
	var offer: PackedInt32Array = VarietyBKit.offer_n(w, 0)
	assert_int(offer.size()).is_equal(3)
	assert_int(_distinct(offer)).is_equal(3)


func _distinct(offer: PackedInt32Array) -> int:
	var seen: Dictionary[int, bool] = {}
	for index: int in offer:
		seen[index] = true
	return seen.size()


func test_no_duplicate_over_1000_offers_of_a_big_pool() -> void:
	var w: SimWorld = VarietyBKit.world_after(VarietyBKit.big_content(), 6, 3, 2)
	for n: int in 1000:
		var offer: PackedInt32Array = VarietyBKit.offer_n(w, n)
		assert_int(offer.size()).is_equal(3)
		assert_int(_distinct(offer)).override_failure_message("duplicate in offer %d" % n).is_equal(3)


func test_no_duplicate_over_1000_offers_of_the_slice_pool() -> void:
	var w: SimWorld = _slice_world(4, 9)
	for n: int in 1000:
		var offer: PackedInt32Array = VarietyBKit.offer_n(w, n)
		assert_int(_distinct(offer)).override_failure_message("duplicate in offer %d" % n).is_equal(offer.size())


func test_quartermaster_makes_it_four_slots() -> void:
	var w: SimWorld = VarietyBKit.world_after(VarietyBKit.big_content(), 3)
	w.mods.draft_slots = 1.0
	var offer: PackedInt32Array = VarietyBKit.offer_n(w, 0)
	assert_int(offer.size()).is_equal(4)
	assert_int(_distinct(offer)).is_equal(4)


func test_a_pool_smaller_than_the_offer_gives_a_short_offer() -> void:
	var c: ContentSet = VarietyBKit.slice_content()
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	for def: DirectiveDef in c.directives:
		if def.id != &"hot_loads" and def.id != &"cyclic_tuning":
			w.draft.stacks[def.index] = def.max_stacks
	var offer: PackedInt32Array = VarietyBKit.offer_n(w, 0)
	assert_int(offer.size()).is_equal(2)
	assert_int(_distinct(offer)).is_equal(2)


func test_maxed_directives_never_appear() -> void:
	var c: ContentSet = VarietyBKit.slice_content()
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	var maxed: Array[StringName] = [&"hot_loads", &"cyclic_tuning", &"reinforced_cage"]
	for id: StringName in maxed:
		var index: int = _index(w, id)
		w.draft.stacks[index] = c.directives[index].max_stacks
	for n: int in 1000:
		for index: int in VarietyBKit.offer_n(w, n):
			assert_bool(maxed.has(c.directives[index].id)).override_failure_message("maxed directive offered").is_false()
	# one stack short of the maximum is still offered
	w.draft.stacks[_index(w, &"hot_loads")] = 4
	assert_bool(DraftOffer.candidates(w).has(_index(w, &"hot_loads"))).is_true()


func test_the_candidate_list_is_sorted_by_id() -> void:
	var w: SimWorld = _slice_world()
	var ids: Array[String] = []
	for index: int in DraftOffer.candidates(w):
		ids.append(String(w.content.directives[index].id))
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	assert_array(ids).is_equal(sorted_ids)
	assert_int(ids.size()).is_equal(8)


func test_turret_deploy_needs_a_free_pad() -> void:
	var w: SimWorld = _slice_world()
	var turret: int = _index(w, &"turret_deploy")
	assert_bool(DraftOffer.candidates(w).has(turret)).is_true()
	w.turrets.active[0] = 1
	assert_bool(DraftOffer.candidates(w).has(turret)).is_true()
	w.turrets.active[1] = 1
	assert_bool(DraftOffer.candidates(w).has(turret)).is_false()
	assert_int(VarietyBKit.offers_with(w, turret, 300)).is_equal(0)


func test_disabled_pads_close_the_pad_requirement() -> void:
	var w: SimWorld = _slice_world()
	w.mods.set_flag(&"pads_disabled", true)
	assert_bool(DraftOffer.candidates(w).has(_index(w, &"turret_deploy"))).is_false()


func test_requirements_of_turrets_weapons_and_weapon_kind() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	var t: int = VarietyBKit.add_directive(
		c, VarietyBKit.require(VarietyBKit.def(&"n_turret", DirectiveDef.Rarity.COMMON), &"turrets", 1.0)
	)
	var two: int = VarietyBKit.add_directive(
		c, VarietyBKit.require(VarietyBKit.def(&"n_two", DirectiveDef.Rarity.COMMON), &"weapons", 2.0)
	)
	var arc: int = VarietyBKit.add_directive(
		c,
		VarietyBKit.require(
			VarietyBKit.def(&"n_arc", DirectiveDef.Rarity.COMMON), &"weapon_kind", float(WeaponDef.Kind.ARC)
		)
	)
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	var open: Array[int] = DraftOffer.candidates(w)
	assert_bool(open.has(t) or open.has(two) or open.has(arc)).is_false()
	w.turrets.active[0] = 1
	assert_bool(DraftOffer.candidates(w).has(t)).is_true()
	w.arsenal.slot_weapon[1] = Ids.WP_SCATTERGUN
	assert_bool(DraftOffer.candidates(w).has(two)).is_true()
	assert_bool(DraftOffer.candidates(w).has(arc)).is_false()
	w.arsenal.slot_weapon[1] = Ids.WP_ARC_PROJECTOR
	assert_bool(DraftOffer.candidates(w).has(arc)).is_true()


func test_a_requirement_filters_the_offers_too() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	var t: int = VarietyBKit.add_directive(
		c, VarietyBKit.require(VarietyBKit.def(&"n_turret", DirectiveDef.Rarity.COMMON), &"turrets", 1.0)
	)
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	assert_int(VarietyBKit.offers_with(w, t, 400)).is_equal(0)
	w.turrets.active[1] = 1
	assert_int(VarietyBKit.offers_with(w, t, 400)).is_greater(0)


func test_a_pack_directive_needs_its_unlock() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	var locked: DirectiveDef = VarietyBKit.def(&"locked_one", DirectiveDef.Rarity.COMMON)
	locked.pool = &"u_p_test"
	var index: int = VarietyBKit.add_directive(c, locked)
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	assert_bool(DraftOffer.candidates(w).has(index)).is_false()
	w.config.unlocked = PackedStringArray(["u_p_test"])
	assert_bool(DraftOffer.candidates(w).has(index)).is_true()
	w.config.unlocked = PackedStringArray()
	w.config.daily = true
	assert_bool(DraftOffer.candidates(w).has(index)).is_true()


func test_same_seed_same_offers_other_seed_other_offers() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	var a: SimWorld = VarietyBKit.world_after(c, 3, 5)
	var b: SimWorld = VarietyBKit.world_after(c, 3, 5)
	var other: SimWorld = VarietyBKit.world_after(c, 3, 6)
	var differs: int = 0
	for n: int in 50:
		var offer: PackedInt32Array = VarietyBKit.offer_n(a, n)
		assert_array(Array(VarietyBKit.offer_n(b, n))).is_equal(Array(offer))
		if Array(VarietyBKit.offer_n(other, n)) != Array(offer):
			differs += 1
	assert_int(differs).is_greater(40)


## Pinned from the first run of DraftOffer (slice pool, act I, after wave 1, stream `draft:0` of seed 1): a change here
## means the draw sequence of VARIETY_SPEC 4.3 changed, which changes every recorded run.
func test_golden_first_offer_of_seed_1() -> void:
	var c: ContentSet = VarietyBKit.slice_content()
	var w: SimWorld = VarietyBKit.world_after(c, 1, 1)
	DraftSystem.open(w)
	assert_array(VarietyBKit.ids(c, w.draft.offer)).is_equal([&"cyclic_tuning", &"hot_loads", &"emp_capacitor"])


func test_offer_n_depends_on_its_own_stream_only() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	var fresh: SimWorld = VarietyBKit.world_after(c, 3, 8)
	var used: SimWorld = VarietyBKit.world_after(c, 3, 8)
	for n: int in 5:
		var _earlier: PackedInt32Array = VarietyBKit.offer_n(used, n)
	var _spawn_roll: float = used.rng.stream(&"spawn").randf()
	var _proc_roll: float = used.rng.stream(&"proc").randf()
	assert_array(Array(VarietyBKit.offer_n(used, 5))).is_equal(Array(VarietyBKit.offer_n(fresh, 5)))


func test_open_counts_offers_and_pushes_the_event() -> void:
	var c: ContentSet = VarietyBKit.slice_content()
	var w: SimWorld = VarietyBKit.draft_world(c, 3)
	assert_int(w.draft.offer_ordinal).is_equal(1)
	assert_bool(w.draft.open).is_true()
	var offered: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.DRAFT_OFFERED)
	assert_int(offered.size()).is_equal(1)
	assert_int(offered[0].a).is_equal(0)
	assert_int(offered[0].b).is_equal(3)
	assert_array(Array(w.draft.offer)).is_equal(Array(VarietyBKit.offer_n(VarietyBKit.world_after(c, 3), 0)))


func test_a_legacy_world_has_no_drafts() -> void:
	var w: SimWorld = TestContent.world(1)
	DraftSystem.open(w)
	assert_bool(w.draft.open).is_false()
	assert_int(w.draft.offer_ordinal).is_equal(0)
	assert_int(DraftSystem.generate_offer(w).size()).is_equal(0)


func test_no_corrupted_directive_in_the_offers_of_waves_one_and_two() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	c.run.acts[0].corrupted_chance = 1.0
	for wave_number: int in range(1, 3):
		var w: SimWorld = VarietyBKit.world_after(c, wave_number)
		for n: int in 300:
			for index: int in VarietyBKit.offer_n(w, n):
				assert_int(c.directives[index].rarity).is_not_equal(DirectiveDef.Rarity.CORRUPTED)


func test_a_corrupted_directive_takes_the_last_slot_at_most_once() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	c.run.acts[0].corrupted_chance = 1.0
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	for n: int in 300:
		var offer: PackedInt32Array = VarietyBKit.offer_n(w, n)
		assert_int(offer.size()).is_equal(3)
		assert_int(c.directives[offer[2]].rarity).is_equal(DirectiveDef.Rarity.CORRUPTED)
		assert_int(c.directives[offer[0]].rarity).is_not_equal(DirectiveDef.Rarity.CORRUPTED)
		assert_int(c.directives[offer[1]].rarity).is_not_equal(DirectiveDef.Rarity.CORRUPTED)


func test_the_corrupted_chance_is_the_chance_of_the_act() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	var w: SimWorld = VarietyBKit.world_after(c, 8, 4, 3)  # act III: 25%
	var hits: int = 0
	for n: int in 4000:
		for index: int in VarietyBKit.offer_n(w, n):
			if c.directives[index].rarity == DirectiveDef.Rarity.CORRUPTED:
				hits += 1
	assert_float(float(hits) / 4000.0).is_equal_approx(0.25, 0.03)


func test_a_world_without_corrupted_candidates_just_keeps_its_offer() -> void:
	var c: ContentSet = VarietyBKit.big_content()
	c.run.acts[0].corrupted_chance = 1.0
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	for index: int in c.directives.size():
		if c.directives[index].rarity == DirectiveDef.Rarity.CORRUPTED:
			w.draft.stacks[index] = c.directives[index].max_stacks
	var offer: PackedInt32Array = VarietyBKit.offer_n(w, 0)
	assert_int(offer.size()).is_equal(3)
	for index: int in offer:
		assert_int(c.directives[index].rarity).is_not_equal(DirectiveDef.Rarity.CORRUPTED)
