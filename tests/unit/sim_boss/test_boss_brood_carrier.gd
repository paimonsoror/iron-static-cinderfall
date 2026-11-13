extends GdUnitTestSuite
## V4-L: NODE 3 // BROOD CARRIER (VARIETY_SPEC 6, CONTENT 5; briefing lines boss.brood_carrier.attack / .answer).
## Every 6 s (360 ticks) it releases 6 motes, the hatches glow 1 s (60 ticks) before; at half HP it molts: armor 0 and a
## release every 3 s (180 ticks); a stun resets the hatch timer.

const TYPE: int = Ids.EN_BROOD_CARRIER


func _carrier(w: SimWorld) -> int:
	return VarietyLKit.place(w, TYPE)


func test_first_60_seconds_the_hatches_glow_at_300_and_release_6_motes_at_360_every_360_ticks() -> void:
	var w: SimWorld = VarietyLKit.world()
	_carrier(w)
	for _n: int in 3600:
		VarietyLKit.tick(w)
		VarietyLKit.cull(w, Ids.EN_MOTE)  # the swarm cap is another test
	var glow: Array[int] = []
	var release: Array[int] = []
	for k: int in 10:
		glow.append(300 + 360 * k)
		release.append(360 + 360 * k)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_HATCH)).is_equal(glow)
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_MOTE)).is_equal(release)
	for e: SimEvent in VarietyLKit.events_of(w, SimEventKind.Id.BOSS_TELEGRAPH):
		assert_int(e.b).is_equal(60)
	assert_int(w.stats.kills_by_type[Ids.EN_MOTE]).is_equal(60)
	assert_int(VarietyLKit.events_of(w, SimEventKind.Id.CORE_HIT).size()).is_equal(0)  # the hatch never touches the core
	assert_int(VarietyLKit.phases(w).size()).is_equal(0)


func test_the_state_shows_the_telegraph_counting_down_to_the_release() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _carrier(w)
	assert_int(w.boss.boss_id).is_equal(w.enemies.id[i])
	assert_int(w.boss.boss_type).is_equal(TYPE)
	assert_int(w.boss.phase_count).is_equal(2)
	assert_int(w.boss.variant).is_equal(BossState.NO_VARIANT)
	VarietyLKit.run_to(w, 299)
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	VarietyLKit.tick(w)
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_HATCH)
	assert_int(w.boss.telegraph_left).is_equal(60)
	VarietyLKit.run_to(w, 359)
	assert_int(w.boss.telegraph_left).is_equal(1)
	assert_int(VarietyLKit.living(w, Ids.EN_MOTE).size()).is_equal(0)
	VarietyLKit.tick(w)
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_int(VarietyLKit.living(w, Ids.EN_MOTE).size()).is_equal(6)


func test_the_motes_leave_on_a_ring_around_the_body() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _carrier(w)
	VarietyLKit.run_to(w, 360)
	var ring: float = w.content.enemies[TYPE].radius + BossBroodCarrier.RING_MARGIN_M
	var motes: Array[int] = VarietyLKit.living(w, Ids.EN_MOTE)
	assert_int(motes.size()).is_equal(6)
	for m: int in motes:
		var d: float = Vector2(w.enemies.x[m] - w.enemies.x[i], w.enemies.z[m] - w.enemies.z[i]).length()
		assert_float(d).is_equal_approx(ring, 0.001)
		assert_bool(w.ext.has_flag(m, EnemyExtState.F_MINI)).is_true()
	# the first mote leaves toward the core
	assert_float(w.enemies.x[motes[0]]).is_equal_approx(w.enemies.x[i] - ring, 0.001)


func test_at_half_hp_it_molts_armor_0_and_a_release_every_180_ticks() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _carrier(w)
	var base_armor: float = w.content.enemies[TYPE].armor
	assert_float(base_armor).is_equal(6.0)
	VarietyLKit.run_to(w, 10)
	VarietyLKit.set_hp_frac(w, i, 0.51)
	VarietyLKit.tick(w)
	assert_bool(w.boss.has_flag(BossState.F_MOLTED)).is_false()
	assert_float(BossSystem.armor_of(w, i, base_armor)).is_equal(6.0)
	VarietyLKit.set_hp_frac(w, i, 0.5)
	VarietyLKit.tick(w)  # tick 12
	assert_bool(w.boss.has_flag(BossState.F_MOLTED)).is_true()
	assert_int(w.boss.phase).is_equal(1)
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 2)])
	assert_float(BossSystem.armor_of(w, i, base_armor)).is_equal(0.0)
	for _n: int in 600:
		VarietyLKit.tick(w)
		VarietyLKit.cull(w, Ids.EN_MOTE)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_HATCH)).is_equal([120, 300, 480])
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_MOTE)).is_equal([180, 360, 540])
	assert_array(VarietyLKit.phases(w)).is_equal([Vector2i(1, 2)])  # once


func test_a_molt_late_in_the_cycle_still_gives_the_full_warning() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _carrier(w)
	VarietyLKit.run_to(w, 250)  # clock 250: past the molted period of 180
	VarietyLKit.set_hp_frac(w, i, 0.4)
	VarietyLKit.run_to(w, 400)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_HATCH)).is_equal([251])
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_MOTE)).is_equal([311])


func test_a_molt_during_the_glow_lets_the_announced_release_land_on_time() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _carrier(w)
	VarietyLKit.run_to(w, 320)
	VarietyLKit.set_hp_frac(w, i, 0.4)
	VarietyLKit.run_to(w, 545)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_HATCH)).is_equal([300, 480])
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_MOTE)).is_equal([360, 540])


func test_a_stun_resets_the_hatch_timer_and_drops_the_glow() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _carrier(w)
	VarietyLKit.run_to(w, 349)
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_HATCH)
	assert_int(VarietyLKit.tick_with_ability(w, Ids.AB_EMP)).is_equal(Reason.Id.OK)  # tick 350
	assert_int(w.boss.telegraph_attack).is_equal(BossState.ATK_NONE)
	assert_int(w.boss.timers[BossBroodCarrier.T_CLOCK]).is_equal(0)
	# the boss stun is 1 s: stunned for the steps of ticks 350..408, free again at 409
	VarietyLKit.run_to(w, 408)
	assert_int(w.enemies.stun_ticks[i]).is_equal(1)
	assert_int(w.boss.timers[BossBroodCarrier.T_CLOCK]).is_equal(0)
	VarietyLKit.run_to(w, 800)
	assert_array(VarietyLKit.telegraph_ticks(w, BossState.ATK_HATCH)).is_equal([300, 708])
	assert_array(VarietyLKit.spawn_ticks(w, Ids.EN_MOTE)).is_equal([768])
	assert_int(w.enemies.stun_immune_ticks[i]).is_equal(0)  # 5 s of immunity came and went


func test_motes_over_the_swarm_cap_wait_in_the_spawn_queue() -> void:
	var w: SimWorld = VarietyLKit.world()
	_carrier(w)
	var cap: int = w.content.run.swarm_cap
	assert_int(cap).is_equal(40)
	VarietyLKit.run_to(w, 360 * 7)  # 7 releases = 42 motes
	assert_int(VarietyLKit.living(w, Ids.EN_MOTE).size()).is_equal(40)
	assert_int(SpawnSystem.pending_count(w)).is_equal(2)
	VarietyLKit.cull(w, Ids.EN_MOTE)
	VarietyLKit.begin_tick(w)
	SpawnSystem.step(w)
	assert_int(VarietyLKit.living(w, Ids.EN_MOTE).size()).is_equal(2)
	assert_int(SpawnSystem.pending_count(w)).is_equal(0)


func test_the_armor_rule_only_answers_for_the_boss_body() -> void:
	var w: SimWorld = VarietyLKit.world()
	var i: int = _carrier(w)
	var other: int = VarietyLKit.place(w, Ids.EN_HOLLOW, 6.0, 0.0)
	VarietyLKit.set_hp_frac(w, i, 0.3)
	VarietyLKit.tick(w)
	assert_float(BossSystem.armor_of(w, i, 6.0)).is_equal(0.0)
	assert_float(BossSystem.armor_of(w, other, 3.0)).is_equal(3.0)
	assert_float(BossSystem.armor_of(w, -1, 3.0)).is_equal(3.0)
	assert_float(BossSystem.damage_taken_mult(w, i)).is_equal(1.0)
	assert_float(BossSystem.damage_taken_mult(w, other)).is_equal(1.0)
