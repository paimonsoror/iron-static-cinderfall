extends GdUnitTestSuite
## GDD A1 / 7: the SMG is "purchasable from wave 2 (first intermission onward), 300 Scrap". min_wave is compared with
## the effective wave: PREPARING = 1, SPAWNING and CLEARING = world.wave, INTERMISSION = world.wave + 1.


func test_effective_wave_by_phase() -> void:
	assert_int(EconomySystem.effective_wave(FlowKit.in_phase(GameState.Id.PREPARING))).is_equal(1)
	assert_int(EconomySystem.effective_wave(FlowKit.in_phase(GameState.Id.SPAWNING, 1))).is_equal(1)
	assert_int(EconomySystem.effective_wave(FlowKit.in_phase(GameState.Id.CLEARING, 1))).is_equal(1)
	assert_int(EconomySystem.effective_wave(FlowKit.in_phase(GameState.Id.INTERMISSION, 1))).is_equal(2)
	assert_int(EconomySystem.effective_wave(FlowKit.in_phase(GameState.Id.SPAWNING, 3))).is_equal(3)
	assert_int(EconomySystem.effective_wave(FlowKit.in_phase(GameState.Id.INTERMISSION, 3))).is_equal(4)


func test_smg_is_locked_while_preparing() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.PREPARING)
	w.add_scrap(1000)
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_SMG)).is_equal(Reason.Id.PREREQ_NOT_MET)
	assert_int(w.scrap).is_equal(1000)
	assert_int(w.upgrade_levels[Ids.UP_SMG]).is_equal(0)
	assert_int(w.warden.weapon_index).is_equal(0)


func test_smg_is_locked_during_wave_one_spawning_and_clearing() -> void:
	for phase: int in [GameState.Id.SPAWNING, GameState.Id.CLEARING]:
		var w: SimWorld = FlowKit.in_phase(phase, 1)
		w.add_scrap(1000)
		var before: String = w.state_hash()
		assert_int(EconomySystem.purchase(w, 1, Ids.UP_SMG)).is_equal(Reason.Id.PREREQ_NOT_MET)
		assert_str(w.state_hash()).is_equal(before)


func test_smg_is_purchasable_in_the_first_intermission() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	w.add_scrap(300)
	assert_int(EconomySystem.block_reason(w, Ids.UP_SMG)).is_equal(Reason.Id.OK)
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_SMG)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(0)
	assert_int(w.upgrade_levels[Ids.UP_SMG]).is_equal(1)
	assert_int(w.warden.weapon_index).is_equal(1)
	assert_int(w.warden.magazine).is_equal(30)


func test_smg_needs_its_300_scrap_in_the_first_intermission() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	w.add_scrap(299)
	assert_int(EconomySystem.block_reason(w, Ids.UP_SMG)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)


func test_smg_stays_purchasable_from_wave_two_on() -> void:
	for phase: int in [GameState.Id.SPAWNING, GameState.Id.CLEARING, GameState.Id.INTERMISSION]:
		var w: SimWorld = FlowKit.in_phase(phase, 2)
		w.add_scrap(300)
		assert_int(EconomySystem.block_reason(w, Ids.UP_SMG)).is_equal(Reason.Id.OK)


func test_the_unlock_follows_a_real_run_into_the_first_intermission() -> void:
	# Through world.step(): wave 1 locked, the first INTERMISSION opens the SMG, the same command succeeds there.
	var w: SimWorld = FlowKit.world()
	w.add_scrap(300)
	FlowKit.step_n(w, w.content.mission.prepare_ticks)
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	assert_int(w.purchase_block_reason(Ids.UP_SMG)).is_equal(Reason.Id.PREREQ_NOT_MET)
	w.submit(SimCommand.purchase(1, Ids.UP_SMG))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_SMG]).is_equal(0)
	assert_int(w.scrap).is_equal(300)
	FlowKit.clear_wave(w)
	assert_int(w.phase).is_equal(GameState.Id.INTERMISSION)
	assert_int(w.wave).is_equal(1)
	w.submit(SimCommand.purchase(2, Ids.UP_SMG))
	w.step()
	assert_int(w.upgrade_levels[Ids.UP_SMG]).is_equal(1)
	assert_int(w.warden.weapon_index).is_equal(1)
