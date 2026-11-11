extends GdUnitTestSuite
## Core attacks (GDD 6, ARCH 6.6): an enemy in its slot counts attack_cd down, hits at 0, restarts the timer.
## Baseline: Skitter 12 per 90 ticks, Hollow 30 per 120, Rusher 28 per 72, Hulk 90 per 150. Core 1000 hp.


## Places an attacker the way MovementSystem leaves one on arrival: ST_ATTACKING with a full timer.
func _attacker(w: SimWorld, type_index: int, dz: float = 0.0) -> int:
	var i: int = CombatTestKit.place(w, type_index, 0.0, dz, EnemyStore.ST_ATTACKING, 0.0)
	w.enemies.attack_cd[i] = w.content.enemies[type_index].attack_period_ticks
	return i


func test_a_skitter_hits_for_12_every_90_ticks_first_hit_after_a_full_period() -> void:
	var w: SimWorld = CombatTestKit.world()
	var s: int = _attacker(w, Ids.EN_SKITTER)
	for n: int in 89:
		CombatTestKit.core_tick(w)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.CORE_HIT)).is_equal(0)
	assert_int(w.enemies.attack_cd[s]).is_equal(1)
	CombatTestKit.core_tick(w)  # the 90th tick
	assert_float(w.core_hp).is_equal(988.0)
	assert_int(w.enemies.attack_cd[s]).is_equal(90)
	for n: int in 89:
		CombatTestKit.core_tick(w)
	assert_float(w.core_hp).is_equal(988.0)
	CombatTestKit.core_tick(w)  # the 180th tick
	assert_float(w.core_hp).is_equal(976.0)
	var hits: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(2)
	assert_int(hits[0].tick).is_equal(90)
	assert_int(hits[1].tick).is_equal(180)


func test_core_hit_event_payload() -> void:
	var w: SimWorld = CombatTestKit.world()
	var s: int = _attacker(w, Ids.EN_SKITTER)
	w.enemies.attack_cd[s] = 1
	CombatTestKit.core_tick(w)
	var hit: SimEvent = CombatTestKit.events_of(w, SimEventKind.Id.CORE_HIT)[0]
	assert_int(hit.a).is_equal(w.enemies.id[s])
	assert_int(hit.b).is_equal(Ids.EN_SKITTER)
	assert_float(hit.f).is_equal(12.0)
	assert_float(hit.g).is_equal(0.0)
	var changed: SimEvent = CombatTestKit.events_of(w, SimEventKind.Id.CORE_CHANGED)[0]
	assert_float(changed.f).is_equal(988.0)
	assert_float(changed.g).is_equal(1000.0)


func test_each_archetype_uses_its_own_damage_and_period() -> void:
	var expected_damage: Array[float] = [12.0, 30.0, 28.0, 90.0]
	var expected_period: Array[int] = [90, 120, 72, 150]
	for type_index: int in 4:
		var w: SimWorld = CombatTestKit.world()
		var e: int = _attacker(w, type_index)
		CombatTestKit.run_core(w, expected_period[type_index] - 1)
		assert_float(w.core_hp).is_equal(1000.0)
		CombatTestKit.core_tick(w)
		assert_float(w.core_hp).is_equal(1000.0 - expected_damage[type_index])
		assert_int(w.enemies.attack_cd[e]).is_equal(expected_period[type_index])
		CombatTestKit.run_core(w, expected_period[type_index])
		assert_float(w.core_hp).is_equal(1000.0 - 2.0 * expected_damage[type_index])


func test_a_stunned_attackers_timer_is_frozen_and_resumes() -> void:
	var w: SimWorld = CombatTestKit.world()
	var s: int = _attacker(w, Ids.EN_SKITTER)
	for n: int in 30:
		CombatTestKit.core_tick(w)
	assert_int(w.enemies.attack_cd[s]).is_equal(60)
	w.enemies.stun_ticks[s] = 200
	for n: int in 200:
		CombatTestKit.core_tick(w)
	assert_int(w.enemies.attack_cd[s]).is_equal(60)  # frozen, not reset
	assert_float(w.core_hp).is_equal(1000.0)
	w.enemies.stun_ticks[s] = 0
	for n: int in 59:
		CombatTestKit.core_tick(w)
	assert_float(w.core_hp).is_equal(1000.0)
	CombatTestKit.core_tick(w)
	assert_float(w.core_hp).is_equal(988.0)


func test_enemies_that_are_not_attacking_never_hit_and_their_timer_is_untouched() -> void:
	var w: SimWorld = CombatTestKit.world()
	var mover: int = CombatTestKit.place(w, Ids.EN_SKITTER, 0.0, 0.0, EnemyStore.ST_MOVING, 5.0)
	var seeker: int = CombatTestKit.place(w, Ids.EN_RUSHER, 0.0, 1.0, EnemyStore.ST_SEEK_SLOT, 1.0)
	w.enemies.attack_cd[mover] = 1
	w.enemies.attack_cd[seeker] = 1
	for n: int in 200:
		CombatTestKit.core_tick(w)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(w.enemies.attack_cd[mover]).is_equal(1)
	assert_int(w.enemies.attack_cd[seeker]).is_equal(1)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.CORE_HIT)).is_equal(0)


func test_a_shield_absorbs_a_hit_in_full_and_leaves_the_core_unchanged() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hulk: int = _attacker(w, Ids.EN_HULK)
	w.enemies.attack_cd[hulk] = 1
	w.shield_hp = 100.0
	CombatTestKit.core_tick(w)
	assert_float(w.shield_hp).is_equal(10.0)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.CORE_CHANGED)).is_equal(0)
	var shield_events: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.SHIELD_CHANGED)
	assert_int(shield_events.size()).is_equal(1)
	assert_float(shield_events[0].f).is_equal(10.0)
	assert_float(shield_events[0].g).is_equal(100.0)
	var hit: SimEvent = CombatTestKit.events_of(w, SimEventKind.Id.CORE_HIT)[0]
	assert_float(hit.f).is_equal(0.0)
	assert_float(hit.g).is_equal(90.0)


func test_the_next_hit_after_the_shield_runs_low_splits_between_shield_and_core() -> void:
	var w: SimWorld = CombatTestKit.world()
	var hulk: int = _attacker(w, Ids.EN_HULK)
	w.enemies.attack_cd[hulk] = 1
	w.shield_hp = 100.0
	CombatTestKit.core_tick(w)
	w.enemies.attack_cd[hulk] = 1
	CombatTestKit.core_tick(w)
	assert_float(w.shield_hp).is_equal(0.0)  # removes 10 shield ...
	assert_float(w.core_hp).is_equal(920.0)  # ... and 80 core
	var hits: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_float(hits[1].f).is_equal(80.0)
	assert_float(hits[1].g).is_equal(10.0)
	assert_float(w.stats.damage_absorbed).is_equal(100.0)
	assert_float(w.stats.core_damage_taken).is_equal(80.0)


func test_with_no_shield_nothing_is_absorbed_and_no_shield_event_is_pushed() -> void:
	var w: SimWorld = CombatTestKit.world()
	var s: int = _attacker(w, Ids.EN_SKITTER)
	w.enemies.attack_cd[s] = 1
	CombatTestKit.core_tick(w)
	assert_float(w.shield_hp).is_equal(0.0)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.SHIELD_CHANGED)).is_equal(0)
	assert_float(w.stats.damage_absorbed).is_equal(0.0)
	assert_float(w.stats.core_damage_taken).is_equal(12.0)


func test_debug_invulnerable_core_is_left_untouched() -> void:
	var w: SimWorld = CombatTestKit.world()
	w.config.debug_invulnerable_core = true
	var hulk: int = _attacker(w, Ids.EN_HULK)
	w.enemies.attack_cd[hulk] = 1
	for n: int in 5:
		CombatTestKit.core_tick(w)
		w.enemies.attack_cd[hulk] = 1
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.CORE_CHANGED)).is_equal(0)
	assert_int(CombatTestKit.count(w, SimEventKind.Id.CORE_HIT)).is_equal(5)
	assert_float(w.stats.core_damage_taken).is_equal(0.0)


func test_hits_on_the_same_tick_are_applied_in_ascending_enemy_id_order() -> void:
	var w: SimWorld = CombatTestKit.world()
	var gone: int = _attacker(w, Ids.EN_SKITTER)
	var low_id: int = _attacker(w, Ids.EN_SKITTER, 1.0)
	w.kill_enemy(gone, DamageSource.Id.WARDEN)
	var high_id: int = _attacker(w, Ids.EN_SKITTER, 2.0)  # reuses the freed lower store index
	assert_int(high_id).is_less(low_id)
	assert_int(w.enemies.id[high_id]).is_greater(w.enemies.id[low_id])
	w.enemies.attack_cd[low_id] = 1
	w.enemies.attack_cd[high_id] = 1
	w.shield_hp = 20.0
	CombatTestKit.core_tick(w)
	var hits: Array[SimEvent] = CombatTestKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(2)
	assert_int(hits[0].a).is_equal(w.enemies.id[low_id])  # first in id order: fully absorbed (12 of 20)
	assert_float(hits[0].g).is_equal(12.0)
	assert_float(hits[0].f).is_equal(0.0)
	assert_int(hits[1].a).is_equal(w.enemies.id[high_id])  # second: 8 absorbed, 4 reach the core
	assert_float(hits[1].g).is_equal(8.0)
	assert_float(hits[1].f).is_equal(4.0)
	assert_float(w.core_hp).is_equal(996.0)
	assert_float(w.shield_hp).is_equal(0.0)


func test_the_core_hp_clamps_at_zero_and_the_hit_reports_the_damage_actually_dealt() -> void:
	var w: SimWorld = CombatTestKit.world()
	var s: int = _attacker(w, Ids.EN_SKITTER)
	w.enemies.attack_cd[s] = 1
	w.set_core_hp(5.0)
	CombatTestKit.core_tick(w)
	assert_float(w.core_hp).is_equal(0.0)
	assert_float(CombatTestKit.events_of(w, SimEventKind.Id.CORE_HIT)[0].f).is_equal(5.0)
	assert_float(w.stats.core_damage_taken).is_equal(5.0)


func test_a_core_hit_counts_in_combat_state() -> void:
	var w: SimWorld = CombatTestKit.world()
	var s: int = _attacker(w, Ids.EN_SKITTER)
	w.enemies.attack_cd[s] = 1
	w.shield_hp = 100.0
	CombatTestKit.core_tick(w)
	w.enemies.attack_cd[s] = 1
	w.shield_hp = 0.0
	CombatTestKit.core_tick(w)
	assert_int(w.combat.core_hits).is_equal(2)
