extends GdUnitTestSuite
## V4-L: NODE 7 // TREMOR RIG (VARIETY_SPEC 6, CONTENT 5; briefing lines boss.tremor_rig.attack / .answer).
## Stomps every 10 s (600 ticks), the ring shows 1.5 s (90 ticks) before: turrets offline for 4 s (240 ticks) and the
## magazine emptied. A Shield active at the stomp negates it; heat weapons ignore the magazine dump. At 66% and 33% HP
## it opens 2 breach points with 3 borers each, 2.5 s (150 ticks) after the cracks show.
## The fixture's breach points: (2.5, -2.0), (6.0, 2.5), (5.0, -4.5), (3.5, 3.0).

const TYPE: int = Ids.EN_TREMOR_RIG


func _rig(w: SimWorld) -> int:
	return VarietyLKit.place(w, TYPE)


func _borers_near(w: SimWorld, at: Vector2) -> int:
	var n: int = 0
	for j: int in VarietyLKit.living(w, Ids.EN_BORER):
		if Vector2(w.enemies.x[j] - at.x, w.enemies.z[j] - at.y).length() <= BossTremorRig.BORER_RING_M + 0.001:
			n += 1
	return n


func test_first_60_seconds_the_ring_shows_at_510_and_the_stomp_lands_at_600_every_600_ticks() -> void:
	var w: SimWorld = VarietyLKit.world()
	_rig(w)
	var full: int = w.arsenal.slot_magazine[0]
	assert_int(full).is_greater(0)
	var landed: Array[int] = []
	for _n: int in 3600:
		VarietyLKit.tick(w)
		if w.events_state.turret_offline_ticks > 0:
			landed.append(w.tick)
			assert_int(w.events_state.turret_offline_ticks).is_equal(240)
			assert_int(w.arsenal.slot_magazine[0]).is_equal(0)
			assert_int(w.warden.magazine).is_equal(0)
			w.events_state.turret_offline_ticks = 0  # the test plays the part of the systems that end the outage
			w.arsenal.slot_magazine[0] = full
		else:
			assert_int(w.arsenal.slot_magazine[0]).is_equal(full)
	assert_array(landed).is_equal([600, 1200, 1800, 2400, 3000, 3600])
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_STOMP)).is_equal([510, 1110, 1710, 2310, 2910, 3510])
	for e: SimEvent in VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH):
		assert_int(e.b).is_equal(90)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.CORE_HIT).size()).is_equal(0)  # the stomp never touches the core
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(w.boss.phase_count).is_equal(3)
	assert_int(w.boss.phase).is_equal(0)


func test_the_arsenal_starts_the_reload_after_the_dump() -> void:
	var w: SimWorld = VarietyLKit.world()
	_rig(w)
	VarietyLKit.run_to(w, 600)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(0)
	assert_int(w.arsenal.slot_reload_left[0]).is_equal(0)
	VarietyLKit.begin_tick(w)
	WeaponSystem.step(w)
	assert_int(w.arsenal.slot_reload_left[0]).is_greater(0)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.RELOAD_STARTED).size()).is_equal(1)


func test_a_shield_active_at_the_stomp_negates_it() -> void:
	var w: SimWorld = VarietyLKit.world()
	_rig(w)
	var full: int = w.arsenal.slot_magazine[0]
	VarietyLKit.run_to(w, 589)
	assert_int(VarietyLKit.tick_with_ability(w, Ids.AB_SHIELD)).is_equal(Reason.Id.OK)  # tick 590, up for 480 ticks
	VarietyLKit.run_to(w, 600)
	assert_bool(w.boss.has_flag(BossState.F_BRACED)).is_true()
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(full)
	assert_float(w.shield_hp).is_equal(100.0)  # the brace costs the Shield nothing
	VarietyLKit.run_to(w, 1200)  # the Shield ended at 1069: the next stomp lands
	assert_bool(w.boss.has_flag(BossState.F_BRACED)).is_false()
	assert_int(w.events_state.turret_offline_ticks).is_equal(240)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(0)


func test_a_heat_weapon_in_hand_ignores_the_magazine_dump() -> void:
	var w: SimWorld = VarietyLKit.world()
	_rig(w)
	ArsenalSystem.give_weapon(w, 1, Ids.WP_ARC_PROJECTOR)
	w.arsenal.active = 1  # a debug write instead of the swap command
	w.arsenal.slot_heat[1] = 7
	var pistol: int = w.arsenal.slot_magazine[0]
	VarietyLKit.run_to(w, 600)
	assert_int(w.events_state.turret_offline_ticks).is_equal(240)
	assert_int(w.arsenal.slot_heat[1]).is_equal(7)
	assert_int(w.arsenal.slot_vent_left[1]).is_equal(0)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(pistol)  # only the weapon in hand is dumped


func test_a_stun_holds_the_ring_and_the_clock() -> void:
	var w: SimWorld = VarietyLKit.world()
	_rig(w)
	VarietyLKit.run_to(w, 549)
	assert_int(w.boss.telegraph_left).is_equal(51)
	VarietyLKit.tick_with_ability(w, Ids.AB_EMP)  # tick 550: stunned for the steps of 550..608
	VarietyLKit.run_to(w, 608)
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_STOMP)
	assert_int(w.boss.telegraph_left).is_equal(51)
	VarietyLKit.run_to(w, 658)
	assert_int(w.events_state.turret_offline_ticks).is_equal(0)
	VarietyLKit.tick(w)  # 659 = 600 + 59
	assert_int(w.events_state.turret_offline_ticks).is_equal(240)
	VarietyLKit.run_to(w, 1259)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_STOMP)).is_equal([510, 1169])


func test_at_66_percent_two_breach_points_crack_and_3_borers_leave_each_150_ticks_later() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _rig(w)
	var points: PackedVector2Array = w.content.arena.breach_points
	assert_int(points.size()).is_equal(4)
	VarietyLKit.run_to(w, 99)
	VarietyLKit.set_hp_frac(w, i, 0.67)
	VarietyLKit.tick(w)  # 100
	assert_int(w.boss.phase).is_equal(0)
	assert_int(BossTremorRig.breach_points(w).size()).is_equal(0)
	VarietyLKit.set_hp_frac(w, i, 0.66)
	VarietyLKit.tick(w)  # 101: the cracks
	assert_int(w.boss.phase).is_equal(1)
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 3)])
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_BREACH)).is_equal([101])
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH)[0].b).is_equal(150)
	assert_array(Array(BossTremorRig.breach_points(w))).is_equal([points[0], points[1]])
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)  # the state telegraph is the stomp's
	VarietyLKit.run_to(w, 250)
	assert_int(VarietyLKit.living(w, Ids.EN_BORER).size()).is_equal(0)
	VarietyLKit.tick(w)  # 251
	assert_int(VarietyLKit.living(w, Ids.EN_BORER).size()).is_equal(6)
	assert_int(_borers_near(w, points[0])).is_equal(3)
	assert_int(_borers_near(w, points[1])).is_equal(3)
	assert_int(BossTremorRig.breach_points(w).size()).is_equal(0)
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_BORER)).is_equal([251])


func test_at_33_percent_the_other_two_points_open() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _rig(w)
	var points: PackedVector2Array = w.content.arena.breach_points
	VarietyLKit.set_hp_frac(w, i, 0.6)
	VarietyLKit.run_to(w, 300)
	VarietyLKit.cull(w, Ids.EN_BORER)
	VarietyLKit.set_hp_frac(w, i, 0.33)
	VarietyLKit.tick(w)  # 301
	assert_int(w.boss.phase).is_equal(2)
	assert_array(Array(BossTremorRig.breach_points(w))).is_equal([points[2], points[3]])
	VarietyLKit.run_to(w, 451)
	assert_int(_borers_near(w, points[2])).is_equal(3)
	assert_int(_borers_near(w, points[3])).is_equal(3)
	VarietyLKit.set_hp_frac(w, i, 0.05)
	VarietyLKit.run_to(w, 500)
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 3), Vector2i(2, 3)])
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_BORER)).is_equal([151, 451])  # two breaches, never a third


func test_a_hit_through_both_thresholds_opens_the_breaches_one_after_the_other() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _rig(w)
	VarietyLKit.run_to(w, 100)
	VarietyLKit.set_hp_frac(w, i, 0.2)
	VarietyLKit.run_to(w, 410)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_BREACH)).is_equal([101, 252])
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_BORER)).is_equal([251, 402])
	assert_int(VarietyLKit.living(w, Ids.EN_BORER).size()).is_equal(12)
	assert_int(w.boss.phase).is_equal(2)


func test_borers_over_their_type_cap_wait_in_the_spawn_queue() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _rig(w)
	var cap: int = w.content.enemies[Ids.EN_BORER].alive_cap
	assert_int(cap).is_equal(16)
	for k: int in cap - 2:
		VarietyLKit.place(w, Ids.EN_BORER, 0.0, -12.0 + 0.5 * float(k))
	VarietyLKit.set_hp_frac(w, i, 0.5)
	VarietyLKit.run_to(w, 151)
	assert_int(VarietyLKit.living(w, Ids.EN_BORER).size()).is_equal(cap)
	assert_int(SpawnSystem.pending_count(w)).is_equal(4)


func test_an_arena_without_breach_points_turns_the_breach_into_an_early_stomp() -> void:
	var content: ContentSet = TestContent.variety()
	content.arena.breach_points = PackedVector2Array()
	var w: SimWorld = VarietyLKit.world(1, content)
	var i: int = _rig(w)
	VarietyLKit.run_to(w, 100)
	VarietyLKit.set_hp_frac(w, i, 0.6)
	VarietyLKit.run_to(w, 191)
	assert_int(w.boss.phase).is_equal(1)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_BREACH)).is_equal([])
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_STOMP)).is_equal([101])
	assert_int(w.events_state.turret_offline_ticks).is_equal(240)
	assert_int(VarietyLKit.living(w, Ids.EN_BORER).size()).is_equal(0)
