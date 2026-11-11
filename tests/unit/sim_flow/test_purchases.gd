extends GdUnitTestSuite
## EconomySystem: exact costs, every refusal, atomicity, effects (A10, A11).


## Buys every level of `upgrade` in order (wave 2 so that the SMG is unlocked) and checks the price of each.
func _buy_all_levels(upgrade: int, prices: PackedInt32Array) -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 2)
	w.add_scrap(20000)
	for level: int in prices.size():
		var before: int = w.scrap
		assert_int(EconomySystem.cost(w, upgrade)).is_equal(prices[level])
		assert_int(EconomySystem.block_reason(w, upgrade)).is_equal(Reason.Id.OK)
		assert_int(EconomySystem.purchase(w, level + 1, upgrade)).is_equal(Reason.Id.OK)
		assert_int(w.scrap).is_equal(before - prices[level])
		assert_int(w.upgrade_levels[upgrade]).is_equal(level + 1)
	assert_int(EconomySystem.cost(w, upgrade)).is_equal(-1)
	assert_int(EconomySystem.block_reason(w, upgrade)).is_equal(Reason.Id.MAX_LEVEL)


func test_damage_price_per_level() -> void:
	_buy_all_levels(Ids.UP_DAMAGE, PackedInt32Array([175, 298, 506, 860, 1462]))


func test_fire_rate_price_per_level() -> void:
	_buy_all_levels(Ids.UP_FIRE_RATE, PackedInt32Array([150, 240, 384, 614, 983]))


func test_armor_piercing_price_per_level() -> void:
	_buy_all_levels(Ids.UP_ARMOR_PIERCING, PackedInt32Array([200, 360, 648, 1166, 2100]))


func test_auto_turret_price_per_level() -> void:
	_buy_all_levels(Ids.UP_AUTO_TURRET, PackedInt32Array([350, 700]))


func test_smg_price_and_single_level() -> void:
	_buy_all_levels(Ids.UP_SMG, PackedInt32Array([300]))


func test_insufficient_scrap_changes_nothing_and_exact_funds_buy() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.add_scrap(174)
	var before: String = w.state_hash()
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_DAMAGE)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(w.scrap).is_equal(174)
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)
	w.add_scrap(1)
	assert_int(EconomySystem.purchase(w, 2, Ids.UP_DAMAGE)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(0)


func test_max_level_changes_nothing() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.add_scrap(5000)
	w.upgrade_levels[Ids.UP_FIRE_RATE] = 5
	var before: String = w.state_hash()
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_FIRE_RATE)).is_equal(Reason.Id.MAX_LEVEL)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(w.scrap).is_equal(5000)


func test_wrong_state_after_the_run_changes_nothing() -> void:
	for phase_id: int in [GameState.Id.VICTORY, GameState.Id.DEFEAT]:
		var w: SimWorld = FlowKit.in_phase(phase_id, 5)
		w.add_scrap(1000)
		var before: String = w.state_hash()
		assert_int(EconomySystem.purchase(w, 1, Ids.UP_DAMAGE)).is_equal(Reason.Id.WRONG_STATE)
		assert_int(EconomySystem.block_reason(w, Ids.UP_DAMAGE)).is_equal(Reason.Id.WRONG_STATE)
		assert_str(w.state_hash()).is_equal(before)


func test_purchases_are_legal_in_every_live_phase() -> void:
	var phases: Array[int] = [
		GameState.Id.PREPARING, GameState.Id.SPAWNING, GameState.Id.CLEARING, GameState.Id.INTERMISSION
	]
	for phase_id: int in phases:
		var w: SimWorld = FlowKit.in_phase(phase_id)
		w.add_scrap(175)
		assert_int(EconomySystem.purchase(w, 1, Ids.UP_DAMAGE)).is_equal(Reason.Id.OK)
		assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(1)


func test_unknown_upgrade_id_changes_nothing() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.add_scrap(5000)
	var before: String = w.state_hash()
	for bad: int in [-1, 5, 99]:
		assert_int(EconomySystem.purchase(w, 7, bad)).is_equal(Reason.Id.UNKNOWN_ID)
		assert_int(EconomySystem.block_reason(w, bad)).is_equal(Reason.Id.UNKNOWN_ID)
	assert_str(w.state_hash()).is_equal(before)


func test_min_wave_locks_the_smg_until_wave_two() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	w.add_scrap(1000)
	var before: String = w.state_hash()
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_SMG)).is_equal(Reason.Id.PREREQ_NOT_MET)
	assert_str(w.state_hash()).is_equal(before)
	w.wave = 2
	assert_int(EconomySystem.purchase(w, 2, Ids.UP_SMG)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(700)


func test_preparing_counts_as_wave_one_for_min_wave() -> void:
	# W2-D: an INTERMISSION counts as the wave that is about to start (GDD A1), so the SMG opens in the first one.
	# The full matrix is in test_smg_availability.gd.
	var w: SimWorld = FlowKit.in_phase(GameState.Id.PREPARING)
	w.add_scrap(1000)
	assert_int(w.wave).is_equal(0)
	assert_int(EconomySystem.block_reason(w, Ids.UP_DAMAGE)).is_equal(Reason.Id.OK)
	assert_int(EconomySystem.block_reason(w, Ids.UP_AUTO_TURRET)).is_equal(Reason.Id.OK)
	assert_int(EconomySystem.block_reason(w, Ids.UP_SMG)).is_equal(Reason.Id.PREREQ_NOT_MET)
	var rested: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	rested.add_scrap(1000)
	assert_int(EconomySystem.block_reason(rested, Ids.UP_SMG)).is_equal(Reason.Id.OK)
	rested.wave = 2
	assert_int(EconomySystem.block_reason(rested, Ids.UP_SMG)).is_equal(Reason.Id.OK)


func test_refusals_are_checked_in_the_documented_order() -> void:
	var done: SimWorld = FlowKit.in_phase(GameState.Id.DEFEAT)
	assert_int(EconomySystem.block_reason(done, 99)).is_equal(Reason.Id.WRONG_STATE)
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	assert_int(EconomySystem.block_reason(w, 99)).is_equal(Reason.Id.UNKNOWN_ID)
	w.upgrade_levels[Ids.UP_SMG] = 1
	assert_int(EconomySystem.block_reason(w, Ids.UP_SMG)).is_equal(Reason.Id.MAX_LEVEL)
	w.upgrade_levels[Ids.UP_SMG] = 0
	assert_int(EconomySystem.block_reason(w, Ids.UP_SMG)).is_equal(Reason.Id.PREREQ_NOT_MET)
	w.wave = 2
	w.add_scrap(299)
	assert_int(EconomySystem.block_reason(w, Ids.UP_SMG)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)


func test_resolved_event_is_pushed_for_success_and_failure() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	EconomySystem.purchase(w, 11, Ids.UP_DAMAGE)
	w.add_scrap(175)
	EconomySystem.purchase(w, 12, Ids.UP_DAMAGE)
	var resolved: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PURCHASE_RESOLVED)
	assert_int(resolved.size()).is_equal(2)
	assert_int(resolved[0].a).is_equal(11)
	assert_int(resolved[0].b).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	assert_float(resolved[0].f).is_equal(float(Ids.UP_DAMAGE))
	assert_int(resolved[1].a).is_equal(12)
	assert_int(resolved[1].b).is_equal(Reason.Id.OK)
	assert_float(resolved[1].f).is_equal(float(Ids.UP_DAMAGE))


func test_success_pushes_level_event_and_counts_the_spend() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.add_scrap(400)
	EconomySystem.purchase(w, 1, Ids.UP_DAMAGE)
	var levels: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.UPGRADE_LEVEL_CHANGED)
	assert_int(levels.size()).is_equal(1)
	assert_int(levels[0].a).is_equal(Ids.UP_DAMAGE)
	assert_int(levels[0].b).is_equal(1)
	assert_int(w.stats.scrap_spent).is_equal(175)
	var changed: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.SCRAP_CHANGED)
	assert_int(changed[changed.size() - 1].a).is_equal(225)
	assert_int(changed[changed.size() - 1].b).is_equal(-175)
	var resolved: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.PURCHASE_RESOLVED)
	assert_int(resolved[0].b).is_equal(Reason.Id.OK)


func test_third_turret_is_refused_and_pads_activate_in_order() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.add_scrap(5000)
	assert_int(w.turrets.active_count()).is_equal(0)
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_AUTO_TURRET)).is_equal(Reason.Id.OK)
	assert_int(w.turrets.active[0]).is_equal(1)
	assert_int(w.turrets.active[1]).is_equal(0)
	assert_int(EconomySystem.purchase(w, 2, Ids.UP_AUTO_TURRET)).is_equal(Reason.Id.OK)
	assert_int(w.turrets.active[1]).is_equal(1)
	var before: String = w.state_hash()
	var scrap_before: int = w.scrap
	assert_int(EconomySystem.purchase(w, 3, Ids.UP_AUTO_TURRET)).is_equal(Reason.Id.MAX_LEVEL)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(w.scrap).is_equal(scrap_before)
	assert_int(w.turrets.active_count()).is_equal(2)
	var deployed: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.TURRET_DEPLOYED)
	assert_int(deployed.size()).is_equal(2)
	assert_int(deployed[0].a).is_equal(0)
	assert_int(deployed[1].a).is_equal(1)


func test_smg_purchase_sets_weapon_fills_magazine_and_clears_a_reload() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 2)
	w.add_scrap(300)
	w.warden.magazine = 3
	w.warden.reload_ticks_left = 40
	assert_int(w.warden.weapon_index).is_equal(0)
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_SMG)).is_equal(Reason.Id.OK)
	assert_int(w.warden.weapon_index).is_equal(1)
	assert_int(w.warden.magazine).is_equal(30)
	assert_int(w.warden.reload_ticks_left).is_equal(0)
	assert_int(w.scrap).is_equal(0)
	var swapped: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.WEAPON_CHANGED)
	assert_int(swapped.size()).is_equal(1)
	assert_int(swapped[0].a).is_equal(1)


func test_stat_upgrades_touch_no_other_state() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	w.add_scrap(500)
	w.warden.magazine = 7
	EconomySystem.purchase(w, 1, Ids.UP_DAMAGE)
	EconomySystem.purchase(w, 2, Ids.UP_FIRE_RATE)
	assert_int(w.warden.magazine).is_equal(7)
	assert_int(w.warden.weapon_index).is_equal(0)
	assert_int(w.turrets.active_count()).is_equal(0)
	assert_int(FlowKit.count(w, SimEventKind.Id.WEAPON_CHANGED)).is_equal(0)
	assert_int(FlowKit.count(w, SimEventKind.Id.TURRET_DEPLOYED)).is_equal(0)


func test_world_queries_delegate_to_the_economy() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING)
	assert_int(w.purchase_block_reason(Ids.UP_DAMAGE)).is_equal(Reason.Id.INSUFFICIENT_SCRAP)
	w.add_scrap(175)
	assert_int(w.purchase_block_reason(Ids.UP_DAMAGE)).is_equal(Reason.Id.OK)
	assert_int(w.upgrade_cost(Ids.UP_DAMAGE)).is_equal(EconomySystem.cost(w, Ids.UP_DAMAGE))
