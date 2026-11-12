extends GdUnitTestSuite
## V2-C: crates on the field, the bank and the SALVAGE command (VARIETY_SPEC 3.4; CONTENT 2, 7).
## Secure: 12 s = 720 uncontested ticks; contest radius 2 m (bodied enemies only); lifetime 40 s = 2400 ticks; bank 2;
## scrapping a crate pays 80 in act I. Drop point 0 is (2.0, -3.0). In the frozen fixture the act I crate pool is the
## arc projector alone (tier 5; the rail lance is behind an unlock).

const DROP_X: float = 2.0
const DROP_Z: float = -3.0


func _awaiting_offer(w: SimWorld) -> void:
	w.phase_state.awaiting = PhaseState.Await.SALVAGE  # debug write: PhaseSystem owns the await
	assert_bool(SalvageSystem.open_next(w)).is_true()


## Submits one SALVAGE command through the world. Returns the refusal (COMMAND_REJECTED) or OK.
func _salvage(w: SimWorld, command_id: int, choice: int, action: int) -> int:
	var before: int = VarietyCKit.count(w, SimEventKind.Id.COMMAND_REJECTED)
	w.submit(SimCommand.salvage(command_id, choice, action))
	w.step()
	var rejected: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.COMMAND_REJECTED)
	if rejected.size() > before:
		return rejected[rejected.size() - 1].b
	return Reason.Id.OK


func test_a_crate_lands_on_a_drop_point_and_only_one_at_a_time() -> void:
	var w: SimWorld = VarietyCKit.world()
	assert_bool(SalvageSystem.drop_crate(w, 9, false)).is_false()
	assert_bool(SalvageSystem.drop_crate(w, 0, false)).is_true()
	assert_bool(SalvageSystem.drop_crate(w, 1, false)).is_false()
	assert_bool(w.salvage.crate_active).is_true()
	assert_float(w.salvage.crate_x).is_equal(DROP_X)
	assert_float(w.salvage.crate_z).is_equal(DROP_Z)
	assert_int(w.salvage.crate_life_left).is_equal(2400)
	var dropped: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CRATE_DROPPED)
	assert_int(dropped.size()).is_equal(1)
	assert_int(dropped[0].a).is_equal(1)
	assert_int(dropped[0].b).is_equal(0)
	assert_float(dropped[0].f).is_equal(DROP_X)
	assert_bool(SalvageSystem.drop_crate(TestContent.world(), 0, false)).is_false()  # the legacy content has no crates


func test_720_uncontested_ticks_secure_and_bank_the_crate() -> void:
	var w: SimWorld = VarietyCKit.world()
	SalvageSystem.drop_crate(w, 0, false)
	VarietyCKit.run_salvage(w, 719)
	assert_int(w.salvage.crate_progress).is_equal(719)
	assert_bool(w.salvage.crate_active).is_true()
	VarietyCKit.salvage_tick(w)
	assert_bool(w.salvage.crate_active).is_false()
	assert_int(w.salvage.crates_secured).is_equal(1)
	assert_int(w.stats.crates_secured).is_equal(1)
	assert_array(Array(w.salvage.banked)).is_equal([0])
	assert_array(Array(w.salvage.banked_items)).is_equal([Ids.WP_ARC_PROJECTOR, -1, -1, -1])
	var secured: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CRATE_SECURED)
	assert_int(secured.size()).is_equal(1)
	assert_int(secured[0].tick).is_equal(720)
	assert_int(secured[0].a).is_equal(1)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.CRATE_LOST)).is_equal(0)


func test_a_bodied_enemy_within_2_m_pauses_the_progress_and_a_mini_does_not() -> void:
	var w: SimWorld = VarietyCKit.world()
	SalvageSystem.drop_crate(w, 0, false)
	VarietyCKit.place(w, Ids.EN_MOTE, DROP_X + 0.5, DROP_Z)  # minis do not contest
	var far: int = VarietyCKit.place(w, Ids.EN_SKITTER, DROP_X + 2.5, DROP_Z)
	VarietyCKit.run_salvage(w, 100)
	assert_int(w.salvage.crate_progress).is_equal(100)
	assert_bool(SalvageSystem.is_contested(w)).is_false()
	w.enemies.x[far] = DROP_X + 1.5  # it steps onto the crate
	w.enemies.stun_ticks[far] = 600  # a stunned squatter still contests
	assert_bool(SalvageSystem.is_contested(w)).is_true()
	VarietyCKit.run_salvage(w, 100)
	assert_int(w.salvage.crate_progress).is_equal(100)
	assert_int(w.salvage.crate_life_left).is_equal(2200)  # the lifetime runs on
	w.kill_enemy(far, DamageSource.Id.WARDEN)
	VarietyCKit.run_salvage(w, 619)
	assert_bool(w.salvage.crate_active).is_true()
	VarietyCKit.salvage_tick(w)  # tick 820 = 720 + 100 contested
	assert_bool(w.salvage.crate_active).is_false()
	assert_int(w.salvage.crates_secured).is_equal(1)


func test_a_crate_that_stays_contested_is_lost_after_2400_ticks() -> void:
	var w: SimWorld = VarietyCKit.world()
	SalvageSystem.drop_crate(w, 0, false)
	VarietyCKit.tough(w, VarietyCKit.place(w, Ids.EN_HOLLOW, DROP_X, DROP_Z + 1.0))
	VarietyCKit.run_salvage(w, 2399)
	assert_bool(w.salvage.crate_active).is_true()
	VarietyCKit.salvage_tick(w)
	assert_bool(w.salvage.crate_active).is_false()
	var lost: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CRATE_LOST)
	assert_int(lost.size()).is_equal(1)
	assert_int(lost[0].tick).is_equal(2400)
	assert_int(lost[0].a).is_equal(1)
	assert_int(w.salvage.crates_secured).is_equal(0)
	assert_int(w.salvage.banked.size()).is_equal(0)
	assert_bool(SalvageSystem.drop_crate(w, 1, false)).is_true()  # the next crate is number 2
	assert_int(w.salvage.crate_ordinal).is_equal(2)


func test_modifiers_change_the_secure_time_and_the_loss() -> void:
	var w: SimWorld = VarietyCKit.world()
	w.mods.crate_time_mul = 0.5
	assert_int(SalvageSystem.secure_ticks(w)).is_equal(360)
	w.mods.set_flag(&"crate_never_lost", true)  # salvage_drone
	SalvageSystem.drop_crate(w, 0, false)
	var squatter: int = VarietyCKit.place(w, Ids.EN_HOLLOW, DROP_X, DROP_Z + 1.0)
	VarietyCKit.run_salvage(w, 3000)
	assert_bool(w.salvage.crate_active).is_true()
	assert_int(w.salvage.crate_life_left).is_equal(2400)
	w.kill_enemy(squatter, DamageSource.Id.WARDEN)
	VarietyCKit.run_salvage(w, 360)
	assert_int(w.salvage.crates_secured).is_equal(1)


func test_a_crate_does_not_move_outside_a_wave() -> void:
	var w: SimWorld = VarietyCKit.world()
	SalvageSystem.drop_crate(w, 0, false)
	w.phase = GameState.Id.INTERMISSION
	VarietyCKit.run_salvage(w, 3000)
	assert_int(w.salvage.crate_progress).is_equal(0)
	assert_int(w.salvage.crate_life_left).is_equal(2400)
	assert_bool(w.salvage.crate_active).is_true()


func test_the_bank_holds_two_crates_and_a_third_becomes_scrap() -> void:
	var w: SimWorld = VarietyCKit.world()
	SalvageSystem.grant_crate(w, false)
	SalvageSystem.grant_crate(w, false)
	assert_int(w.salvage.banked.size()).is_equal(2)
	assert_int(w.scrap).is_equal(0)
	SalvageSystem.grant_crate(w, false)
	assert_int(w.salvage.banked.size()).is_equal(2)
	assert_int(w.salvage.banked_items.size()).is_equal(8)
	assert_int(w.scrap).is_equal(80)
	assert_int(w.salvage.crates_secured).is_equal(3)
	assert_int(w.salvage.crate_ordinal).is_equal(3)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.CRATE_SECURED)).is_equal(3)


func test_open_next_grants_the_guaranteed_crate_after_wave_2_once() -> void:
	var w: SimWorld = VarietyCKit.world()
	w.waves_completed = 1
	assert_bool(SalvageSystem.open_next(w)).is_false()
	w.waves_completed = 2
	assert_bool(SalvageSystem.open_next(w)).is_true()
	assert_array(Array(w.salvage.offer)).is_equal([Ids.WP_ARC_PROJECTOR])
	assert_bool(w.salvage.offer_boss).is_false()
	assert_int(w.salvage.banked.size()).is_equal(0)
	assert_int(w.salvage.crates_secured).is_equal(1)
	assert_bool(SalvageSystem.open_next(w)).is_true()  # the same offer is still open
	assert_int(w.salvage.crates_secured).is_equal(1)
	w.phase_state.awaiting = PhaseState.Await.SALVAGE
	assert_int(_salvage(w, 1, 0, SalvageSystem.ACTION_SCRAP)).is_equal(Reason.Id.OK)
	assert_bool(SalvageSystem.open_next(w)).is_false()  # granted once: a secured crate counts for the rule
	assert_bool(SalvageSystem.open_next(TestContent.world())).is_false()


func test_open_next_secures_a_crate_left_on_a_cleared_field() -> void:
	var w: SimWorld = VarietyCKit.world()
	SalvageSystem.drop_crate(w, 0, false)
	var last: int = VarietyCKit.place(w, Ids.EN_SKITTER, 8.0, 8.0)
	VarietyCKit.place(w, Ids.EN_MOTE, 9.0, 9.0)
	VarietyCKit.run_salvage(w, 50)
	assert_bool(SalvageSystem.open_next(w)).is_false()  # a body is still alive: the crate stays where it is
	assert_bool(w.salvage.crate_active).is_true()
	w.kill_enemy(last, DamageSource.Id.WARDEN)
	assert_bool(SalvageSystem.open_next(w)).is_true()
	assert_bool(w.salvage.crate_active).is_false()
	assert_array(Array(w.salvage.offer)).is_equal([Ids.WP_ARC_PROJECTOR])


func test_take_in_the_empty_slot() -> void:
	var w: SimWorld = TestContent.variety_world()
	SalvageSystem.grant_crate(w, false)
	_awaiting_offer(w)
	assert_int(_salvage(w, 1, 0, SalvageSystem.ACTION_SLOT_1)).is_equal(Reason.Id.OK)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(Ids.WP_ARC_PROJECTOR)
	assert_int(w.arsenal.slot_weapon[0]).is_equal(Ids.WP_PISTOL)
	assert_int(w.scrap).is_equal(0)  # nothing was replaced
	assert_int(w.salvage.offer.size()).is_equal(0)
	var resolved: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.SALVAGE_RESOLVED)
	assert_int(resolved.size()).is_equal(1)
	assert_int(resolved[0].a).is_equal(1)
	assert_int(resolved[0].b).is_equal(Reason.Id.OK)
	assert_float(resolved[0].f).is_equal(1.0)
	assert_bool(SalvageSystem.open_next(w)).is_false()
	assert_int(_salvage(w, 2, 0, SalvageSystem.ACTION_SCRAP)).is_equal(Reason.Id.NOT_AWAITING)  # no offer is open


func test_take_in_slot_0_scraps_the_pistol_for_half_the_crate_value() -> void:
	var w: SimWorld = TestContent.variety_world()
	SalvageSystem.grant_crate(w, false)
	_awaiting_offer(w)
	assert_int(_salvage(w, 1, 0, SalvageSystem.ACTION_SLOT_0)).is_equal(Reason.Id.OK)
	assert_int(w.arsenal.slot_weapon[0]).is_equal(Ids.WP_ARC_PROJECTOR)
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_ARC_PROJECTOR)
	assert_int(w.scrap).is_equal(40)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.WEAPON_CHANGED)).is_equal(1)


func test_scrap_it_pays_the_crate_value() -> void:
	var w: SimWorld = TestContent.variety_world()
	SalvageSystem.grant_crate(w, false)
	_awaiting_offer(w)
	assert_int(SalvageSystem.scrap_value(w)).is_equal(80)
	assert_int(_salvage(w, 1, 0, SalvageSystem.ACTION_SCRAP)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(80)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(-1)
	w.phase_state.act = 3
	assert_int(SalvageSystem.scrap_value(w)).is_equal(200)


func test_a_duplicate_can_only_level_up_or_be_scrapped() -> void:
	var w: SimWorld = TestContent.variety_world()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_ARC_PROJECTOR)
	for level: int in [2, 3]:
		VarietyCKit.bank(w, [Ids.WP_ARC_PROJECTOR], false)
		_awaiting_offer(w)
		assert_array(Array(w.salvage.offer)).is_equal([Ids.WP_ARC_PROJECTOR])
		assert_int(SalvageSystem.level_up_slot(w, Ids.WP_ARC_PROJECTOR)).is_equal(1)
		assert_int(_salvage(w, level * 10, 0, SalvageSystem.ACTION_SLOT_0)).is_equal(Reason.Id.INVALID_CHOICE)
		assert_int(w.salvage.offer.size()).is_equal(1)  # a refusal leaves the offer open
		assert_int(_salvage(w, level * 10 + 1, 0, SalvageSystem.ACTION_LEVEL_UP)).is_equal(Reason.Id.OK)
		assert_int(w.arsenal.slot_level[1]).is_equal(level)
	VarietyCKit.bank(w, [Ids.WP_ARC_PROJECTOR], false)
	_awaiting_offer(w)
	assert_int(SalvageSystem.level_up_slot(w, Ids.WP_ARC_PROJECTOR)).is_equal(-1)
	assert_int(_salvage(w, 40, 0, SalvageSystem.ACTION_LEVEL_UP)).is_equal(Reason.Id.INVALID_CHOICE)  # level 3 is the top
	assert_int(_salvage(w, 41, 0, SalvageSystem.ACTION_SCRAP)).is_equal(Reason.Id.OK)
	assert_int(w.scrap).is_equal(80)


func test_salvage_refusals() -> void:
	var w: SimWorld = TestContent.variety_world()
	SalvageSystem.grant_crate(w, false)
	assert_int(_salvage(w, 1, 0, SalvageSystem.ACTION_SCRAP)).is_equal(Reason.Id.NOT_AWAITING)
	_awaiting_offer(w)
	assert_int(_salvage(w, 2, 1, SalvageSystem.ACTION_SCRAP)).is_equal(Reason.Id.INVALID_CHOICE)  # one weapon only
	assert_int(_salvage(w, 3, 0, SalvageSystem.ACTION_SLOT_2)).is_equal(Reason.Id.INVALID_CHOICE)  # no third sling
	assert_int(_salvage(w, 4, 0, 5)).is_equal(Reason.Id.INVALID_CHOICE)  # not an action
	assert_int(_salvage(w, 5, 0, SalvageSystem.ACTION_LEVEL_UP)).is_equal(Reason.Id.INVALID_CHOICE)  # not carried
	assert_int(w.salvage.offer.size()).is_equal(1)
	assert_int(w.scrap).is_equal(0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SALVAGE_RESOLVED)).is_equal(0)
	assert_int(w.tick).is_equal(5)  # one tick per command, none while only waiting
	assert_int(w.command_log.entries.size()).is_equal(5)


func test_crate_contents_come_from_the_crate_stream_and_respect_the_pool() -> void:
	var cfg: SimConfig = SimConfig.create(TestContent.variety(), 5)
	cfg.daily = true  # the full pool: every weapon unlocked
	var a: SimWorld = SimWorld.new(cfg)
	var b: SimWorld = SimWorld.new(cfg)
	a.phase_state.act = 2
	b.phase_state.act = 2
	var first: PackedInt32Array = SalvageSystem.roll_contents(a, 1, true)
	assert_int(first.size()).is_equal(2)  # a boss crate: choose 1 of 2
	assert_int(first[0]).is_not_equal(first[1])
	for weapon_index: int in first:
		var def: WeaponDef = a.content.weapons[weapon_index]
		assert_float(a.content.run.tier_weight(3, def.tier)).is_greater(0.0)  # the next act's row
	assert_array(Array(SalvageSystem.roll_contents(b, 1, true))).is_equal(Array(first))
	assert_str(a.state_hash()).is_equal(b.state_hash())  # the draw is in the hash (the stream state)
	assert_str(a.state_hash()).is_not_equal(SimWorld.new(cfg).state_hash())
	var seen: Dictionary[int, bool] = {}
	for ordinal: int in range(2, 60):
		for weapon_index: int in SalvageSystem.roll_contents(a, ordinal, false):
			seen[weapon_index] = true
			assert_int(a.content.weapons[weapon_index].tier).is_greater_equal(2)  # never the pistol
	assert_int(seen.size()).is_greater(3)
	a.mods.crate_choices = 1.0
	assert_int(SalvageSystem.roll_contents(a, 60, false).size()).is_equal(2)
	var base: SimWorld = TestContent.variety_world(5)
	assert_bool(SalvageSystem.in_pool(base, base.content.weapons[Ids.WP_RAIL_LANCE])).is_false()  # locked
	assert_bool(SalvageSystem.in_pool(base, base.content.weapons[Ids.WP_ARC_PROJECTOR])).is_true()
	assert_bool(SalvageSystem.in_pool(base, base.content.weapons[Ids.WP_PISTOL])).is_false()


func test_a_boss_kill_banks_a_boss_crate() -> void:
	var w: SimWorld = VarietyCKit.world()
	var hulk: int = VarietyCKit.place(w, Ids.EN_HULK, 5.0, 0.0)
	var elite: int = w.spawn_enemy(Ids.EN_SKITTER, 6.0, 0.0, 1)
	w.kill_enemy(elite, DamageSource.Id.WARDEN)
	assert_int(w.salvage.elite_kills).is_equal(1)
	assert_int(w.salvage.banked.size()).is_equal(0)
	w.kill_enemy(hulk, DamageSource.Id.TURRET_0)
	assert_array(Array(w.salvage.banked)).is_equal([1])
	assert_bool(SalvageSystem.open_next(w)).is_true()
	assert_bool(w.salvage.offer_boss).is_true()
	assert_int(w.salvage.offer.size()).is_greater_equal(1)
