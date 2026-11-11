extends GdUnitTestSuite
## SimWorld shared mutators, queries and the stub tick (ARCH 6.2).


func _count(world: SimWorld, kind: int) -> int:
	var n: int = 0
	for e: SimEvent in world.events.peek():
		if e.kind == kind:
			n += 1
	return n


func test_new_world_starts_in_preparing_with_full_core() -> void:
	var w: SimWorld = TestContent.world()
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	assert_int(w.tick).is_equal(0)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_float(w.core_max_hp).is_equal(1000.0)
	assert_int(w.scrap).is_equal(0)
	assert_int(w.upgrade_levels.size()).is_equal(5)
	assert_int(w.enemies.capacity).is_equal(58)
	assert_int(w.warden.magazine).is_equal(12)
	assert_int(w.turrets.x.size()).is_equal(2)
	assert_float(w.turrets.x[0]).is_equal(-2.5)
	assert_bool(w.is_over()).is_false()
	assert_int(w.result()).is_equal(RunResult.Id.NONE)


func test_kill_enemy_twice_pays_scrap_once_and_pushes_one_event() -> void:
	var w: SimWorld = TestContent.world()
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)
	assert_int(i).is_greater_equal(0)
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	w.kill_enemy(i, DamageSource.Id.WARDEN)
	assert_int(w.scrap).is_equal(20)
	assert_int(_count(w, SimEventKind.Id.ENEMY_KILLED)).is_equal(1)
	assert_int(w.stats.kills_by_type[Ids.EN_SKITTER]).is_equal(1)
	assert_int(w.stats.scrap_earned).is_equal(20)
	assert_int(w.alive_count()).is_equal(0)


func test_kill_enemy_pays_by_type() -> void:
	var w: SimWorld = TestContent.world()
	w.kill_enemy(w.spawn_enemy(Ids.EN_HOLLOW, 5.0, 0.0), DamageSource.Id.TURRET_0)
	w.kill_enemy(w.spawn_enemy(Ids.EN_RUSHER, 5.0, 1.0), DamageSource.Id.TURRET_1)
	w.kill_enemy(w.spawn_enemy(Ids.EN_HULK, 5.0, 2.0), DamageSource.Id.WARDEN)
	assert_int(w.scrap).is_equal(35 + 25 + 400)


func test_kill_enemy_on_invalid_index_is_a_no_op() -> void:
	var w: SimWorld = TestContent.world()
	w.kill_enemy(-1, 0)
	w.kill_enemy(3, 0)
	w.kill_enemy(9999, 0)
	assert_int(w.scrap).is_equal(0)
	assert_int(_count(w, SimEventKind.Id.ENEMY_KILLED)).is_equal(0)


func test_add_scrap_clamps_at_zero() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(50)
	w.add_scrap(-80)
	assert_int(w.scrap).is_equal(0)
	assert_int(w.stats.scrap_earned).is_equal(50)
	assert_int(w.stats.scrap_spent).is_equal(50)
	w.add_scrap(-5)
	assert_int(w.scrap).is_equal(0)
	assert_int(_count(w, SimEventKind.Id.SCRAP_CHANGED)).is_equal(2)


func test_spawn_enemy_at_capacity_returns_minus_one() -> void:
	var w: SimWorld = TestContent.world()
	for n: int in w.enemies.capacity:
		assert_int(w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)).is_greater_equal(0)
	assert_int(w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)).is_equal(-1)
	assert_int(w.alive_count()).is_equal(w.enemies.capacity)
	assert_int(w.next_enemy_id).is_equal(w.enemies.capacity + 1)


func test_spawn_enemy_sets_fields_ids_and_events() -> void:
	var w: SimWorld = TestContent.world()
	var a: int = w.spawn_enemy(Ids.EN_HULK, 8.0, -4.0)
	var b: int = w.spawn_enemy(Ids.EN_SKITTER, 8.0, -3.0)
	assert_int(w.enemies.id[a]).is_equal(1)
	assert_int(w.enemies.id[b]).is_equal(2)
	assert_float(w.enemies.hp[a]).is_equal(2800.0)
	assert_float(w.enemies.prev_x[a]).is_equal(8.0)
	assert_int(w.enemies.slot[a]).is_equal(-1)
	assert_int(w.boss_store_index()).is_equal(a)
	assert_int(_count(w, SimEventKind.Id.ENEMY_SPAWNED)).is_equal(2)
	assert_int(_count(w, SimEventKind.Id.BOSS_SPAWNED)).is_equal(1)
	w.kill_enemy(a, 0)
	assert_int(w.boss_store_index()).is_equal(-1)


func test_step_advances_tick_and_is_deterministic() -> void:
	var a: SimWorld = TestContent.world(7)
	var b: SimWorld = TestContent.world(7)
	for n: int in 120:
		a.step()
		b.step()
	assert_int(a.tick).is_equal(120)
	assert_int(b.tick).is_equal(120)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.events.event_hash).is_equal(b.events.event_hash)


func test_state_hash_changes_with_state() -> void:
	var w: SimWorld = TestContent.world()
	var h0: String = w.state_hash()
	w.step()
	var h1: String = w.state_hash()
	w.set_core_hp(900.0)
	var h2: String = w.state_hash()
	w.spawn_enemy(Ids.EN_RUSHER, 5.0, 5.0)
	var h3: String = w.state_hash()
	assert_bool(h0 != h1).is_true()
	assert_bool(h1 != h2).is_true()
	assert_bool(h2 != h3).is_true()


func test_set_phase_accepts_legal_and_rejects_illegal() -> void:
	var w: SimWorld = TestContent.world()
	w.set_phase(GameState.Id.CLEARING)
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	w.set_phase(GameState.Id.VICTORY)
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	w.set_phase(GameState.Id.PAUSED)
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	w.set_phase(GameState.Id.MENU)
	assert_int(w.phase).is_equal(GameState.Id.PREPARING)
	assert_int(_count(w, SimEventKind.Id.PHASE_CHANGED)).is_equal(0)
	w.set_phase(GameState.Id.SPAWNING)
	assert_int(w.phase).is_equal(GameState.Id.SPAWNING)
	var e: SimEvent = w.events.peek()[0]
	assert_int(e.kind).is_equal(SimEventKind.Id.PHASE_CHANGED)
	assert_int(e.a).is_equal(GameState.Id.PREPARING)
	assert_int(e.b).is_equal(GameState.Id.SPAWNING)


func test_terminal_phase_ends_the_run_and_step_becomes_a_no_op() -> void:
	var w: SimWorld = TestContent.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.set_phase(GameState.Id.DEFEAT)
	assert_bool(w.is_over()).is_true()
	assert_int(w.result()).is_equal(RunResult.Id.DEFEAT)
	var h: String = w.state_hash()
	w.step()
	assert_int(w.tick).is_equal(0)
	assert_str(w.state_hash()).is_equal(h)


func test_set_core_hp_clamps_and_pushes_event() -> void:
	var w: SimWorld = TestContent.world()
	w.set_core_hp(-50.0)
	assert_float(w.core_hp).is_equal(0.0)
	w.set_core_hp(5000.0)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(_count(w, SimEventKind.Id.CORE_CHANGED)).is_equal(2)


func test_upgrade_cost_query_and_max_level() -> void:
	var w: SimWorld = TestContent.world()
	assert_int(w.upgrade_cost(Ids.UP_DAMAGE)).is_equal(175)
	assert_int(w.upgrade_cost(Ids.UP_SMG)).is_equal(300)
	w.upgrade_levels[Ids.UP_DAMAGE] = 2
	assert_int(w.upgrade_cost(Ids.UP_DAMAGE)).is_equal(506)
	w.upgrade_levels[Ids.UP_DAMAGE] = 5
	assert_int(w.upgrade_cost(Ids.UP_DAMAGE)).is_equal(-1)
	assert_int(w.upgrade_cost(99)).is_equal(-1)


func test_stub_commands_report_wrong_state() -> void:
	var w: SimWorld = TestContent.world()
	assert_int(w.purchase_block_reason(Ids.UP_DAMAGE)).is_equal(Reason.Id.WRONG_STATE)
	assert_int(w.ability_block_reason(Ids.AB_EMP)).is_equal(Reason.Id.WRONG_STATE)
	assert_int(PhaseSystem.skip_intermission(w)).is_equal(Reason.Id.WRONG_STATE)


func test_summary_reports_the_run() -> void:
	var w: SimWorld = TestContent.world(5)
	w.kill_enemy(w.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0), 0)
	var s: RunSummary = w.summary("run-1")
	assert_str(s.run_id).is_equal("run-1")
	assert_int(s.run_seed).is_equal(5)
	assert_int(s.result).is_equal(RunResult.Id.NONE)
	assert_int(s.core_hp).is_equal(1000)
	assert_int(s.scrap_earned).is_equal(20)
	assert_int(s.kills_by_type[Ids.EN_SKITTER]).is_equal(1)
	assert_int(s.data_reward).is_equal(0)
