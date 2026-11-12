extends GdUnitTestSuite
## V2-B: the old combat shop is closed when mission.shop_enabled is false (VARIETY_SPEC 13.2) and works as before when
## it is true (the legacy fixture).


func _resolved(w: SimWorld) -> Array[SimEvent]:
	return VarietyBKit.events_of(w, SimEventKind.Id.PURCHASE_RESOLVED)


func test_the_variety_shop_is_closed_for_every_upgrade() -> void:
	var w: SimWorld = SimWorld.new(SimConfig.create(TestContent.variety(), 1))
	w.add_scrap(5000)
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 2
	var before: String = w.state_hash()
	for upgrade_index: int in w.content.upgrades.size():
		assert_int(EconomySystem.purchase(w, upgrade_index + 1, upgrade_index)).is_equal(Reason.Id.SHOP_CLOSED)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(w.scrap).is_equal(5000)
	for level: int in w.upgrade_levels:
		assert_int(level).is_equal(0)
	assert_int(w.turrets.active_count()).is_equal(0)


func test_the_refusal_is_a_purchase_resolved_event_with_the_reason() -> void:
	var w: SimWorld = SimWorld.new(SimConfig.create(TestContent.variety(), 1))
	w.add_scrap(5000)
	assert_int(EconomySystem.purchase(w, 7, Ids.UP_DAMAGE)).is_equal(Reason.Id.SHOP_CLOSED)
	var resolved: Array[SimEvent] = _resolved(w)
	assert_int(resolved.size()).is_equal(1)
	assert_int(resolved[0].a).is_equal(7)
	assert_int(resolved[0].b).is_equal(Reason.Id.SHOP_CLOSED)
	assert_float(resolved[0].f).is_equal(float(Ids.UP_DAMAGE))  # the upgrade index travels in `f`


func test_shop_closed_is_the_first_answer_even_for_a_bad_index_or_phase() -> void:
	var w: SimWorld = SimWorld.new(SimConfig.create(TestContent.variety(), 1))
	assert_int(EconomySystem.block_reason(w, 99)).is_equal(Reason.Id.SHOP_CLOSED)
	assert_int(EconomySystem.block_reason(w, -1)).is_equal(Reason.Id.SHOP_CLOSED)
	assert_int(w.purchase_block_reason(Ids.UP_SMG)).is_equal(Reason.Id.SHOP_CLOSED)
	w.set_phase(GameState.Id.SPAWNING)
	w.set_phase(GameState.Id.DEFEAT)
	assert_int(EconomySystem.block_reason(w, Ids.UP_DAMAGE)).is_equal(Reason.Id.SHOP_CLOSED)


func test_a_purchase_command_is_answered_and_nothing_changes() -> void:
	var w: SimWorld = SimWorld.new(SimConfig.create(TestContent.variety(), 1))
	w.add_scrap(5000)
	w.submit(SimCommand.purchase(VarietyBKit.next_id(), Ids.UP_FIRE_RATE))
	w.step()
	var resolved: Array[SimEvent] = _resolved(w)
	assert_int(resolved.size()).is_equal(1)
	assert_int(resolved[0].b).is_equal(Reason.Id.SHOP_CLOSED)
	assert_int(w.scrap).is_equal(5000)
	assert_int(w.upgrade_levels[Ids.UP_FIRE_RATE]).is_equal(0)
	assert_int(w.command_log.entries.size()).is_equal(1)


func test_the_flag_is_read_from_the_content() -> void:
	var c: ContentSet = TestContent.variety()
	c.mission.shop_enabled = true
	var w: SimWorld = SimWorld.new(SimConfig.create(c, 1))
	w.add_scrap(5000)
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 1
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_DAMAGE)).is_equal(Reason.Id.OK)
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)


func test_the_legacy_shop_is_unchanged() -> void:
	var w: SimWorld = TestContent.world(1)
	assert_bool(w.content.mission.shop_enabled).is_true()
	w.add_scrap(5000)
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_DAMAGE)).is_equal(Reason.Id.OK)
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)
	assert_int(w.scrap).is_equal(5000 - 175)
	assert_int(EconomySystem.purchase(w, 2, 99)).is_equal(Reason.Id.UNKNOWN_ID)
	assert_int(EconomySystem.purchase(w, 3, Ids.UP_SMG)).is_equal(Reason.Id.PREREQ_NOT_MET)  # from wave 2
	assert_int(EconomySystem.purchase(w, 4, Ids.UP_AUTO_TURRET)).is_equal(Reason.Id.OK)
	assert_int(w.turrets.active_count()).is_equal(1)
