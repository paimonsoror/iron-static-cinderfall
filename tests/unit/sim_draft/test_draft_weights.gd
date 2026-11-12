extends GdUnitTestSuite
## V2-B: the weights inside a rarity (CONTENT 3.7): the tag lean x2, the weapon lean x1.5, the repeat penalty x0.5,
## and the build chips (DraftSystem.build_tags).


## 14 commons only: c00..c06 tagged alpha, c07..c13 tagged beta, a 3-slot offer, nothing else going on.
func _tagged() -> ContentSet:
	var c: ContentSet = VarietyBKit.big_content()
	c.run.rare_pity = 0
	for a: ActDef in c.run.acts:
		a.corrupted_chance = 0.0
		a.rarity_weights = PackedFloat32Array([100.0, 0.0, 0.0])
	for i: int in 14:
		var t: Array[StringName] = []
		t.append(&"alpha" if i < 7 else &"beta")
		c.directives[i].tags = t
	return c


## The share of the picks of the first `count` offers that were tagged alpha.
func _alpha_share(w: SimWorld, count: int) -> float:
	var alpha: int = 0
	var all: int = 0
	for n: int in count:
		for index: int in VarietyBKit.offer_n(w, n):
			all += 1
			if w.content.directives[index].tags.has(&"alpha"):
				alpha += 1
	return float(alpha) / float(all)


func test_without_a_build_the_tags_are_even() -> void:
	var w: SimWorld = VarietyBKit.world_after(_tagged(), 6)
	assert_float(_alpha_share(w, 3000)).is_equal_approx(0.5, 0.03)


func test_two_held_stacks_of_a_tag_lean_the_offers_toward_it() -> void:
	var w: SimWorld = VarietyBKit.world_after(_tagged(), 6)
	w.draft.stacks[0] = 2  # c00, alpha
	var leaning: float = _alpha_share(w, 3000)
	assert_float(leaning).is_greater(0.6)
	var b: SimWorld = VarietyBKit.world_after(_tagged(), 6)
	b.draft.stacks[10] = 2  # c10, beta
	assert_float(_alpha_share(b, 3000)).is_less(0.4)


func test_one_stack_does_not_lean() -> void:
	var w: SimWorld = VarietyBKit.world_after(_tagged(), 6)
	w.draft.stacks[0] = 1
	assert_float(_alpha_share(w, 3000)).is_equal_approx(0.5, 0.03)


func test_two_different_directives_of_one_tag_lean_as_well() -> void:
	var w: SimWorld = VarietyBKit.world_after(_tagged(), 6)
	w.draft.stacks[0] = 1
	w.draft.stacks[1] = 1
	assert_float(_alpha_share(w, 3000)).is_greater(0.6)


func test_the_weight_numbers() -> void:
	var c: ContentSet = TestContent.variety()
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	var hot: DirectiveDef = c.directive(&"hot_loads")
	var tags: Dictionary[StringName, int] = DraftSystem.build_tags(w)
	assert_float(DraftOffer.weight_of(w, hot, tags)).is_equal(10.0)
	w.draft.stacks[hot.index] = 2
	assert_float(DraftOffer.weight_of(w, hot, DraftSystem.build_tags(w))).is_equal(20.0)  # bullet x2
	w.draft.last_offer = PackedInt32Array([hot.index])
	assert_float(DraftOffer.weight_of(w, hot, DraftSystem.build_tags(w))).is_equal(10.0)  # x2 then x0.5
	var cage: DirectiveDef = c.directive(&"reinforced_cage")
	assert_float(DraftOffer.weight_of(w, cage, DraftSystem.build_tags(w))).is_equal(10.0)


func test_a_directive_for_a_carried_weapon_kind_weighs_more() -> void:
	var c: ContentSet = _tagged()
	var kind_index: int = VarietyBKit.add_directive(
		c, VarietyBKit.require(VarietyBKit.def(&"w00", DirectiveDef.Rarity.COMMON), &"weapon_kind", float(WeaponDef.Kind.HITSCAN))
	)
	var w: SimWorld = VarietyBKit.world_after(c, 6)
	var plain: int = VarietyBKit.offers_with(w, 3, 3000)
	var kind: int = VarietyBKit.offers_with(w, kind_index, 3000)
	assert_float(float(kind) / float(plain)).is_greater(1.25)
	var no_tags: Dictionary[StringName, int] = {}
	assert_float(DraftOffer.weight_of(w, c.directives[kind_index], no_tags)).is_equal(15.0)


func test_a_directive_for_a_weapon_that_is_not_carried_is_not_offered() -> void:
	var c: ContentSet = _tagged()
	var kind_index: int = VarietyBKit.add_directive(
		c, VarietyBKit.require(VarietyBKit.def(&"w00", DirectiveDef.Rarity.COMMON), &"weapon_kind", float(WeaponDef.Kind.BEAM))
	)
	var w: SimWorld = VarietyBKit.world_after(c, 6)
	assert_int(VarietyBKit.offers_with(w, kind_index, 300)).is_equal(0)


func test_what_was_offered_and_not_picked_is_offered_less_often() -> void:
	var w: SimWorld = VarietyBKit.world_after(_tagged(), 6)
	var rested: int = VarietyBKit.offers_with(w, 0, 3000)
	w.draft.last_offer = PackedInt32Array([0])
	var penalised: int = VarietyBKit.offers_with(w, 0, 3000)
	assert_float(float(penalised) / float(rested)).is_less(0.65)
	assert_float(float(penalised) / float(rested)).is_greater(0.35)


func test_closing_a_draft_keeps_only_what_was_not_taken() -> void:
	var c: ContentSet = TestContent.variety()
	var w: SimWorld = VarietyBKit.draft_world(c, 3)
	var offer: PackedInt32Array = w.draft.offer.duplicate()
	assert_int(DraftSystem.pick(w, 0, 1)).is_equal(Reason.Id.OK)
	assert_int(w.draft.last_offer.size()).is_equal(2)
	assert_bool(w.draft.last_offer.has(offer[1])).is_false()
	assert_bool(w.draft.last_offer.has(offer[0])).is_true()
	assert_bool(w.draft.last_offer.has(offer[2])).is_true()


func test_a_skip_leaves_the_whole_offer_to_the_penalty() -> void:
	var w: SimWorld = VarietyBKit.draft_world(TestContent.variety(), 3)
	var offer: PackedInt32Array = w.draft.offer.duplicate()
	assert_int(DraftSystem.skip(w, 0)).is_equal(Reason.Id.OK)
	assert_array(Array(w.draft.last_offer)).is_equal(Array(offer))


func test_build_tags_count_the_stacks_held() -> void:
	var c: ContentSet = TestContent.variety()
	var w: SimWorld = VarietyBKit.world_after(c, 3)
	assert_bool(DraftSystem.build_tags(w).is_empty()).is_true()
	w.draft.stacks[c.directive_index(&"hot_loads")] = 3
	w.draft.stacks[c.directive_index(&"penetrator_cores")] = 1
	w.draft.stacks[c.directive_index(&"emp_capacitor")] = 2
	var tags: Dictionary[StringName, int] = DraftSystem.build_tags(w)
	assert_int(tags[&"bullet"]).is_equal(4)  # hot_loads x3, penetrator_cores x1
	assert_int(tags[&"gunline"]).is_equal(1)
	assert_int(tags[&"tempo"]).is_equal(2)
	assert_int(tags[&"arc"]).is_equal(2)
	assert_bool(tags.has(&"fortress")).is_false()
