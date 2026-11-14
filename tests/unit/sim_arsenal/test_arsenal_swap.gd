extends GdUnitTestSuite
## V2-C: two weapon slots and swapping (VARIETY_SPEC 3.1). Each slot keeps its own magazine; a swap makes the new slot
## active at once and nothing fires for swap_ticks (24); a holstered weapon reloads at half speed.
## Pistol: 2.2 shots per second (V5-C: was 2), 12 rounds, 75-tick reload; its rounds leave on ticks 28, 55, 82, 110, 137,
## 164, 191, 219, 246, 273, 300, 328. SMG: 6 per second, 30 rounds, 96-tick reload.


func _two_weapons() -> SimWorld:
	var w: SimWorld = VarietyCKit.world()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_SMG)
	VarietyCKit.tough(w, VarietyCKit.place_rel(w, Ids.EN_HULK, 10.0, 0.0))
	return w


func test_a_new_world_carries_the_pistol_in_slot_0_and_nothing_in_slot_1() -> void:
	var w: SimWorld = VarietyCKit.world()
	assert_int(w.arsenal.slot_count).is_equal(2)
	assert_int(w.arsenal.slot_weapon[0]).is_equal(Ids.WP_PISTOL)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(-1)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(12)
	assert_int(ArsenalSystem.slot_state(w, 0)).is_equal(ArsenalSystem.ST_READY)
	assert_int(ArsenalSystem.slot_state(w, 1)).is_equal(ArsenalSystem.ST_EMPTY)
	assert_str(String(ArsenalSystem.weapon_of(w, 1).id)).is_equal("pistol")  # an empty slot shows the pistol
	assert_array(Array(w.stats.weapons)).is_equal([Ids.WP_PISTOL])


func test_a_swap_is_active_at_once_and_holds_fire_for_24_ticks() -> void:
	var w: SimWorld = _two_weapons()
	assert_array(VarietyCKit.shot_ticks(w, 60)).is_equal([28, 55])
	assert_int(VarietyCKit.swap_on_next_tick(w, 1)).is_equal(Reason.Id.OK)  # applied on tick 61
	assert_int(w.arsenal.active).is_equal(1)
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_SMG)
	assert_int(w.warden.magazine).is_equal(30)
	assert_int(ArsenalSystem.slot_state(w, 1)).is_equal(ArsenalSystem.ST_SWAPPING)
	assert_int(ArsenalSystem.slot_ticks_left(w, 1)).is_equal(23)
	var swapped: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.WEAPON_SWAPPED)
	assert_int(swapped.size()).is_equal(1)
	assert_int(swapped[0].a).is_equal(1)
	assert_int(swapped[0].b).is_equal(Ids.WP_SMG)
	# ticks 61 .. 84 are silent (24 ticks); the first SMG round leaves on tick 85 with 6000 milli over, so the next
	# follows 9 ticks later and then one every 10 ticks
	assert_array(VarietyCKit.shot_ticks(w, 50)).is_equal([85, 94, 104])
	assert_int(ArsenalSystem.slot_state(w, 1)).is_equal(ArsenalSystem.ST_READY)


func test_each_slot_keeps_its_own_magazine() -> void:
	var w: SimWorld = _two_weapons()
	VarietyCKit.run_weapon(w, 60)  # two pistol rounds
	VarietyCKit.swap_on_next_tick(w, 1)
	VarietyCKit.run_weapon(w, 49)  # to tick 110: SMG rounds on 85, 94, 104
	assert_int(w.arsenal.slot_magazine[0]).is_equal(10)
	assert_int(w.arsenal.slot_magazine[1]).is_equal(27)
	assert_int(w.warden.magazine).is_equal(27)
	VarietyCKit.swap_on_next_tick(w, 0)
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_PISTOL)
	assert_int(w.warden.magazine).is_equal(10)
	assert_int(w.arsenal.slot_magazine[1]).is_equal(27)


func test_the_swap_time_follows_fast_hands_and_never_goes_below_zero() -> void:
	var w: SimWorld = _two_weapons()
	assert_int(ArsenalSystem.swap_ticks(w)).is_equal(24)
	w.mods.swap_ticks_add = -9.0
	assert_int(ArsenalSystem.swap_ticks(w)).is_equal(15)
	VarietyCKit.run_weapon(w, 60)
	VarietyCKit.swap_on_next_tick(w, 1)  # tick 61, silent for 15 ticks
	assert_array(VarietyCKit.shot_ticks(w, 20)).is_equal([76])
	w.mods.swap_ticks_add = -90.0
	assert_int(ArsenalSystem.swap_ticks(w)).is_equal(0)


func test_swap_refusals() -> void:
	var w: SimWorld = VarietyCKit.world()
	assert_int(ArsenalSystem.swap(w, 1, 1)).is_equal(Reason.Id.WRONG_STATE)  # slot 1 is empty
	assert_int(ArsenalSystem.swap(w, 2, 0)).is_equal(Reason.Id.WRONG_STATE)  # already active
	assert_int(ArsenalSystem.swap(w, 3, 2)).is_equal(Reason.Id.INVALID_CHOICE)  # no third sling
	assert_int(ArsenalSystem.swap(w, 4, -1)).is_equal(Reason.Id.INVALID_CHOICE)
	ArsenalSystem.give_weapon(w, 1, Ids.WP_SMG)
	assert_int(ArsenalSystem.swap(w, 5, 1)).is_equal(Reason.Id.OK)
	assert_int(ArsenalSystem.swap(w, 6, 0)).is_equal(Reason.Id.WRONG_STATE)  # the first swap is still running
	assert_int(w.arsenal.active).is_equal(1)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.WEAPON_SWAPPED)).is_equal(1)
	var legacy: SimWorld = TestContent.world()
	assert_int(ArsenalSystem.swap(legacy, 7, 1)).is_equal(Reason.Id.WRONG_STATE)


func test_a_swap_outside_combat_is_instant() -> void:
	var w: SimWorld = TestContent.variety_world()  # PREPARING
	ArsenalSystem.give_weapon(w, 1, Ids.WP_SMG)
	assert_int(ArsenalSystem.swap(w, 1, 1)).is_equal(Reason.Id.OK)
	assert_int(w.arsenal.swap_left).is_equal(0)
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_SMG)


func test_the_swap_command_goes_through_the_world_and_is_logged() -> void:
	var w: SimWorld = TestContent.variety_world()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_SMG)
	w.submit(SimCommand.swap_weapon(1, 1))
	w.step()
	assert_int(w.arsenal.active).is_equal(1)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.WEAPON_SWAPPED)).is_equal(1)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.COMMAND_REJECTED)).is_equal(0)
	w.submit(SimCommand.swap_weapon(2, 1))  # already active
	w.step()
	var rejected: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.COMMAND_REJECTED)
	assert_int(rejected.size()).is_equal(1)
	assert_int(rejected[0].b).is_equal(Reason.Id.WRONG_STATE)
	assert_int(w.command_log.entries.size()).is_equal(2)


func test_a_holstered_weapon_reloads_at_half_speed() -> void:
	var w: SimWorld = _two_weapons()
	VarietyCKit.run_weapon(w, 328)  # the 12th round leaves on tick 328 and the 75-tick reload starts
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(75)
	VarietyCKit.swap_on_next_tick(w, 1)  # tick 329: the pistol is holstered with 75 reload ticks left
	VarietyCKit.run_weapon(w, 148)  # to tick 477
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(1)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(0)
	assert_int(ArsenalSystem.slot_state(w, 0)).is_equal(ArsenalSystem.ST_RELOADING)
	VarietyCKit.weapon_tick(w)  # tick 478 = 328 + 2 x 75
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(0)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(12)
	assert_int(ArsenalSystem.slot_state(w, 0)).is_equal(ArsenalSystem.ST_READY)


func test_a_reload_keeps_its_progress_across_a_swap_and_back() -> void:
	var w: SimWorld = _two_weapons()
	VarietyCKit.run_weapon(w, 358)  # 30 of the 75 reload ticks done at the active speed
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(45)
	VarietyCKit.swap_on_next_tick(w, 1)  # tick 359
	VarietyCKit.run_weapon(w, 39)  # 40 holstered ticks = 20 reload ticks
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(25)
	VarietyCKit.swap_on_next_tick(w, 0)  # tick 399: active again, full speed
	assert_int(w.warden.reload_ticks_left).is_equal(24)
	VarietyCKit.run_weapon(w, 23)
	assert_int(w.warden.reload_ticks_left).is_equal(1)
	assert_int(w.warden.magazine).is_equal(0)
	# tick 423: the reload ends (24 ticks after the swap, which also covers the 24 silent ticks) and a round leaves
	assert_array(VarietyCKit.shot_ticks(w, 1)).is_equal([423])
	assert_int(w.warden.magazine).is_equal(11)


func test_swapping_at_an_empty_magazine_beats_waiting_for_the_reload() -> void:
	var w: SimWorld = _two_weapons()
	VarietyCKit.run_weapon(w, 360)
	VarietyCKit.swap_on_next_tick(w, 1)
	# the SMG fires from tick 385; staying on the pistol would have fired again on tick 403
	var ticks: Array[int] = VarietyCKit.shot_ticks(w, 40)
	assert_int(ticks[0]).is_equal(385)
	assert_int(ticks.size()).is_equal(2)


func test_give_weapon_and_level_up() -> void:
	var w: SimWorld = VarietyCKit.world()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_ARC_PROJECTOR)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(Ids.WP_ARC_PROJECTOR)
	assert_int(w.arsenal.slot_level[1]).is_equal(1)
	assert_int(w.arsenal.slot_magazine[1]).is_equal(0)  # a heat weapon has no magazine
	assert_int(ArsenalSystem.heat_cap_of(w, 1)).is_equal(100)
	assert_int(ArsenalSystem.magazine_size_of(w, 0)).is_equal(12)
	assert_int(ArsenalSystem.slot_of(w, Ids.WP_ARC_PROJECTOR)).is_equal(1)
	assert_int(ArsenalSystem.slot_of(w, Ids.WP_SMG)).is_equal(-1)
	assert_array(Array(w.stats.weapons)).is_equal([Ids.WP_PISTOL, Ids.WP_ARC_PROJECTOR])
	assert_int(VarietyCKit.count(w, SimEventKind.Id.WEAPON_CHANGED)).is_equal(0)  # not the active slot
	for _n: int in 4:
		ArsenalSystem.level_up(w, 1)
	assert_int(w.arsenal.slot_level[1]).is_equal(3)
	ArsenalSystem.give_weapon(w, 0, Ids.WP_SMG)  # the active slot: the Warden mirrors it
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_SMG)
	assert_int(w.warden.magazine).is_equal(30)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.WEAPON_CHANGED)).is_equal(1)
	ArsenalSystem.give_weapon(w, 2, Ids.WP_SMG)  # no third slot
	assert_int(w.arsenal.slot_weapon[2]).is_equal(-1)


func test_magazine_and_reload_follow_the_modifiers() -> void:
	var w: SimWorld = VarietyCKit.world()
	w.mods.w_mag_mul = 1.3
	w.mods.w_reload_mul = 0.8
	ArsenalSystem.give_weapon(w, 0, Ids.WP_PISTOL)
	assert_int(w.warden.magazine).is_equal(16)  # 12 x 1.3 = 15.6
	assert_int(ArsenalSystem.reload_ticks_of(w, w.content.weapons[Ids.WP_PISTOL])).is_equal(60)
	VarietyCKit.tough(w, VarietyCKit.place_rel(w, Ids.EN_HULK, 10.0, 0.0))
	var ticks: Array[int] = VarietyCKit.shot_ticks(w, 560)
	assert_int(ticks[15]).is_equal(437)  # the 16th round
	assert_int(ticks[16]).is_equal(497)  # 60 ticks of reload


func test_a_shop_purchase_on_variety_content_goes_through_give_weapon() -> void:
	# V3-I: the shop is closed in the shipped data. A content that opens it again puts the SMG into the active slot
	# through ArsenalSystem.give_weapon: nothing writes the Warden directly on variety content.
	var c: ContentSet = TestContent.variety()
	c.mission.shop_enabled = true
	var w: SimWorld = SimWorld.new(SimConfig.create(c, 1))
	w.phase = GameState.Id.SPAWNING
	w.wave = 2
	ArsenalSystem.give_weapon(w, 1, Ids.WP_ARC_PROJECTOR)
	w.add_scrap(5000)
	assert_int(EconomySystem.purchase(w, 1, Ids.UP_SMG)).is_equal(Reason.Id.OK)
	assert_int(w.arsenal.slot_weapon[0]).is_equal(Ids.WP_SMG)
	assert_int(w.arsenal.slot_level[0]).is_equal(1)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(30)
	assert_int(w.arsenal.slot_weapon[1]).is_equal(Ids.WP_ARC_PROJECTOR)
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_SMG)
	assert_int(w.warden.magazine).is_equal(30)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.WEAPON_CHANGED)).is_equal(1)
	VarietyCKit.tough(w, VarietyCKit.place_rel(w, Ids.EN_HULK, 10.0, 0.0))
	VarietyCKit.run_weapon(w, 30)  # a direct write of the Warden would be undone by the mirror on the first tick
	assert_int(w.warden.weapon_index).is_equal(Ids.WP_SMG)
	assert_int(w.arsenal.slot_weapon[0]).is_equal(Ids.WP_SMG)
